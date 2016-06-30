module Admin
  class VoterRegistrationRecordsController < ApplicationController
    before_action :set_no_cache
    before_action :require_admin_auth

    def index
      @election = Election.find(params[:election_id])
      load_records
      @record = VoterRegistrationRecord.new

      # This is hacky. This is to allow the config to overwrite the strings in locales/*.yml
      # so that we can use custom <%= t('registration.verify_age_label') %>, etc.
      Thread.current[:i18n_locales] = @election.config[:locales]
    end

    def create
      @election = Election.find(params[:election_id])

      voter_registration_record_params = params.require(:voter_registration_record).permit(@election.config[:voter_registration_questions] - ["age_verify"])
      @record = VoterRegistrationRecord.new(voter_registration_record_params)
      @record.election_id = @election.id
      @record.user_id = current_user.id
      if @record.save
        flash[:notice] = 'New voter record created successfully.'
        redirect_to action: :index
      else
        load_records
        Thread.current[:i18n_locales] = @election.config[:locales]
        render :index
      end
    end

    def destroy
      election = Election.find(params[:election_id])
      record = VoterRegistrationRecord.find(params[:id])
      raise 'error' if record.user_id != current_user.id
      record.destroy
      redirect_to action: :index
    end

    private

    def load_records
      @records = @election.voter_registration_records.where(user_id: current_user.id).last(5)
      @questions = @election.config[:voter_registration_questions] - ["age_verify"]
    end
  end
end
