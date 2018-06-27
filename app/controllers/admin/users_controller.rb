module Admin
  class UsersController < ApplicationController
    before_action :set_no_cache
    before_action :require_superadmin_auth, only: [:destroy]  # index, new, create, edit, and update are handled in their methods
    before_action :require_admin_auth, only: [:election_user_destroy]
    before_action :require_user_account, only: [:profile, :edit_profile, :update_profile, :edit_password, :update_password]

    # index page to show users list
    def index
      # This action can be called from two different URLs.
      # And each URL requires a different level of user authentication.
      # We might want to split it into two actions in the future.
      if params.key?(:election_id)
        # This is called from GET /admin/elections/:election_id/users
        require_admin_auth
        return if performed?
        @election = Election.find(params[:election_id])
        @election_users = @election.election_users.includes(:user).order(:status)
      else
        # This is called from GET /admin/users
        require_superadmin_auth
        return if performed?
        @users = User.all
      end
    end

    def new
      # This action can be called from two different URLs.
      # We might want to split it into two actions in the future.
      if params.key?(:election_id)
        # This is called from GET /admin/elections/:election_id/users/new
        require_admin_auth
        return if performed?
        @election = Election.find(params[:election_id])
        @user = User.new
        @election_user = ElectionUser.new
      else
        # This is called from GET /admin/users/new
        require_superadmin_auth
        return if performed?
        @user = User.new
      end
    end

    def create
      # This action can be called from two different URLs.
      # We might want to split it into two actions in the future.
      if params.key?(:election_id)
        # This is called from POST /admin/elections/:election_id/users
        require_admin_auth
        return if performed?
        @election = Election.find(params[:election_id])
        @user = User.new(user_params)
        @election_user = ElectionUser.new(status: params[:status])
      else
        # This is called from POST /admin/users
        require_superadmin_auth
        return if performed?
        @user = User.new(user_params)
        @user.is_superadmin = params[:user][:is_superadmin]
      end

      if count_activity('authenticate_failure', 2.minutes.ago, note: current_user.id) >= 8
        flash.now[:errors] = ['Too many attempts. Please wait two minutes and try again.']
        render action: :new
        return
      end
      if !current_user.authenticate(params[:user][:current_password])
        log_activity('authenticate_failure', note: current_user.id)
        flash.now[:errors] = ['Wrong password']
        render action: :new
        return
      end

      errors = []
      username = params[:user][:username].strip.downcase

      ActiveRecord::Base.transaction do
        if params.key?(:election_id) && !(existing_user = User.find_by(username: username)).nil?
          user = existing_user
          create_new_user = false
        else
          user = @user
          create_new_user = true
        end

        if create_new_user
          if !user.save
            errors += user.errors.full_messages
            raise ActiveRecord::Rollback
          end
        end

        if params.key?(:election_id)
          # Add the user to a specific election.
          election_user = ElectionUser.new(election_id: @election.id, user_id: user.id, status: params[:status])
          if !election_user.save
            errors += election_user.errors.full_messages
            raise ActiveRecord::Rollback
          end
        end

        if create_new_user
          # Send the confirmation email
          generate_new_confirmation_id(user)
          begin
            UserMailer.confirmation_email(user, request.base_url).deliver
          rescue Net::SMTPFatalError => e
            errors << e.message
            raise ActiveRecord::Rollback
          end
        end

        log_activity('user_create', note: user.id.to_s)
      end

      if errors.empty?
        redirect_to({action: :new}, flash: {notice: 'User ' + username + ' created successfully'})
      else
        flash.now[:errors] = errors
        render action: :new
      end
    end

    def edit
      # This action can be called from two different URLs.
      # We might want to split it into two actions in the future.
      if params.key?(:election_id)
        # This is called from GET /admin/elections/:election_id/users/:id/edit
        require_admin_auth
        return if performed?
        @election = Election.find(params[:election_id])
        @user = User.find(params[:id])
        @election_user = ElectionUser.find_by!(user_id: @user.id, election_id: @election.id)
      else
        # This is called from GET /admin/users/:id/edit
        require_superadmin_auth
        return if performed?
        @user = User.find(params[:id])
      end
    end

    def update
      # This action can be called from two different URLs.
      # We might want to split it into two actions in the future.
      if params.key?(:election_id)
        # This is called from PATCH /admin/elections/:election_id/users/:id
        require_admin_auth
        return if performed?
        @election = Election.find(params[:election_id])
        @user = User.find(params[:id])
        @election_user = ElectionUser.find_by!(user_id: @user.id, election_id: @election.id)
        @election_user.status = params[:status]
      else
        # This is called from PATCH /admin/users/:id
        require_superadmin_auth
        return if performed?
        @user = User.find(params[:id])
        @user.is_superadmin = params[:user][:is_superadmin]
      end

      if count_activity('authenticate_failure', 2.minutes.ago, note: current_user.id) >= 8
        flash.now[:errors] = ['Too many attempts. Please wait two minutes and try again.']
        render action: :edit
        return
      end
      if !current_user.authenticate(params[:user][:current_password])
        log_activity('authenticate_failure', note: current_user.id)
        flash.now[:errors] = ['Wrong password']
        render action: :edit
        return
      end

      if params.key?(:election_id)
        @election_user.save!
      else
        @user.save!
      end
      redirect_to action: :index
    end

    def destroy
      user = User.find(params[:id])
      user.destroy
      redirect_to action: :index
    end

    def election_user_destroy
      @user = User.find(params[:id])
      @election = Election.find(params[:election_id])
      election_user = ElectionUser.find_by!(user_id: @user.id, election_id: @election.id)
      log_activity('election_user_destroy', note: @user.id.to_s)

      if election_user.destroy
        redirect_to({action: :index}, flash: {notice: "deleted successfully"})
      else
        redirect_to "/admin/elections/#{@election.id}/users", flash: {errors: "Fail to delete"}
      end
    end

    def profile
      @user = current_user
    end

    def edit_profile
      @user = current_user
    end

    def update_profile
      @user = current_user
      @user.assign_attributes(user_params)
      if count_activity('authenticate_failure', 2.minutes.ago, note: current_user.id) >= 8
        flash.now[:errors] = ['Too many attempts. Please wait two minutes and try again.']
        render action: :edit_profile
        return
      end
      if !current_user.authenticate(params[:user][:current_password])
        log_activity('authenticate_failure', note: current_user.id)
        flash.now[:errors] = ['Wrong password']
        render action: :edit_profile
        return
      end
      if @user.save
        redirect_to({action: :profile}, flash: {notice: "edited successfully"})
      else
        flash.now[:errors] = @user.errors.full_messages
        render action: :edit_profile
      end
    end

    def edit_password
      @user = current_user
    end

    def update_password
      @user = current_user
      if count_activity('authenticate_failure', 2.minutes.ago, note: current_user.id) >= 8
        flash.now[:errors] = ['Too many attempts. Please wait two minutes and try again.']
        render action: :edit_password
        return
      end
      if !current_user.authenticate(params[:user][:current_password])
        log_activity('authenticate_failure', note: current_user.id)
        flash.now[:errors] = ['Wrong current password']
        render action: :edit_password
        return
      end
      @user.password = params[:user][:password]
      @user.password_confirmation = params[:user][:password_confirmation]
      if @user.save
        redirect_to({action: :profile}, flash: {notice: "Changed password successfully"})
      else
        flash.now[:errors] = @user.errors.full_messages
        render action: :edit_password
      end
    end

    def login
      @previous_url = params[:previous_url]
      if current_user.nil? || !@previous_url.blank?
      else
        redirect_to "/admin"
      end
    end

    def post_login
      username = params[:user][:username].strip.downcase
      previous_url = params[:previous_url]

      if count_activity('login_failure', 2.minutes.ago, note: username) >= 8
        flash[:error] = 'Too many login attempts. Please wait two minutes and try logging in again.'
        redirect_to controller: :users, action: :login, previous_url: previous_url
        return
      end

      user = User.find_by(username: username)
      if !user.nil? && user.confirmed && !params[:user][:password].blank? && user.authenticate(params[:user][:password])
        session[:user_id] = user.id
        log_activity('login_success')
        if !previous_url.blank?
          raise 'error' if previous_url.include?(':') || previous_url.include?('.') # To prevent XSS.
          redirect_to previous_url
        else
          if user.superadmin? or user.election_users.count != 1
            redirect_to "/admin"
          else
            election = user.election_users.first.election
            if user.volunteer?(election)
              redirect_to to_voting_machine_admin_election_url(election)
            else
              redirect_to admin_election_url(election)
            end
          end
        end
      else
        log_activity('login_failure', note: username)
        flash[:error] = 'Wrong username and/or password'
        redirect_to controller: :users, action: :login, previous_url: previous_url
      end
    end

    def logout
      log_activity('logout')
      session[:user_id] = nil
      session[:voting_machine_user_id] = nil  # TODO: hacky
      session[:voting_machine_election_id] = nil  # TODO: hacky
      redirect_to action: :login
    end

    # Page to set password. Users can only come to this page through a link
    # that we email them. There are only two situations we email them:
    # 1. New user account
    # 2. Password reset from the "Forgot password?" link
    def validate_confirmation  #FIXME: Better name.
      user = User.find_by(id: params[:id])
      @authentication_status = authenticate_confirmation_id(user, params[:confirmation_id])
      if @authentication_status == :ok
        @confirmation_id = params[:confirmation_id]
      end
    end

    # Set password from the validate_confirmation page.
    def set_password  #FIXME: Better name.
      user = User.find_by(id: params[:id])
      @authentication_status = authenticate_confirmation_id(user, params[:user][:confirmation_id])
      if @authentication_status == :ok
        user.confirmed = true
        user.password = params[:user][:password]
        user.password_confirmation = params[:user][:password_confirmation]
        user.confirmation_id = nil
        if user.save
          session[:user_id] = user.id
          if user.superadmin? || user.election_users.count != 1
            redirect_to "/admin"
          else
            redirect_to admin_election_url(user.election_users.first.election)
          end
        else
          @confirmation_id = params[:user][:confirmation_id]
          flash.now[:errors] = user.errors.full_messages
          render action: :validate_confirmation
        end
      else
        render action: :validate_confirmation
      end
    end

    def post_reset_password
      username = params[:user][:username].strip.downcase

      if count_activity('reset_password', 1.minute.ago, ip_address: request.remote_ip) >= 5
        redirect_to({action: :reset_password}, flash: {errors: ["Please wait one minute and try again."]})
        return
      end

      log_activity('reset_password', note: username)
      user = User.find_by(username: username)
      if !user.nil?
        generate_new_confirmation_id(user)
        UserMailer.reset_password_email(user, request.base_url).deliver
        redirect_to action: :reset_password_email_sent
      else
        redirect_to({action: :reset_password}, flash: {errors: ["Sorry, there is no such user."]})
      end
    end

    def resend_confirmation
      # This action can be called from two different URLs.
      # We might want to split it into two actions in the future.
      if params.key?(:election_id)
        # This is called from GET /admin/elections/:election_id/users/:id/resend_confirmation
        require_admin_auth
        return if performed?
        user = User.find(params[:id])
        election = Election.find(params[:election_id])
        ElectionUser.find_by!(user_id: user.id, election_id: election.id)
      else
        # This is called from GET /admin/users/:id/resend_confirmation
        require_superadmin_auth
        return if performed?
        user = User.find(params[:id])
      end
      if confirmation_id_expired?(user)
        generate_new_confirmation_id(user)
      end
      UserMailer.confirmation_email(user, request.base_url).deliver
      redirect_to({action: :index}, flash: {notice: "Confirmation sent"})
    end

    private

    def user_params
      params.require('user').permit(:username)
    end

    def generate_new_confirmation_id(user)
      chars = (('a'..'z').to_a + ('0'..'9').to_a) - ['o', '0', '1', 'l', 'q']
      user.confirmation_id = (0...32).map { chars.sample }.join
      user.confirmation_id_created_at = Time.now
      user.save!
    end

    def confirmation_id_expired?(user)
      Time.now - user.confirmation_id_created_at > 1.week
    end

    def authenticate_confirmation_id(user, confirmation_id)
      if count_activity('validate_confirmation_failure', 2.minutes.ago, note: params[:id]) >= 5
        return :over_rate_limit
      end

      if !user.nil? && !user.confirmation_id.blank? && confirmation_id == user.confirmation_id
        if confirmation_id_expired?(user)
          return :expired
        end
        return :ok
      end

      log_activity('validate_confirmation_failure', note: params[:id])
      return :error
    end
  end
end
