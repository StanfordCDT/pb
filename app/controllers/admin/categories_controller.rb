module Admin
  class CategoriesController < ApplicationController
    before_action :set_no_cache
    before_action :require_admin_auth

    def new
      @election = Election.find(params[:election_id])
      raise "error" if !current_user.can_update_election?(@election)
      @category = Category.new
    end

    def create
      @election = Election.find(params[:election_id])
      raise "error" if !current_user.can_update_election?(@election)
      @category = Category.new(category_params)
      @category.election = @election
      @category.sort_order = @election.categories.maximum(:sort_order).to_i + 1
      if @category.save
        redirect_to admin_election_projects_path(@election)
      else
        render :new
      end
    end

    def edit
      @election = Election.find(params[:election_id])
      raise "error" if !current_user.can_update_election?(@election)
      @category = @election.categories.find(params[:id])
    end

    def update
      @election = Election.find(params[:election_id])
      raise "error" if !current_user.can_update_election?(@election)
      @category = @election.categories.find(params[:id])
      if @category.update(category_params)
        redirect_to admin_election_projects_path(@election)
      else
        render :edit
      end
    end

    def destroy
      election = Election.find(params[:election_id])
      raise "error" if !current_user.can_update_election?(election)
      category = election.categories.find(params[:id])
      category.destroy
      redirect_to admin_election_projects_path(election)
    end

    def reorder
      election = Election.find(params[:election_id])
      raise "error" if !current_user.can_update_election?(election)
      category_ids = params[:category_ids].map(&:to_i)
      election.categories.each do |category|
        category.update_attribute(:sort_order, category_ids.index(category.id))
      end
      render json: {}
    end

    private

    def category_params
      params.require(:category).permit([:image, :image_cache, :remove_image, :pinned, :category_group] + Category.globalize_attribute_names)
    end
  end
end
