class UserMailer < ApplicationMailer
  def email_verification(user)
    @user = user
    @token = user.generate_token_for(:email_verification)
    mail subject: "Verify your Themery email address", to: user.email_address
  end
end
