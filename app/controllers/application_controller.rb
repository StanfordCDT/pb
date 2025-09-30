class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  include ActionView::Helpers::NumberHelper
  protect_from_forgery with: :exception
  helper_method :current_user, :cost_with_delimiter
  before_action :set_locale
  before_action :record_visitor

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

    no_access unless has_auth?(:admin?)
  end

  # Only allows superadmins, admins, and volunteers of the current election.
  def require_admin_or_volunteer_auth
    # Note: The comment in require_admin_auth also applies to this method.
    no_access unless has_auth?(:admin_or_volunteer?)
  end

  # Only allows anyone with a user account, i.e.,
  # superadmins, admins, and volunteers of ANY election.
  def require_user_account
    no_access unless !current_user.nil?
  end

  def has_auth?(status_checking_method)
    return false if current_user.nil?
    return true if current_user.superadmin?

    if params[:controller] == 'admin/elections'
      election_id = params[:id]
    else  # Nested resources under elections
      election_id = params[:election_id]
    end
    return false if election_id.nil?

    election = Election.find_by_id(election_id)
    return election && current_user.send(status_checking_method, election)
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

  def record_visitor
    connection = ActiveRecord::Base.connection
    ip = connection.quote(request.remote_ip)
    user_agent = connection.quote(request.env['HTTP_USER_AGENT'])
    referrer = connection.quote(request.referer)
    url = connection.quote(request.url)
    request_method = connection.quote(request.method)
    election_id = connection.quote(determine_election_id_from_url(request.url))
    connection.execute("INSERT INTO visitors (ip_address, user_agent, referrer, url, method, election_id, created_at) VALUES (#{ip}, #{user_agent}, #{referrer}, #{url}, #{request_method}, #{election_id}, NOW())")
  end

  def determine_election_id_from_url(url)
    begin
      bases = ["http://localhost:3000/", "https://pbstanford.org/"]
      
      base = bases.find { |b| url.start_with?(b) }
      unless base
        url_logger.error "URL parsing failed: URL doesn't match expected base patterns | URL: #{url}"
        return -1
      end
      
      rest = url[base.length..] || ""
      # Remove query string before splitting to handle URLs like "el4?locale=en"
      path_without_query = rest.split('?').first
      # Check if path_without_query is not nil before splitting
      return -1 unless path_without_query
      
      # first non-empty segment after base
      first_segment = path_without_query.split("/", 2).first
      return -1 unless first_segment && !first_segment.empty?
      
      # Look up election by slug
      election = Election.find_by(slug: first_segment)
      election ? election.id : -1
    rescue => e
      url_logger.error "URL parsing failed: #{e.message} | URL: #{url} | Slug: #{first_segment rescue 'unknown'}"
      -1
    end
  end

  def cost_with_delimiter(cost, currency_symbol)
    if I18n.locale == :fr || I18n.locale == :pl
      number_with_delimiter(cost, delimiter: " ", separator: ",") + ' ' + currency_symbol
    else
      currency_symbol + number_with_delimiter(cost)
    end
  end

  # Custom logger for URL processing errors
  def url_logger
    @url_logger ||= begin
      log_file = Rails.root.join('log', 'url_logger.log')
      logger = Logger.new(log_file, 'monthly')
      logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
      end
      logger
    end
  end
end
