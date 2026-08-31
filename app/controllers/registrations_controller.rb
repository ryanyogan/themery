class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 5, within: 1.hour, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      UserMailer.email_verification(@user).deliver_later
      start_new_session_for @user
      redirect_to root_path, notice: "Welcome to Themery! Check your email to verify your address."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def user_params
      params.expect(user: [ :username, :email_address, :password, :password_confirmation ])
    end
end
