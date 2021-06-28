module Admin
  require 'csv'
  require_relative "./knapsack_allocation"
  class ElectionsController < ApplicationController
    before_action :set_no_cache
    before_action :require_superadmin_auth, only: [:new, :create, :duplicate, :post_duplicate, :destroy]
    before_action :require_admin_auth, only: [:edit, :update, :analytics, :analytics_more, :analytics_cooccurrence, :analytics_adjustable_cost_projects, :analytics_chicago49]
    before_action :require_admin_or_volunteer_auth, only: [:show, :to_voting_machine, :post_to_voting_machine]
    before_action :require_user_account, only: [:config_reference]

    def show
      @election = Election.find(params[:id])
    end

    def new
      @election = Election.new
    end

    def create
      @election = Election.new(election_params)
      @election.config_yaml = ""
      if @election.save
        (1..5).each do |i|
          project = Project.new
          project.election = @election
          project.number = i.to_s
          project.title = "Example Project " + i.to_s
          project.description = "Example description " + i.to_s + "."
          project.cost = i * 1000
          project.save!
        end
        redirect_to admin_election_path(@election)
      else
        render :new
      end
    end

    def duplicate
      @election = Election.new
      original_election = Election.find(params[:id])
      @election.name = original_election.name
      @election.slug = original_election.slug
    end

    def post_duplicate
      original_election = Election.find(params[:id])
      @election = original_election.dup
      local_election_params = election_params
      @election.name = local_election_params[:name]
      @election.slug = local_election_params[:slug]
      @election.duplicate_projects = params[:election][:duplicate_projects]
      ActiveRecord::Base.transaction do
        if @election.save
          redirect_to admin_election_path(@election)
        else
          render :duplicate
          raise ActiveRecord::Rollback
        end

        if @election.duplicate_projects
          category_ids = {}
          original_election.categories.each do |original_category|
            category = original_category.dup
            category.election_id = @election.id
            category.image = original_category.image
            category.save!
            category_ids[original_category.id] = category.id
          end
          original_election.projects.each do |original_project|
            project = original_project.dup
            project.election_id = @election.id
            project.image = original_project.image
            if !original_project.category.nil?
              project.category_id = category_ids[original_project.category_id]
            end
            project.save!
          end
        end
      end
    end

    def edit
      @election = Election.find(params[:id])
      load_config_description_and_locales  # hacky
    end

    def update
      @election = Election.find(params[:id])
      raise "error" if !current_user.can_update_election?(@election)

      respond_to do |format|
        if @election.update(election_params)
          format.html { redirect_to admin_election_path(@election) }
          format.json { render json: {message: 'Saved successfully'}, status: :ok }
        else
          format.html { render :edit }
          format.json { render json: @election.errors.full_messages, status: :unprocessable_entity }
        end
      end
    end

    def destroy
      # TODO: This action is very dangerous.
      # We shouldn't really delete it. We should just mark it as 'deleted'.
      election = Election.find(params[:id])

      if election.voters.count > 0
        render plain: "Sorry, this election can't be deleted because it has already received some votes. Please contact the Stanford team or email feedback@pbstanford.org."
        return
      end
      election.destroy
      redirect_to admin_root_path
    end

    def analytics
      @election = Election.find(params[:id])
      workflow = @election.config[:workflow].flatten

      log_activity('analytics', note: @election.id.to_s)

      # Find UTC offset.
      utc_offset = ActiveSupport::TimeZone.seconds_to_utc_offset(@election.utc_offset_in_seconds)

      # Construct the filter string. Filter strings are used to filter
      # the vote results to a particular place.
      # Disable this for now until it's fully supported.
=begin
      filter_clauses = []
      filter_clauses << 'voters.authentication_method = ' + Voter.sanitize(params[:authentication_method]) if params.key?(:authentication_method)
      filter_clauses << 'voters.location_id = ' + Voter.sanitize(params[:location_id]) if params.key?(:location_id)
      filter_clauses << 'voters.data LIKE \'%"shuffled":' + (params[:shuffled] != '0').to_s  + '%\'' if params.key?(:shuffled)  # crude way
      filter = filter_clauses.join(' AND ')
=end
      filter = ''

      @authentication_method = params[:authentication_method]
      @location_name = Location.find(params[:location_id]).name if params.key?(:location_id)

      Globalize.with_locale(@election.config[:default_locale]) do
        @projects = @election.projects.map do |p|
          {
            id: p.id,
            title: p.title,
            cost: p.cost,
            adjustable_cost: p.adjustable_cost,
            category_name: p.category.nil? ? nil : p.category.name,
          }
        end
      end

      # code for the vote count table
      @total_vote_count = @election.valid_voters.count
      @columns, @vote_counts, @totals = analytics_vote_count_table(@election, utc_offset)

      @analytics_data = {}

      if workflow.include?('approval')
        @analytics_data[:approval], approvals_csv, approvals_individual_csv =
          analytics_approval(@election, utc_offset, filter)
      end

      if workflow.include?('knapsack')
        @analytics_data[:knapsack], knapsacks_csv, knapsacks_individual_csv =
          analytics_knapsack(@election, utc_offset)
      end

      if workflow.include?('comparison')
        @analytics_data[:comparison], comparison_losses_csv, comparison_ties_csv, comparison_wins_csv, comparison_ratios_csv, comparisons_individual_csv =
          analytics_comparison(@election, utc_offset, filter)
      end

      @voter_registration_exists, voter_registration_csv = analytics_voter_registration(@election)

      if @election.config[:remote_voting_free_verification]
        voter_data_csv = analytics_voter_data(@election)
      end

      if params[:legacy]
        if @election.config[:approval][:project_ranking] || workflow.include?('ranking')
          @analytics_data[:ranking], ranking_csv, ranking_individual_csv = analytics_ranking_legacy(@election)
        end
      else
        if workflow.include?('ranking')
          @analytics_data[:ranking], ranking_csv, ranking_individual_csv = analytics_ranking(@election)
        end
      end

      respond_to do |format|
        format.html {}
        format.json do
          render json: {
            analytics_data: @analytics_data
          }
        end
        format.csv do
          table = params[:table]
          csv_string = case table.to_sym
            when :all then analytics_all_csv_string
            when :approvals then approvals_csv.call
            when :knapsacks then knapsacks_csv.call
            when :comparison_wins then comparison_wins_csv.call
            when :comparison_ties then comparison_ties_csv.call
            when :comparison_losses then comparison_losses_csv.call
            when :comparison_ratios then comparison_ratios_csv.call
            when :approvals_individual then approvals_individual_csv.call
            when :knapsacks_individual then knapsacks_individual_csv.call
            when :comparisons_individual then comparisons_individual_csv.call
            when :voter_registration then voter_registration_csv.call
            when :voter_data then voter_data_csv.call
            when :ranking then ranking_csv.call
            when :ranking_individual then ranking_individual_csv.call
            else raise 'error'
          end
          send_data csv_string, type: :csv, disposition: "attachment; filename=" + @election.slug + "-" + table + ".csv"
          # render plain: csv_string  # for debugging
        end
      end
    end

    # This is another analytics page for data that require a lot of CPU power to process.
    # We separate it from the main analytics page in hope that users won't reload it often.
    # This is not a good solution. Let's think of a better solution.
    def analytics_more
      @election = Election.find(params[:id])

      # Calculate the average time voters spent on each page
      durations_by_page = {}
      @election.valid_voters.pluck(:data).each do |data|
        next if data.nil? || !data.key?('timestamps')
        timestamps = data['timestamps'].to_a
        (timestamps.length - 1).times do |i|
          page = timestamps[i][0]
          duration = timestamps[i + 1][1] - timestamps[i][1]
          durations_by_page[page] = [] if !durations_by_page.key?(page)
          durations_by_page[page] << duration
        end
      end
      @duration_stats = durations_by_page.map do |page, durations|
        n = durations.length
        sorted_durations = durations.sort
        {
          page: page,
          mean: (durations.sum.to_f / n),
          median: (n % 2 == 0) ? ((sorted_durations[n/2 - 1] + sorted_durations[n/2]).to_f / 2) : sorted_durations[n/2]
        }
      end

      # Count the number of voters for each language
      @voter_counts_by_locale = Hash.new(0)
      @election.valid_voters.pluck(:data).each do |data|
        next if data.nil? || !data.key?('locale')
        @voter_counts_by_locale[data['locale']] += 1
      end
    end

    def analytics_cooccurrence
      @election = Election.find(params[:id])

      raise 'error' unless current_user.can_see_voter_data?(@election)

      vote_approvals = @election.valid_voters.joins('LEFT OUTER JOIN vote_approvals ON vote_approvals.voter_id = voters.id')
        .select('voters.id, vote_approvals.project_id').order(:id)

      projects = @election.projects
      project_id_to_index = {}
      projects.each_with_index { |p, index| project_id_to_index[p.id] = index }

      n_projects = projects.count
      cooccurrence_matrix = Array.new(n_projects) { Array.new(n_projects) { 0 } }
      vote_counts = Array.new(n_projects) { 0 }

      current_voter = -1
      current_voter_projects = []
      vote_approvals.each do |v|
        if v.id != current_voter
          current_voter = v.id
          current_voter_projects = []
        end
        if !v.project_id.nil?
          project_index = project_id_to_index[v.project_id]
          current_voter_projects.each do |project_index2|
            cooccurrence_matrix[project_index][project_index2] += 1
            cooccurrence_matrix[project_index2][project_index] += 1
          end
          current_voter_projects << project_index
          vote_counts[project_index] += 1
        end
      end

      @projects = @election.projects.map do |p|
        {
          id: p.id,
          title: p.title,
          cost: p.cost
        }
      end

      # Sort rows and columns by approval vote count.
      @cooccurrence_ordered_indices = (0...@projects.length).to_a
      @cooccurrence_ordered_indices.sort_by! { |i| -vote_counts[i] }

      @cooccurrence_data = cooccurrence_matrix.each_with_index.map do |row, i|
        vote_count = vote_counts[i]
        row.each_with_index.map do |x, j|
          [x, vote_count, vote_counts[j]]
        end
      end
    end

    # Analytics page for the adjustable cost projects
    def analytics_adjustable_cost_projects
      @election = Election.find(params[:id])

      total_votes = @election.voters.where('void = 0 AND stage IS NOT NULL AND stage != \'approval\'').count  # FIXME: Not a good way to count.

      # Get the adjustable cost projects.
      @adjustable_cost_projects = @election.projects.where(adjustable_cost: true).map do |project|
        # Get the vote count for each cost from the table.
        vote_counts = {}
        adjustable_project_data = project.vote_approvals.select('cost, COUNT(*) AS vote_count')
          .joins(:voter).where('voters.void = 0').group(:cost)
        adjustable_project_data.each do |vp|
          vote_counts[vp.cost] = vp.vote_count
        end

        # FIXME: Since we don't create a vote_approval row with cost=0, we have to use this.
        if project.cost_min == 0
          raise "error" if vote_counts.key?(0)
          vote_counts[0] = total_votes - vote_counts.values.sum
        end

        # For projects that use radio buttons, set the vote count for options that haven't received any votes to 0.
        if !project.uses_slider
          (project.cost_min..project.cost).step(project.cost_step).each do |cost|
            vote_counts[cost] = 0 if !vote_counts.key?(cost)
          end
        end

        if !current_user.can_see_exact_results?(@election)
          vote_counts.each { |cost, vote_count| vote_counts[cost] = vote_count.round(-1) }
        end

        {
          title: project.title,
          vote_counts: vote_counts,
          max_vote_count: vote_counts.values.max.to_i,
          average_cost: (total_votes > 0) ? (vote_counts.map { |cost, vote_count| cost * vote_count }.inject(&:+).to_f / total_votes) : nil,
          median_cost: 0,  # TODO: Implement median cost.
        }
      end
    end

    # This is for Chicago's 49th ward only.
    # FIXME: Clean this up.
    def analytics_chicago49
      @election = Election.find(params[:id])
      projects = @election.projects.order(:sort_order).to_a
      adjustable_cost_project_indices = projects.length.times.select { |i| projects[i].adjustable_cost? }
      locales = ['en', 'es', 'ru']
      vote_approvals_by_voter_id = @election.valid_voters
        .select('voters.id, vote_approvals.project_id, vote_approvals.cost')
        .joins(:vote_approvals).group_by(&:id)

      csv_string = CSV.generate do |csv|
        csv << ['BALLOT', 'Streets/Lights %'] + (projects.count-1).times.map { |i| 'Proj. ' + (i+1).to_s } + ['', 'English', 'Spanish', 'Russian']
        @election.valid_voters.each_with_index do |voter, i|
          cs = [''] * projects.length
          adjustable_cost_project_indices.each { |j| cs[j] = '0' }
          vote_approvals = vote_approvals_by_voter_id[voter.id] || []
          vote_approvals.each do |vote_approval|
            j = projects.index { |p| p.id == vote_approval.project_id }
            project = projects[j]
            if project.adjustable_cost?
              cs[j] = ((vote_approval.cost * 100) / project.cost).to_s
            else
              cs[j] = '1'
            end
          end

          ls = [''] * locales.length
          locale = voter.data['locale']
          if locale.nil?
            locale = 'en'
          end
          ls[locales.index(locale)] = '1'

          csv << [(i+1).to_s] + cs + [''] + ls
        end
      end
      send_data csv_string, type: :csv, disposition: "attachment; filename=pb" + @election.slug + ".csv"
    end

    def to_voting_machine
      @election = Election.find(params[:id])
      raise "error" unless @election.config[:allow_local_voting]
      @locations = @election.locations.order(:name)
    end

    def post_to_voting_machine
      @election = Election.find(params[:id])
      raise "error" unless @election.config[:allow_local_voting]
      @locations = @election.locations

      if @locations.length > 0 && !params.key?(:location_id)
        flash.now[:errors] = ['Please choose the current location.']
        render action: :to_voting_machine
        return
      end

      location_id = params[:location_id].to_i
      if location_id == 0  # the user chooses "Other (please specify)"
        other_location_name = params[:other_location_name]
        if other_location_name.blank?
          flash.now[:errors] = ['The current location cannot be blank.']
          render action: :to_voting_machine
          return
        end

        location = Location.new
        location.election = @election
        location.name = other_location_name.strip
        if !location.save
          flash.now[:errors] = location.errors.full_messages
          render action: :to_voting_machine
          return
        end
      else
        location = Location.find(location_id)
        raise "error" unless location.election == @election
      end

      # TODO: use cookie?
      log_activity('to_voting_machine')
      session[:voting_machine_user_id] = session[:user_id]
      session[:voting_machine_election_id] = @election.id
      session[:voting_machine_location_id] = location.id
      session[:user_id] = nil
      session[:voter_id] = nil
      redirect_to "/" + @election.slug
    end

    def config_reference
      @default_config = Election.default_config
      @locales = Dir.glob(Rails.root.join('config', 'locales', '*.yml')).sort.map do |path|
        {filename: File.basename(path), yaml: File.read(path)}
      end
    end

    private

    def election_params
      params.require(:election).permit(
        [:name, :slug, :budget, :time_zone, :config_yaml] +
        (current_user.superadmin? ? [:allow_admins_to_update_election, :allow_admins_to_see_voter_data, :allow_admins_to_see_exact_results, :real_election, :remarks] : [])
      )
    end

    def load_config_description_and_locales
      @config_description = YAML.load_file(Rails.root.join('app', 'models', 'election_config_description.yml'))

      @locales = {}
      Dir.glob(Rails.root.join('config', 'locales', '*.yml')).sort.each do |path|
        @locales.merge!(YAML.load_file(path))
      end
    end

    def analytics_vote_count_table(election, utc_offset)
      has_external_vote_count = !election.projects.where('external_vote_count > 0').empty?

      voters_by_date_and_origin = election.valid_voters
        .select("DATE(CONVERT_TZ(created_at, '+00:00', '#{utc_offset}')) AS date, authentication_method, location_id, COUNT(*) AS vote_count")
        .group(:date, :authentication_method, :location_id)
      origins = voters_by_date_and_origin.map(&:origin).uniq
      columns = origins + (has_external_vote_count ? ['External Votes'] : []) + ['Total']

      # vote_counts is a table where each row corresponds to a date and
      # each column corresponds to an origin. (An origin is authentication_method + location_id)
      # SQL can only return 1-D results. So, we have to group 1-D into 2-D results ourselves.
      vote_counts = voters_by_date_and_origin.group_by(&:date).map do |date, voters|
        cols = [0] * origins.length
        voters.each do |voter|
          cols[origins.index(voter.origin)] = voter.vote_count
        end
        if has_external_vote_count
          cols << 0  # add an empty column
        end
        cols << cols.sum  # add a total
        [date, cols]
      end
      if has_external_vote_count  # add a row for the external vote count
        cols = [0] * origins.length
        cols << election.projects.sum(:external_vote_count)
        cols << cols.sum # add total
        vote_counts << [nil, cols]
      end
      totals = columns.length.times.map { |i| vote_counts.map { |r| r[1][i] }.sum }  # add column totals
      [columns, vote_counts, totals]
    end

    def analytics_approval(election, utc_offset, filter)
      approvals = election.projects.joins('LEFT OUTER JOIN vote_approvals ON vote_approvals.project_id = projects.id ' \
        'LEFT OUTER JOIN voters ON voters.id = vote_approvals.voter_id AND ' \
        'voters.void = 0' + (filter.empty? ? '' : (' AND ' + filter)))
        .select('projects.*, COUNT(voters.id) + COALESCE(projects.external_vote_count, 0) AS vote_count')
        .group('projects.id').order('vote_count DESC').map do |p|
        {
          id: p.id,
          title: p.title,
          cost: p.cost,
          vote_count: p.vote_count
        }
      end

      if !current_user.can_see_exact_results?(election)
        approvals.each { |p| p[:vote_count] = p[:vote_count].round(-1) }
      end

      max_approval_vote_count = approvals.map { |p| p[:vote_count] }.max

      approvals_csv = lambda do
        CSV.generate do |csv|
          csv << ["Project", "Cost", "Votes"]
          approvals.each do |p|
            csv << [p[:title], "$"+p[:cost].to_s, p[:vote_count]]
          end
        end
      end

      approvals_individual_csv = lambda do
        raise 'error' unless current_user.can_see_voter_data?(election)

        vote_approvals = election.valid_voters.joins('LEFT OUTER JOIN vote_approvals ON vote_approvals.voter_id = voters.id')
          .select('voters.id, voters.authentication_id, vote_approvals.project_id').order(:id)

        voter_count = election.valid_voters.count
        vote_approvals_matrix = Array.new(voter_count) { Array.new(election.projects.count) { 0 } }
        voter_id_matrix = Array.new(voter_count)
        authentication_id_matrix = Array.new(voter_count)

        projects = election.projects
        project_id_to_index = {}
        projects.each_with_index { |p, index| project_id_to_index[p.id] = index }

        index = -1
        current_voter = -1
        vote_approvals.each do |v|
          if v.id != current_voter
            index += 1
            current_voter = v.id
            voter_id_matrix[index] = current_voter
            authentication_id_matrix[index] = v.authentication_id
          end
          vote_approvals_matrix[index][project_id_to_index[v.project_id]] = 1 if !v.project_id.nil?
        end

        CSV.generate do |csv|
          csv << ['Voter ID'] + ['Authentication ID'] + projects.map(&:title)
          csv << [''] + [''] + projects.map { |p| '$' + p.cost.to_s }
          vote_approvals_matrix.each_with_index do |r, index|
            csv << [voter_id_matrix[index]] + [authentication_id_matrix[index]] + r
          end
        end
      end

      [{
        approvals: approvals,
        max_approval_vote_count: max_approval_vote_count
      }, approvals_csv, approvals_individual_csv]
    end

    def analytics_comparison(election, utc_offset, filter)
      # FIXME: use local projects, don't use @projects

      id_to_index = {}
      @projects.each_with_index { |project, index| id_to_index[project[:id]] = index }

      # comparison_data is an n x n matrix, where n is the number of projects and each element
      # is array of length 3: [# of losses, # of ties, # of wins] by the project on the row.
      comparison_data = Array.new(@projects.length) {Array.new(@projects.length) {[0, 0, 0]}}
      VoteComparison.select('first_project_id, second_project_id, result, COUNT(*) AS vote_count')
              .joins(:voter).where('voters.election_id = ? AND voters.void = 0 AND voters.stage IS NOT NULL' + (filter.empty? ? '' : (' AND ' + filter)), election.id)
              .group('first_project_id, second_project_id, result').each do |v|
        i = id_to_index[v.first_project_id]
        j = id_to_index[v.second_project_id]
        comparison_data[i][j][v.result + 1] = v.vote_count   # min(v.result) = -1, thus we have to add 1.
      end

      # Sort rows and columns by approval vote count, if this election does approval vote.
      comparison_ordered_indices = (0...@projects.length).to_a
      if @approvals
        id_to_vote_counts = {}
        @approvals.each { |p| id_to_vote_counts[p[:id]] = p[:vote_count] }
        comparison_ordered_indices.sort_by! { |i| -id_to_vote_counts[@projects[i][:id]] }
      end

      header = [''] + (1..@projects.length).to_a
      comparison_losses_csv, comparison_ties_csv, comparison_wins_csv, comparison_ratios_csv = [
        ->(c) { c[0] },
        ->(c) { c[1] },
        ->(c) { c[2] },
        ->(c) { (c[2] + 0.5 * c[1]) / (c[0] + c[1] + c[2]) }
      ].map do |f|
        lambda do
          CSV.generate do |csv|
            csv << header
            comparison_ordered_indices.each_with_index do |i, row|
              csv << [(row + 1).to_s + ' "' + @projects[i][:title] + '"'] + comparison_ordered_indices.map do |j|
                f.call(comparison_data[i][j])
              end
            end
          end
        end
      end

      comparison_voters_by_date = election.valid_voters.joins(:vote_comparisons)
        .select("DATE(CONVERT_TZ(voters.created_at, '+00:00', '#{utc_offset}')) AS date, COUNT(DISTINCT voters.id) AS vote_count")
        .group(:date)
      comparison_total = comparison_voters_by_date.map(&:vote_count).sum

      comparisons_individual_csv = lambda do
        raise 'error' unless current_user.can_see_voter_data?(election)

        vote_comparisons = election.valid_voters.joins(:vote_comparisons)
          .select('voters.id, vote_comparisons.first_project_id, vote_comparisons.second_project_id, vote_comparisons.result').order(:id)

        CSV.generate do |csv|
          csv << ["Voter ID", "Project 1 Title", "Project 1 Cost", "Project 2 Title", "Project 2 Cost", "Result"]
          vote_comparisons.each do |r|
            i = id_to_index[r.first_project_id]
            j = id_to_index[r.second_project_id]
            result = (r.result == 0)? 0 : (r.result == 1)? 1 : 2
            csv << [r.id, @projects[i][:title], @projects[i][:cost], @projects[j][:title], @projects[j][:cost], result]
          end
        end
      end

      [{
        comparison_data: comparison_data,
        comparison_ordered_indices: comparison_ordered_indices,
        comparison_voters_by_date: comparison_voters_by_date,
        comparison_total: comparison_total
      }, comparison_losses_csv, comparison_ties_csv, comparison_wins_csv, comparison_ratios_csv, comparisons_individual_csv]
    end

    def group_project_costs_by_id(knapsack_votes)
      # Helper function to transform the knapsack_votes into the form needed by the class KnapsackAllocation
      project_costs = {}
      knapsack_votes.each do |v|
        project_id = v.project_id
        next if project_id.nil?
        if !project_costs.has_key?(project_id)
          project_costs[project_id] = []
        end
        project_costs[project_id] << v.cost
      end
      project_costs
    end

    def analytics_knapsack(election, utc_offset)
      knapsack_projects = election.categorized? ? election.projects.left_outer_joins(:category).where('category_group IN (?) OR category_id IS NULL', election.config[:knapsack][:pages]) : election.projects

      votes_by_project_and_cost = knapsack_projects
        .joins('LEFT OUTER JOIN vote_knapsacks ON vote_knapsacks.project_id = projects.id '\
        'LEFT OUTER JOIN voters ON voters.id = vote_knapsacks.voter_id AND voters.void = 0')
        .select('projects.id, vote_knapsacks.cost AS knapsack_cost, COUNT(voters.id) AS vote_count')
        .group('projects.id, vote_knapsacks.cost')
        .order('vote_count DESC, projects.sort_order')

      if !current_user.can_see_exact_results?(election)
        votes_by_project_and_cost.each { |v| v.vote_count = v.vote_count.round(-1) }
      end

      # ----------------
      # FIXME: Optimize this.
      project_costs = {}
      votes_by_project_and_cost.group_by(&:id).map do |id, ps|
        project_costs[id] = ps.reject { |p| p.knapsack_cost.nil? || p.vote_count == 0 }.map { |p| [p.knapsack_cost] * p.vote_count }.flatten
      end
      partial_allocation_method = case params[:knapsack_partial]
        when "fractional" then :fractional_partial_allocation
        when "equalizing" then :equalizing_partial_allocation
        else :increasing_partial_allocation
      end
      allocation = KnapsackAllocation.new(project_costs, election.budget, KnapsackAllocation.method(partial_allocation_method))
      total_allocations = allocation.total_allocations
      discrete_allocations = allocation.discrete_allocations
      partial_allocations = allocation.partial_allocations
      # ----------------

      knapsack_data = votes_by_project_and_cost.group_by(&:id).map do |id, ps|
        {
          id: id,
          votes: ps.reject { |p| p.knapsack_cost.nil? || p.vote_count == 0 }.sort_by(&:knapsack_cost).reverse.map { |p| [p.knapsack_cost, p.vote_count] },
          allocation: total_allocations[id],
          discrete_allocation: discrete_allocations[id],
          partial_allocation: partial_allocations[id]
        }
      end

      knapsack_max_vote_count = knapsack_data.map { |p| p[:votes].map { |v| v[1] }.sum }.max

      knapsacks_csv = lambda do
=begin
        CSV.generate do |csv|
          csv << ["Project", "Votes"]
          votes_by_project_and_cost.each do |p|
            curr_row = []
            if knapsack_cutoff == p[:title]
              csv << ["BUDGET", "$" + election.budget.to_s]
            end
            csv << [p[:title], p[:vote_count]]
          end
        end
=end
        {}  # FIXME: Make it work.
      end

      knapsack_voters_by_date = election.valid_voters.joins(:vote_knapsacks)
        .select("DATE(CONVERT_TZ(voters.created_at, '+00:00', '#{utc_offset}')) AS date, COUNT(DISTINCT voters.id) AS vote_count")
        .group(:date)
      knapsack_total = knapsack_voters_by_date.map(&:vote_count).sum

      knapsacks_individual_csv = lambda do
        raise 'error' unless current_user.can_see_voter_data?(election)

        valid_voters = election.voters.where("void = 0 AND stage IS NOT NULL")

        vote_knapsacks = valid_voters.joins('LEFT OUTER JOIN vote_knapsacks ON vote_knapsacks.voter_id = voters.id')
          .select('voters.id, voters.stage, vote_knapsacks.project_id, vote_knapsacks.cost').order(:id)

        voter_count = valid_voters.count
        projects = knapsack_projects
        vote_knapsacks_matrix = Array.new(voter_count) { Array.new(projects.count) { 0 } }
        voter_id_matrix = Array.new(voter_count) { [0, ''] }

        project_id_to_index = {}
        projects.each_with_index { |p, index| project_id_to_index[p.id] = index }

        project_costs = group_project_costs_by_id(vote_knapsacks)
        allocation = KnapsackAllocation.new(project_costs, election.budget)
        total_allocations = allocation.total_allocations

        index = -1
        current_voter = -1
        vote_knapsacks.each do |v|
          if v.id != current_voter
            index += 1
            current_voter = v.id
            voter_id_matrix[index] = [current_voter, v.stage]
          end
          vote_knapsacks_matrix[index][project_id_to_index[v.project_id]] = v.cost if !v.project_id.nil?
        end

        CSV.generate do |csv|
          csv << ['Voter ID', 'Voter Stage'] + projects.map(&:title)
          csv << ['Allocation', ''] + projects.map { |p| total_allocations[p.id] }
          vote_knapsacks_matrix.each_with_index do |r, index|
            csv << voter_id_matrix[index] + r
          end
        end
      end

      [{
        knapsack_data: knapsack_data,
        knapsack_max_vote_count: knapsack_max_vote_count,
        knapsack_voters_by_date: knapsack_voters_by_date,
        knapsack_total: knapsack_total,
        knapsack_discrete_vote: allocation.discrete_vote,
        knapsack_partial_project_ids: allocation.partial_project_ids
      }, knapsacks_csv, knapsacks_individual_csv]
    end

    # Analytics for ranking interface
    def analytics_ranking(election)
      projects_to_rank = election.projects
      # FIXME: This is wrong, if an election has both approval and ranking.
      if election.config[:workflow].flatten.include?('ranking') && election.categorized?
        projects_to_rank = election.projects.left_outer_joins(:category).where("category_group IN (?) OR category_id IS NULL", election.config[:ranking][:pages])
      end

      n_projects = projects_to_rank.count
      k = election.config[:ranking][:max_n_projects]

      # [title] [cost] [k projects] [total]
      n_cols = k + 3

      # Generate a 2D matrix mapping project to ranked votes
      project_id_to_index = {}
      project_ranked_votes = Array.new(n_projects) { Array.new(n_cols) { 0 } }

      projects_to_rank.each_with_index do |p, index|
        project_id_to_index[p.id] = index
        project_ranked_votes[index][0] = projects_to_rank.find(p.id).title
        project_ranked_votes[index][1] = projects_to_rank.find(p.id).cost
      end

      votes_by_project_and_rank = projects_to_rank
        .joins('INNER JOIN vote_rankings ON vote_rankings.project_id = projects.id '\
        'INNER JOIN voters ON voters.id = vote_rankings.voter_id AND voters.void = 0')
        .select('vote_rankings.project_id, vote_rankings.rank, COUNT(voters.id) AS vote_count')
        .group('vote_rankings.project_id, vote_rankings.rank')
      if !current_user.can_see_exact_results?(election)
        votes_by_project_and_rank.each { |v| v.vote_count = v.vote_count.round(-1) }
      end
      votes_by_project_and_rank.each do |v|
        project_ranked_votes[project_id_to_index[v.project_id]][v.rank + 1] = v.vote_count
      end

      # Get the total count of the votes in the last column
      for i in 0...n_projects do
        sum_score = 0
        for j in 0...k do
          sum_score += project_ranked_votes[i][j + 2] * project_vote_score(n_projects, k, j + 1)
        end
        project_ranked_votes[i][k + 2] = sum_score
      end

      # Sort in decreasing order of the total count
      project_ranked_votes.sort! { |a, b| b[n_cols - 1] <=> a[n_cols - 1] }

      # The lambda function to generate the CSV for the project vote counts
      ranking_csv = lambda do
        # Generate the headers
        headers = ['Project', 'Cost']
        for i in 1..(n_cols - 3)
          headers << 'Rank' + i.to_s
        end
        headers << 'Total Score'

        CSV.generate do |csv|
          csv << headers

          # Add the rows for the projects
          project_ranked_votes.each do |p|
            csv << p
          end
        end
      end

      # The lambda function to generate the CSV file for the voter data
      ranking_individual_csv = lambda do
        raise 'error' unless current_user.can_see_voter_data?(election)

        ranking_approval_votes = election.valid_voters.joins('JOIN vote_rankings ON vote_rankings.voter_id = voters.id')
          .select('voters.id, vote_rankings.project_id, vote_rankings.rank')
          .order('voters.id, vote_rankings.rank')

        # Get the project title + cost to print
        project_data = {}
        election.projects.each do |p|
          project_data[p.id] = p.title + ' ($' + p.cost.to_s + ')'
        end

        # Generate the headers
        headers = ['Voter ID']

        # Add headers for the ranked projects
        for i in 1..(election.config[:ranking][:max_n_projects])
          headers += ['Rank' + i.to_s]
        end

        # Generate the CSV
        CSV.generate do |csv|
          # Add the headers
          csv << headers
          # Store the current voter and current row so that the projects can be aggregated
          current_voter = -1
          current_row = []
          ranking_approval_votes.each do |r|
            if current_voter != r.id
              csv << current_row if !current_row.empty?
              current_voter = r.id
              current_row = [r.id]
            end
            # Add the project details
            current_row << project_data[r.project_id]
          end
          # Add the last row to the CSV
          csv << current_row if !current_row.empty?
        end
      end

      [{
        project_ranked_votes: project_ranked_votes
      }, ranking_csv, ranking_individual_csv]
    end

    # Analytics for ranking interface (It's legacy because it stores votes in the approval table.)
    def analytics_ranking_legacy(election)
      projects_to_rank = election.projects
      # FIXME: This is wrong, if an election has both approval and ranking.
      if election.config[:workflow].flatten.include?('ranking') && election.categorized?
        projects_to_rank = election.projects.left_outer_joins(:category).where("category_group IN (?) OR category_id IS NULL", election.config[:ranking][:pages])
      end

      n_projects = projects_to_rank.count
      k = election.config[:ranking][:max_n_projects]

      # [title] [cost] [k projects] [total]
      n_cols = k + 3

      # Generate a 2D matrix mapping project to ranked votes
      project_id_to_index = {}
      project_ranked_votes = Array.new(n_projects) { Array.new(n_cols) { 0 } }

      projects_to_rank.each_with_index do |p, index|
        project_id_to_index[p.id] = index
        project_ranked_votes[index][0] = projects_to_rank.find(p.id).title
        project_ranked_votes[index][1] = projects_to_rank.find(p.id).cost
      end

      votes_by_project_and_rank = projects_to_rank
        .joins('INNER JOIN vote_approvals ON vote_approvals.project_id = projects.id '\
        'INNER JOIN voters ON voters.id = vote_approvals.voter_id AND voters.void = 0')
        .select('vote_approvals.project_id, vote_approvals.rank, COUNT(voters.id) AS vote_count')
        .group('vote_approvals.project_id, vote_approvals.rank')
      if !current_user.can_see_exact_results?(election)
        votes_by_project_and_rank.each { |v| v.vote_count = v.vote_count.round(-1) }
      end
      votes_by_project_and_rank.each do |v|
        project_ranked_votes[project_id_to_index[v.project_id]][v.rank + 1] = v.vote_count
      end

      # Get the total count of the votes in the last column
      for i in 0...n_projects do
        sum_score = 0
        for j in 0...k do
          sum_score += project_ranked_votes[i][j + 2] * project_vote_score(n_projects, k, j + 1)
        end
        project_ranked_votes[i][k + 2] = sum_score
      end

      # Sort in decreasing order of the total count
      project_ranked_votes.sort! { |a, b| b[n_cols - 1] <=> a[n_cols - 1] }

      # The lambda function to generate the CSV for the project vote counts
      ranking_csv = lambda do
        # Generate the headers
        headers = ['Project', 'Cost']
        for i in 1..(n_cols - 3)
          headers << 'Rank' + i.to_s
        end
        headers << 'Total Score'

        CSV.generate do |csv|
          csv << headers

          # Add the rows for the projects
          project_ranked_votes.each do |p|
            csv << p
          end
        end
      end

      # The lambda function to generate the CSV file for the voter data
      ranking_individual_csv = lambda do
        raise 'error' unless current_user.can_see_voter_data?(election)

        ranking_approval_votes = election.valid_voters.joins('JOIN vote_approvals ON vote_approvals.voter_id = voters.id')
          .select('voters.id, vote_approvals.project_id, vote_approvals.rank')
          .order('voters.id, vote_approvals.rank')

        # Get the project title + cost to print
        project_data = {}
        election.projects.each do |p|
          project_data[p.id] = p.title + ' ($' + p.cost.to_s + ')'
        end

        # Generate the headers
        headers = ['Voter ID']

        # Add headers for the ranked projects
        for i in 1..(election.config[:ranking][:max_n_projects])
          headers += ['Rank' + i.to_s]
        end

        # Generate the CSV
        CSV.generate do |csv|
          # Add the headers
          csv << headers
          # Store the current voter and current row so that the projects can be aggregated
          current_voter = -1
          current_row = []
          ranking_approval_votes.each do |r|
            if current_voter != r.id
              csv << current_row if !current_row.empty?
              current_voter = r.id
              current_row = [r.id]
            end
            # Add the project details
            current_row << project_data[r.project_id]
          end
          # Add the last row to the CSV
          csv << current_row if !current_row.empty?
        end
      end

      [{
        project_ranked_votes: project_ranked_votes
      }, ranking_csv, ranking_individual_csv]
    end

    # Helper method for ranking approval analytics
    # Method to calculate the score for each project
    def project_vote_score(number_projects, number_votes, rank)
      (number_projects + number_votes - 2*rank + 1).to_f / 2
    end

    # Analytics for the voter registration details - Get CSV
    def analytics_voter_registration(election)
      voter_registration_exists = election.voter_registration_records.exists?

      voter_registration_csv = lambda do
        raise 'error' unless current_user.can_see_voter_data?(election)

        records = election.voter_registration_records
          .joins('LEFT OUTER JOIN voters ON voters.id = voter_registration_records.voter_id AND ' \
          'voters.void = 0')
          .where('voter_id IS NULL OR voters.id IS NOT NULL')

        # Generate the column headers
        voter_registration_questions = election.config[:voter_registration_questions] - ['age_verify']
        headers = ['Record ID', 'Voter ID'] + voter_registration_questions + ['Online or in-person']

        # Generate the CSV
        CSV.generate do |csv|
          csv << headers
          records.each do |record|
            row = [record.id, record.voter_id]

            # Get the voter data for the required fields
            data = record.data
            row += voter_registration_questions.map { |question| data[question] }

            row << (record.user.nil? ? 'online' : 'in-person')

            csv << row
          end
        end
      end

      [voter_registration_exists, voter_registration_csv]
    end

    # Analytics for the voter data. Currently only used by free verification.
    def analytics_voter_data(election)
      voter_data_csv = lambda do
        raise 'error' unless current_user.can_see_voter_data?(election)
        raise 'error' unless election.config[:remote_voting_free_verification]

        voters = election.voters.where('void = 0').order(:id)

        # Generate the column headers
        headers = (!current_user.superadmin? ? ['voter_id'] : []) + ['text_field_value']

        # Generate the CSV
        id = 1
        CSV.generate do |csv|
          csv << headers
          voters.each do |voter|
            row = (!current_user.superadmin? ? [voter.id] : []) + [voter.data["freeform_text"]]
            csv << row
            id += 1
          end
        end
      end

      voter_data_csv
    end

    # The detailed results for each poll site.
    # FIXME: Rename this method.
    def analytics_all_csv_string
      csv_string = analytics_all_csv_string_helper
      csv_string += "\nVoters\n"
      csv_string += "All," + @election.valid_voters.count.to_s + "\n"

      csv_string
    end

    def analytics_all_csv_string_helper(filter = nil)
      project_ids = @election.projects.order(:sort_order).pluck(:id)
      origins = @election.valid_voters.select(:authentication_method, :location_id).group(:authentication_method, :location_id).map(&:origin).uniq

      voters_by_project_and_origin = @election.valid_voters
        .joins(:vote_approvals)
        .select('project_id, authentication_method, location_id, COUNT(*) AS vote_count')
        .where(filter)
        .group(:project_id, :authentication_method, :location_id)

      data = Array.new(project_ids.length) {Array.new(origins.length) { 0 }}
      voters_by_project_and_origin.each do |voter|
        data[project_ids.index(voter.project_id)][origins.index(voter.origin)] += voter.vote_count
      end
      data.each do |row|
        row << row.sum
      end

      header = [''] + [''] + origins.map { |o| (o[:authentication_method] == 'code') ? o[:location].name : o[:authentication_method] } + ['Total']
      csv_string = CSV.generate do |csv|
        csv << header
        data.each_with_index do |row, i|
          csv << [ Project.find(project_ids[i]).title ] + [ '$'+Project.find(project_ids[i]).cost.to_s ] + row
        end
      end
      csv_string
    end
  end
end
