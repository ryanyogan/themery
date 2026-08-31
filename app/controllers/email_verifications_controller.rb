class EmailVerificationsController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    if user = User.find_by_token_for(:email_verification, params[:token])
      user.verify_email!
      redirect_to root_path, notice: "Email verified. You can now publish themes."
    else
      redirect_to root_path, alert: "That verification link is invalid or expired."
    end
  end

  def create
    UserMailer.email_verification(Current.user).deliver_later
    redirect_back fallback_location: root_path, notice: "Verification email sent."
  end
end
