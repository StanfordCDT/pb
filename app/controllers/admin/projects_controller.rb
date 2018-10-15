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

    private

    def project_params
      params.require(:project).permit([:number, :cost, :cost_step, :cost_min, :adjustable_cost, :uses_slider, :map_geometry, :category_id, :image, :image_cache, :remove_image, :external_vote_count, :data] + Project.globalize_attribute_names)
    end
  end
end
