class HomeController < ApplicationController
  skip_forgery_protection only: [:twilio_sms]

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

  # A convenient method for surveys to let us know that voters have completed
  # the survey without specifying the election in the URL. For example, surveys
  # can redirect voters to /done_survey instead of /chicago123/done_survey.
  # We will figure out the election from the session.
  def done_survey
    voter = Voter.find_by(id: session[:voter_id])
    if !voter.nil?
      redirect_to controller: :vote, action: :done_survey, election_slug: voter.election.slug
    else
      render plain: "Thank you for voting!"
    end
  end

  def terms
    
  end  


  # When we send confirmation codes to voters via SMS, they sometimes respond to
  # our messages. We have configured Twilio to call this method when that happens.
  # (It's called "webhook.") This method forwards the SMS to our email and also
  # responds to the SMS.
  def twilio_sms
    require 'twilio-ruby'

    # Validate that the request is coming from Twilio.
    twilio_info = Rails.application.secrets[:twilio]
    validator = Twilio::Security::RequestValidator.new(twilio_info[:auth_token])
    url = "https://" + request.host_with_port + "/twilio_sms"
    twilio_signature = request.headers["X-Twilio-Signature"]
    raise "error" unless validator.validate(url, request.POST, twilio_signature)

    # Forward the SMS to us.
    HomeMailer.sms(params["From"], params["Body"]).deliver

    # Respond to the SMS.
    twiml = Twilio::TwiML::MessagingResponse.new do |r|
      r.message body: "Thanks for the message. We can't respond to your messages here. If you have any question, please email contact@pbstanford.org"
    end
    render xml: twiml.to_s
  end
end
