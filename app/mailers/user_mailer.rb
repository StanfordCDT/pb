class UserMailer < ActionMailer::Base
  default from: "cdt.no.reply@gmail.com"

  def confirmation_email(user, base_url)
    @confirm_url = base_url + "/admin/users/#{user.id}/validate_confirmation?confirmation_id=#{user.confirmation_id}"
    mail(to: user.username, subject: 'Stanford CDT: Set your password now')
  end

  def reset_password_email(user, base_url)
    @reset_url = base_url + "/admin/users/#{user.id}/validate_confirmation?confirmation_id=#{user.confirmation_id}"
    mail(to: user.username, subject: 'Stanford CDT: Request to reset password')
  end

  def vote_result_email(email, result)
    @result = result
    mail(to: email, subject: "Here is a copy of your vote")
  end
end
