module Admin
  class ProjectsController < ApplicationController
    before_action :set_no_cache
    before_action :require_admin_auth

    def index
      @election = Election.find(params[:election_id])
      @projects = @election.projects.order(:sort_order)
      @categories = @election.categories.order(:sort_order)
    end

    def new
      @election = Election.find(params[:election_id])
      raise "error" if !current_user.can_update_election?(@election)
      @project = Project.new
    end

    def create
      @election = Election.find(params[:election_id])
      raise "error" if !current_user.can_update_election?(@election)
      @project = Project.new(project_params)
      @project.election = @election
      @project.sort_order = @election.projects.maximum(:sort_order).to_i + 1
      if @project.save
        redirect_to admin_election_projects_path(@election)
      else
        render :new
      end
    end

    def edit
      @election = Election.find(params[:election_id])
      raise "error" if !current_user.can_update_election?(@election)
      @project = @election.projects.find(params[:id])
    end

    def update
      @election = Election.find(params[:election_id])
      raise "error" if !current_user.can_update_election?(@election)
      @project = @election.projects.find(params[:id])
      if @project.update(project_params)
        redirect_to admin_election_projects_path(@election)
      else
        render :edit
      end
    end

    def destroy
      election = Election.find(params[:election_id])
      raise "error" if !current_user.can_update_election?(election)
      project = election.projects.find(params[:id])
      project.destroy
      redirect_to admin_election_projects_path(election)
    end

    def reorder
      election = Election.find(params[:election_id])
      raise "error" if !current_user.can_update_election?(election)
      project_ids = params[:project_ids].map(&:to_i)
      election.projects.each do |project|
        project.update_attribute(:sort_order, project_ids.index(project.id))
      end
      render json: {}
    end

    def import
      @election = Election.find(params[:election_id])
      raise "error" if !current_user.can_update_election?(@election)
    end

    def post_import
      require 'roo'

      @election = Election.find(params[:election_id])
      raise "error" if !current_user.can_update_election?(@election)

      import_file = params[:project][:import_file] if !params[:project].nil?
      if import_file.nil?
        redirect_to action: :import
        return
      end

      # Read the file according to their format.
      filename = import_file.original_filename
      if filename.end_with?(".xlsx") || filename.end_with?(".xls")  # Excel
        begin
          xlsx = Roo::Spreadsheet.open(import_file, extension: filename.end_with?(".xls") ? :xls : :xlsx)
        rescue
          flash.now[:errors] = ["Cannot open the Excel file"]
          render action: :import
          return
        end
        sheet = xlsx.sheet(0)
        header = sheet.row(1)
        rows = (2..sheet.last_row).map { |i| sheet.row(i) }
      else  # CSV
        csv = CSV.new(import_file.read.force_encoding("UTF-8").sub(/^\xEF\xBB\xBF/, "").encode)  # Remove UTF-8 BOM.
        table = csv.read
        header = table[0]
        rows = table[1...table.length]
      end

      # Find the indices of the columns.
      header = header.map { |col| col.strip.downcase if col.is_a?(String) }
      title_index = header.find_index { |col| col == "title" || col == "titles" }
      description_index = header.find_index { |col| col == "description" || col == "descriptions" }
      cost_index = header.find_index { |col| col == "cost" || col == "costs" }
      number_index = header.find_index { |col| col == "number" || col == "numbers" }
      details_index = header.find_index("details")
      address_index = header.find_index { |col| col == "location" || col == "locations" }
      category_index = header.find_index { |col| col == "category" || col == "categories" }

      errors = []
      if title_index.nil?
        errors << "Cannot find the title column"
      end
      if description_index.nil?
        errors << "Cannot find the description column"
      end
      if cost_index.nil?
        errors << "Cannot find the cost column"
      end

      def parse_cost(str)
        # Remove currency symbols.
        str = str.sub(/^(\$|€|£|¥|₹|zł)/, "").sub(/(\$|€|£|¥|₹|zł)$/, "")
        begin
          Integer(str)
        rescue ArgumentError
          nil
        end
      end

      # Read the contents.
      if !title_index.nil? && !description_index.nil? && !cost_index.nil?
        ActiveRecord::Base.transaction do
          @election.voters.destroy_all
          @election.categories.destroy_all
          @election.projects.destroy_all

          category_sort_order = 0
          category_map = {}
          project_sort_order = 0

          Globalize.with_locale(@election.config[:default_locale]) do
            for row in rows
              next if row.all?(&:nil?)

              # Create a category (if needed).
              category = nil
              if !category_index.nil?
                category_name = row[category_index]
                if !category_name.blank?
                  if category_map.key?(category_name)
                    category = category_map[category_name]
                  else
                    category = Category.new
                    category.name = category_name
                    category.sort_order = category_sort_order
                    category.election = @election
                    if !category.save
                      errors += category.errors.full_messages
                      raise ActiveRecord::Rollback
                    end
                    category_sort_order += 1
                    category_map[category_name] = category
                  end
                end
              end

              # Create a project.
              project = Project.new
              project.title = row[title_index].to_s.strip
              cost = parse_cost(row[cost_index])
              if cost.nil?
                errors << "Cannot parse \"" + row[cost_index] + "\" as a cost. Make sure to remove all the digit group separators such as commas from the cost."
                raise ActiveRecord::Rollback
              end
              project.cost = cost
              project.description = row[description_index].to_s.strip
              project.number = row[number_index] if !number_index.nil?
              project.details = row[details_index] if !details_index.nil?
              project.address = row[address_index] if !address_index.nil?
              project.sort_order = project_sort_order
              project.election = @election
              project.category = category if !category.nil?
              if !project.save
                errors += project.errors.full_messages
                raise ActiveRecord::Rollback
              end
              project_sort_order += 1
            end
          end
        end
      end

      if errors.empty?
        redirect_to admin_election_projects_path(@election)
      else
        flash.now[:errors] = errors
        render action: :import
      end
    end

    def export
      election = Election.find(params[:election_id])
      projects = election.projects.order(:sort_order)

      rows = []
      Globalize.with_locale(election.config[:default_locale]) do
        use_number = projects.any? { |p| !p.number.blank? }
        use_address = projects.any? { |p| !p.address.blank? }
        use_details = projects.any? { |p| !p.details.blank? }
        use_category = projects.any? { |p| !p.category.nil? }

        header = []
        header << "Number" if use_number
        header += ["Title", "Description", "Cost"]
        header << "Location" if use_address
        header << "Details" if use_details
        header << "Category" if use_category
        rows << header
        projects.each do |p|
          row = []
          row << p.number if use_number
          row += [p.title, p.description, p.cost]
          row << p.address if use_address
          row << p.details if use_details
          row << (p.category.nil? ? "" : p.category.name) if use_category
          rows << row
        end
      end

      respond_to do |format|
        format.csv do
          csv_string = CSV.generate do |csv|
            rows.each { |row| csv << row }
          end
          send_data csv_string, type: :csv, disposition: "attachment; filename=projects.csv"
        end
      end
    end

    private

    def project_params
      params.require(:project).permit([:number, :cost, :cost_step, :cost_min, :adjustable_cost, :uses_slider, :map_geometry, :category_id, :image, :image_cache, :remove_image, :external_vote_count, :data] + Project.globalize_attribute_names)
    end
  end
end
