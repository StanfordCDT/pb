module Admin
  require 'csv'
  require_relative "./knapsack_allocation"
  class ElectionsController < ApplicationController
    before_action :set_no_cache
    before_action :require_superadmin_auth, only: [:new, :create, :destroy]
    before_action :require_admin_auth_with_special_permission, only: [:edit, :update]
    before_action :require_admin_auth, only: [:analytics, :analytics_more, :analytics_adjustable_cost_projects, :analytics_chicago49]
    before_action :require_admin_or_volunteer_auth, only: [:show, :to_voting_machine, :post_to_voting_machine]
    before_action :require_user_account, only: [:config_reference]
    helper_method :is_allowed_to_see_voter_data?, :is_allowed_to_see_exact_results?

    def show
      @election = Election.find(params[:id])
    end

    def new
      @election = Election.new
      load_config_description_and_locales  # hacky
    end

    def create
      @election = Election.new(election_params)
      if @election.save
        redirect_to admin_election_path(@election)
      else
        load_config_description_and_locales  # hacky
        render :new
      end
    end

    def edit
      @election = Election.find(params[:id])
      load_config_description_and_locales  # hacky
    end

    def update
      @election = Election.find(params[:id])

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

      @projects = @election.projects.map do |p|
        {
          id: p.id,
          title: p.title,
          cost: p.cost,
          adjustable_cost: p.adjustable_cost,
        }
      end

      # code for the vote count table
      @total_vote_count = @election.valid_voters.count
      @columns, @vote_counts, @totals = analytics_vote_count_table(@election, utc_offset)

      if workflow.include?('approval')
        @approvals, @max_approval_vote_count, approvals_csv, approvals_individual_csv =
          analytics_approval(@election, utc_offset, filter)
      end

      if workflow.include?('knapsack')
        @knapsack_data, @knapsack_max_vote_count, knapsacks_csv, @knapsack_voters_by_date, @knapsack_total, knapsacks_individual_csv =
          analytics_knapsack(@election, utc_offset)
      end

      if workflow.include?('plusminus')
        @plusminus, plusminus_csv, @plusminus_voters_by_date, @plusminus_total, plusminuses_individual_csv =
          analytics_plusminus(@election, utc_offset)
      end

      if workflow.include?('comparison')
        @comparison_data, @comparison_ordered_indices, comparison_losses_csv, comparison_ties_csv, comparison_wins_csv, comparison_ratios_csv, @comparison_voters_by_date, @comparison_total, comparisons_individual_csv =
          analytics_comparison(@election, utc_offset, filter)
      end

      if @election.config[:thanks_approval][:survey_questions]
        @thanks_approval_survey_data, thanks_approval_survey_csv = analytics_thanks_approval(@election)
      end

      @voter_registration_exists, voter_registration_csv = analytics_voter_registration(@election)

      if @election.config[:approval][:project_ranking] || workflow.include?('ranking')
        @project_ranked_votes, project_ranked_votes_csv = analytics_ranking_approval(@election)
      end

      respond_to do |format|
        format.html {}
        format.json do
          render json: {
          }
        end
        format.csv do
          table = params[:table]
          csv_string = case table.to_sym
            when :all then analytics_all_csv_string
            when :approvals then approvals_csv.call
            when :knapsacks then knapsacks_csv.call
            when :plusminus then plusminus_csv.call
            when :comparison_wins then comparison_wins_csv.call
            when :comparison_ties then comparison_ties_csv.call
            when :comparison_losses then comparison_losses_csv.call
            when :comparison_ratios then comparison_ratios_csv.call
            when :approvals_individual then approvals_individual_csv.call
            when :knapsacks_individual then knapsacks_individual_csv.call
            when :plusminuses_individual then plusminuses_individual_csv.call
            when :comparisons_individual then comparisons_individual_csv.call
            when :thanks_approval_survey then thanks_approval_survey_csv.call
            when :voter_registration then voter_registration_csv.call
            when :project_ranked_votes then project_ranked_votes_csv.call
            else raise 'error'
          end
          send_data csv_string, type: Mime::CSV, disposition: "attachment; filename=" + @election.slug + "-" + table + ".csv"
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

        if !is_allowed_to_see_exact_results?
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
          ls[locales.index(voter.data['locale'])] = '1'

          csv << [(i+1).to_s] + cs + [''] + ls
        end
      end
      send_data csv_string, type: Mime::CSV, disposition: "attachment; filename=pb" + @election.slug + ".csv"
    end

    def to_voting_machine
      @election = Election.find(params[:id])
      @locations = @election.locations.order(:name)
    end

    def post_to_voting_machine
      @election = Election.find(params[:id])
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
        (current_user.superadmin? ? [:allow_admins_to_update_election, :allow_admins_to_see_voter_data, :allow_admins_to_see_exact_results] : [])
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

      if !is_allowed_to_see_exact_results?
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
        raise 'error' unless is_allowed_to_see_voter_data?

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

      [approvals, max_approval_vote_count, approvals_csv, approvals_individual_csv]
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
        raise 'error' unless is_allowed_to_see_voter_data?

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

      [comparison_data, comparison_ordered_indices, comparison_losses_csv, comparison_ties_csv, comparison_wins_csv, comparison_ratios_csv, comparison_voters_by_date, comparison_total, comparisons_individual_csv]
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
      knapsack_projects = election.config[:categorized] ? election.projects.joins(:category).where('category_group IN (?)', election.config[:knapsack][:pages]) : election.projects

      votes_by_project_and_cost = knapsack_projects
        .joins('LEFT OUTER JOIN vote_knapsacks ON vote_knapsacks.project_id = projects.id '\
        'LEFT OUTER JOIN voters ON voters.id = vote_knapsacks.voter_id AND voters.void = 0')
        .select('projects.id, vote_knapsacks.cost AS knapsack_cost, COUNT(voters.id) AS vote_count')
        .group('projects.id, vote_knapsacks.cost')
        .order('vote_count DESC, projects.sort_order')

      if !is_allowed_to_see_exact_results?
        votes_by_project_and_cost.each { |v| v.vote_count = v.vote_count.round(-1) }
      end

      # ----------------
      # FIXME: Optimize this.
      project_costs = {}
      votes_by_project_and_cost.group_by(&:id).map do |id, ps|
        project_costs[id] = ps.reject { |p| p.knapsack_cost.nil? || p.vote_count == 0 }.map { |p| [p.knapsack_cost] * p.vote_count }.flatten
      end
      allocation = KnapsackAllocation.new(project_costs, election.budget)
      total_allocations = allocation.total_allocations
      # ----------------

      knapsack_data = votes_by_project_and_cost.group_by(&:id).map do |id, ps|
        {
          id: id,
          votes: ps.reject { |p| p.knapsack_cost.nil? || p.vote_count == 0 }.sort_by(&:knapsack_cost).map { |p| [p.knapsack_cost, p.vote_count] },
          allocation: total_allocations[id]
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
        raise 'error' unless is_allowed_to_see_voter_data?

        vote_knapsacks = election.valid_voters.joins('LEFT OUTER JOIN vote_knapsacks ON vote_knapsacks.voter_id = voters.id')
          .select('voters.id, vote_knapsacks.project_id, vote_knapsacks.cost').order(:id)

        voter_count = election.valid_voters.count
        projects = knapsack_projects
        vote_knapsacks_matrix = Array.new(voter_count) { Array.new(projects.count) { 0 } }
        voter_id_matrix = Array.new(voter_count) { 0 }

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
            voter_id_matrix[index] = current_voter
          end
          vote_knapsacks_matrix[index][project_id_to_index[v.project_id]] = v.cost if !v.project_id.nil?
        end

        CSV.generate do |csv|
          csv << ['Voter ID'] + projects.map(&:title)
          csv << ['Allocation'] + projects.map { |p| total_allocations[p.id] }
          vote_knapsacks_matrix.each_with_index do |r, index|
            csv << [voter_id_matrix[index]] + r
          end
        end
      end

      [knapsack_data, knapsack_max_vote_count, knapsacks_csv, knapsack_voters_by_date, knapsack_total, knapsacks_individual_csv]
    end

    def analytics_plusminus(election, utc_offset)
      # FIXME: use voters.void = 0
      plusminus = election.projects
        .joins('LEFT OUTER JOIN vote_plusminuses ON vote_plusminuses.project_id = projects.id')
        .select('projects.*, SUM(plusminus) AS netvotes, SUM(plusminus=1) AS upvotes, SUM(plusminus=-1) AS downvotes')
        .group('projects.id').map do |p|
        {
          id: p.id,
          title: p.title,
          netvotes: p.netvotes.to_i,  # use to_i to convert nil to 0
          upvotes: p.upvotes.to_i,
          downvotes: p.downvotes.to_i,
        }
      end

      plusminus_csv = lambda do
        CSV.generate do |csv|
          csv << ["Project", "Net-upvotes", "Upvotes", "Downvotes"]
          plusminus.each do |p|
            csv << [p[:title], p[:netvotes], p[:upvotes], p[:downvotes]]
          end
        end
      end

      plusminus_voters_by_date = election.valid_voters.joins(:vote_plusminuses)
        .select("DATE(CONVERT_TZ(voters.created_at, '+00:00', '#{utc_offset}')) AS date, COUNT(DISTINCT voters.id) AS vote_count")
        .group(:date)
      plusminus_total = plusminus_voters_by_date.map(&:vote_count).sum

      plusminuses_individual_csv = lambda do
        raise 'error' unless is_allowed_to_see_voter_data?

        # FIXME: This is not accurate, because it counts void votes. Do the same thing as knapsack.
        vote_plusminuses = election.projects.joins('JOIN vote_plusminuses ON vote_plusminuses.project_id = projects.id ' \
          'LEFT OUTER JOIN voters ON voters.id = vote_plusminuses.voter_id AND voters.void = 0')
          .select('vote_plusminuses.*').map do |v|
          {
            id: v.voter_id,
            project_id: v.project_id,
            plusminus: v.plusminus
          }
        end

        voter_count = election.valid_voters.count
        vote_plusminuses_matrix = Array.new(voter_count) { Array.new(election.projects.count) { 0 } }
        voters_matrix = Array.new(voter_count) { 0 }

        projects = election.projects
        project_id_to_index = {}
        projects.each_with_index { |p, index| project_id_to_index[p.id] = index }

        index = -1
        current_voter = -1
        vote_plusminuses.each do |v|
          if v[:id] != current_voter
            index += 1
            current_voter = v[:id]
            voters_matrix[index] = current_voter
          end
          vote_plusminuses_matrix[index][project_id_to_index[v[:project_id]]] = v[:plusminus]
        end

        CSV.generate do |csv|
          csv << ['Voter ID'] + projects.map(&:title)
          csv << [''] + projects.map { |p| '$' + p.cost.to_s }
          vote_plusminuses_matrix.each_with_index do |r, index|
            if voters_matrix[index] != 0
              csv << [voters_matrix[index]] + r
            end
          end
        end
      end

      [plusminus, plusminus_csv, plusminus_voters_by_date, plusminus_total, plusminuses_individual_csv]
    end

    # Analytics for ranking approval interface
    def analytics_ranking_approval(election)
      projects_to_rank = election.projects
      # FIXME: This is wrong, if an election has both approval and ranking.
      if election.config[:workflow].flatten.include?('ranking') && election.config[:categorized]
        projects_to_rank = election.projects.joins(:category).where("category_group IN (?)", election.config[:ranking][:pages])
      end

      n_projects = projects_to_rank.count

      # 3 = 1 + 1 + 1: 1 for Project title, 1 for project cost, 1 for total score
      n_cols = election.config[:ranking][:max_n_projects] + 3

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
      if !is_allowed_to_see_exact_results?
        votes_by_project_and_rank.each { |v| v.vote_count = v.vote_count.round(-1) }
      end
      votes_by_project_and_rank.each do |v|
        project_ranked_votes[project_id_to_index[v.project_id]][v.rank + 1] = v.vote_count
      end

      # Get the total count of the votes in the last column
      start_j = 2
      for i in 0...n_projects do
        for j in start_j..(n_cols - 2) do
          project_ranked_votes[i][n_cols - 1] +=
            project_ranked_votes[i][j] * project_vote_score(n_projects, n_cols - 3, j - 1)
        end
      end

      # Sort in decreasing order of the total count
      project_ranked_votes.sort! { |a, b| b[n_cols - 1] <=> a[n_cols - 1] }

      # The lambda function to generate the CSV for the project vote counts
      project_ranked_votes_csv = lambda do
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

=begin
      # Get the project title + cost to print
      project_data = {}
      election.projects.each do |p|
        project_data[p.id] = p.title + ' ($' + p.cost.to_s + ')'
      end
=end

      [project_ranked_votes, project_ranked_votes_csv]
    end

    # Helper method for ranking approval analytics
    # Method to calculate the score for each project
    def project_vote_score(number_projects, number_votes, rank)
      (number_projects + number_votes - 2*rank + 1).to_f / 2
    end

    # Analytics for the thanks_approval survey - Get CSV
    def analytics_thanks_approval(election)
      voter_survey_data = election.valid_voters.select("id, data")

      thanks_approval_survey_csv = lambda do
        raise 'error' unless is_allowed_to_see_voter_data?

        # Generate the column headers
        headers = ['Voter ID', 'Age', 'Gender', 'Household Income', 'Ethnicity']

        # Generate the CSV
        CSV.generate do |csv|
          csv << headers
          voter_survey_data.each do |r|
            # Get the voter data for the required fields
            data_row = [r.id, r.data['age'], r.data['gender'], r.data['household_income'], r.data['ethnicity']]
            csv << data_row
          end
        end
      end

      [voter_survey_data, thanks_approval_survey_csv]
    end

    # Analytics for the voter registration details - Get CSV
    def analytics_voter_registration(election)
      voter_registration_exists = election.voter_registration_records.exists?

      voter_registration_csv = lambda do
        raise 'error' unless is_allowed_to_see_voter_data?

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

    def is_allowed_to_see_voter_data?
      current_user.superadmin? || @election.allow_admins_to_see_voter_data?
    end

    def is_allowed_to_see_exact_results?
      current_user.superadmin? || @election.allow_admins_to_see_exact_results?
    end
  end
end
