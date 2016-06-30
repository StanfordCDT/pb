module Admin
  class LocationsController < ApplicationController
    before_action :set_no_cache
    before_action :require_superadmin_auth

    def index
      @election = Election.find(params[:election_id])
      @locations = @election.locations.order(:name)
    end

    def show
      @election = Election.find(params[:election_id])
      @location = Location.find(params[:id])
    end

    def new
      @election = Election.find(params[:election_id])
      @location = Location.new
    end

    def create
      @election = Election.find(params[:election_id])
      @location = Location.new(location_params)
      @location.election = @election
      if @location.save
        redirect_to admin_election_locations_path(@election)
      else
        render :new
      end
    end

    def edit
      @election = Election.find(params[:election_id])
      @location = Location.find(params[:id])
    end

    def update
      @election = Election.find(params[:election_id])
      @location = Location.find(params[:id])
      if @location.update(location_params)
        redirect_to admin_election_locations_path(@election)
      else
        render :edit
      end
    end

    def destroy
      election = Election.find(params[:election_id])
      location = Location.find(params[:id])
      if !location.voters.empty?
        flash[:errors] = ['Can\'t delete the location "' + location.name + '" because '\
          'it has already received some votes. If they are all test votes, please delete '\
          'them before deleting this location.']
        redirect_to admin_election_locations_path(election)
        return
      end
      location.destroy
      redirect_to admin_election_locations_path(election)
    end

    private

    def location_params
      params.require(:location).permit(:name)
    end
  end
end
