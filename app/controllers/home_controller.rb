class HomeController < ApplicationController
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
