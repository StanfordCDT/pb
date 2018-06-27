class HomeController < ApplicationController
  def index
    elections = Election.all.select { |election| election.config[:show_link_on_home_page] }.natural_sort_by(&:name)
    @active_elections, @inactive_elections = elections.partition { |election| !election.config[:voting_has_ended] }
  end

  def contact
    name = params['name']
    email = params['email']
    message = params['message']
    if !name.blank? && !email.blank? && !message.blank?
      HomeMailer.contact_email(name, email, message).deliver
      render plain: 'Thank you. We have received your message.'
    else
      render plain: 'Error: name, email, or message cannot be blank.'
    end
  end
end
