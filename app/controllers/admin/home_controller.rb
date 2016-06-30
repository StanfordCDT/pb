module Admin
  class HomeController < ApplicationController
    before_action :set_no_cache

    def index
      if current_user
        elections = Election.all.select { |election| current_user.admin?(election) || current_user.volunteer?(election) }
        elections = elections.natural_sort_by(&:name)
        @active_elections, @inactive_elections = elections.partition { |election| !election.config[:voting_has_ended] }
      elsif session[:voting_machine_user_id]

      else
        redirect_to_login_page
      end
    end

    def fake_no_access
      no_access
    end
  end
end
