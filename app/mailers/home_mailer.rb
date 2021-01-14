class HomeMailer < ActionMailer::Base
  default from: "cdt.no.reply@gmail.com"

  def contact_email(name, email, message)
    @name = name
    @email = email
    @message = message
    mail(to: "cdt.no.reply@gmail.com", subject: 'Stanford CDT: New message from the Contact Us form')
  end

  def sms(from, message)
    @from = from
    @message = message
    mail(to: "cdt.no.reply@gmail.com", subject: 'Stanford CDT: New message from SMS')
  end
end
