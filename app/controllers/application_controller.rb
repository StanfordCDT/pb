class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  include ActionView::Helpers::NumberHelper
  protect_from_forgery with: :exception
  helper_method :current_user, :cost_with_delimiter
  before_action :set_locale

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def set_no_cache
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
  end

  def no_access
    flash[:error] = "Sorry, you do not have the access to this page."
    redirect_to_login_page
  end

  # Only allows superadmins.
  def require_superadmin_auth
    no_access unless !current_user.nil? && current_user.superadmin?
  end

  # Only allows superadmins and admins of the current election.
  def require_admin_auth
    # Note: This method only checks that the user is an admin of the election.
    # It does NOT check that the resource the user is trying to access belongs
    # to the election.
    #
    # For example, say the user is going to /admin/elections/5/project/123/edit.
    # This method only checks that the user is an admin of Election 5. It does NOT
    # check that Project 123 is a project of Election 5.
    #
    # Therefore, if you implement ProjectsController#edit, you should NEVER do this:
    #   project = Project.find(params[:id])
    # This is highly INSECURE, because it allows the user to access any project.
    #
    # Do this instead:
    #   election = Election.find(params[:election_id])
    #   project = election.projects.find(params[:id])

    no_access unless has_auth?(:admin?, false)
  end

  # Only allows superadmins, admins, and volunteers of the current election.
  def require_admin_or_volunteer_auth
    # Note: The comment in require_admin_auth also applies to this method.
    no_access unless has_auth?(:admin_or_volunteer?, false)
  end

  # Only allows superadmins and (admins with a special permission) of the current election.
  # A "special permission" means that election.allow_admins_to_update_election is true.
  def require_admin_auth_with_special_permission
    # Note: The comment in require_admin_auth also applies to this method.
    no_access unless has_auth?(:admin?, true)
  end

  # Only allows anyone with a user account, i.e.,
  # superadmins, admins, and volunteers of ANY election.
  def require_user_account
    no_access unless !current_user.nil?
  end

  def has_auth?(status_checking_method, require_special_permission)
    return false if current_user.nil?
    return true if current_user.superadmin?

    if params[:controller] == 'admin/elections'
      election_id = params[:id]
    else  # Nested resources under elections
      election_id = params[:election_id]
    end
    return false if election_id.nil?

    election = Election.find_by_id(election_id)
    return election && current_user.send(status_checking_method, election) && (!require_special_permission || election.allow_admins_to_update_election?)
  end

  def log_activity(activity, opts={})
    log = ActivityLog.new
    log.user = current_user
    log.activity = activity
    log.note = opts[:note]
    log.ip_address = request.remote_ip
    log.user_agent = request.env['HTTP_USER_AGENT']
    log.save!
  end

  def count_activity(activity, since, opts={})
    ActivityLog.where("activity = ? AND created_at >= ?", activity, since).where(opts).count
  end

  def redirect_to_login_page
    previous_url = (request.get? && request.fullpath != '/admin') ? request.fullpath : nil
    redirect_to controller: 'admin/users', action: :login, previous_url: previous_url
  end

  def default_url_options(options=nil)
    o = {}
    o[:locale] = I18n.locale if I18n.locale != I18n.default_locale
    o[:campaign] = params[:campaign] if params[:campaign]
    o
  end

  def set_locale
    # See http://guides.rubyonrails.org/i18n.html#setting-the-locale-from-the-url-params
    I18n.locale = params[:locale] || I18n.default_locale
  end

  def cost_with_delimiter(cost)
    if I18n.locale == :fr
      number_with_delimiter(cost, delimiter: " ", separator: ",") + ' $'
    else
      '$' + number_with_delimiter(cost)
    end
  end
end
