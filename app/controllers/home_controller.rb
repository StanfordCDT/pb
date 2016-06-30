class HomeController < ApplicationController
  def index
    elections = Election.all.select { |election| election.config[:show_link_on_home_page] }.natural_sort_by(&:name)
    @active_elections, @inactive_elections = elections.partition { |election| !election.config[:voting_has_ended] }
  end
end
