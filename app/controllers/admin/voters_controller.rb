module Admin
  class VotersController < ApplicationController
    before_action :set_no_cache
    before_action :require_superadmin_auth

    def index
      @election = Election.find(params[:election_id])
      @voters = @election.voters.includes(:location, :voter_registration_record).order(:id)
    end

    def show
      @election = Election.find(params[:election_id])
      @voter = Voter.find(params[:id])
    end

    def destroy
      election = Election.find(params[:election_id])
      voter = Voter.find(params[:id])

      # This action is dangerous. Only allow removing test votes for now.
      return unless voter.authentication_id.start_with?('_test')

      log_activity('voter_destroy', note: voter.id)
      voter.destroy
      redirect_to admin_election_voters_path(election)
    end

    def update
      voter = Voter.find(params[:id])
      voter.update_attribute(:void, params[:void] != '0')

      respond_to do |format|
        format.html { redirect_to action: :index }
        format.json { render json: {}, status: :ok }
      end
    end
  end
end
