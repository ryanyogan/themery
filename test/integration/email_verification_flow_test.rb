require "test_helper"

class EmailVerificationFlowTest < ActionDispatch::IntegrationTest
  setup { @user = users(:two) }

  test "signing up sends a verification email carrying a working link" do
    perform_enqueued_jobs do
      post registration_path, params: {
        user: {
          username: "seaglass",
          email_address: "seaglass@example.com",
          password: "a-long-enough-passphrase",
          password_confirmation: "a-long-enough-passphrase"
        }
      }
    end

    user = User.find_by(email_address: "seaglass@example.com")
    mail = ActionMailer::Base.deliveries.last

    assert_equal [ "seaglass@example.com" ], mail.to
    assert_equal "Verify your Themery email address", mail.subject

    # The mailer mints its own token; a token generated here is interchangeable,
    # so following it exercises the same link the recipient would click.
    get email_verification_path(token: user.generate_token_for(:email_verification))

    assert_predicate user.reload, :verified?
  end

  test "following the verification link marks the address verified" do
    token = @user.generate_token_for(:email_verification)

    assert_changes -> { @user.reload.verified? }, from: false, to: true do
      get email_verification_path(token: token)
    end

    assert_redirected_to root_path
    assert_match(/verified/i, flash[:notice])
  end

  test "verification works while signed out" do
    get email_verification_path(token: @user.generate_token_for(:email_verification))

    assert_response :redirect
    assert_predicate @user.reload, :verified?
  end

  test "a garbage token verifies nobody and says so" do
    assert_no_changes -> { @user.reload.email_verified_at } do
      get email_verification_path(token: "clearly-not-a-token")
    end

    assert_redirected_to root_path
    assert_match(/invalid or expired/i, flash[:alert])
    assert_nil flash[:notice]
  end

  test "an expired token verifies nobody and says so" do
    token = @user.generate_token_for(:email_verification)

    travel 2.days + 1.minute do
      get email_verification_path(token: token)

      assert_redirected_to root_path
      assert_match(/invalid or expired/i, flash[:alert])
    end

    assert_not_predicate @user.reload, :verified?
  end

  test "a token stops working once the address it names changes" do
    token = @user.generate_token_for(:email_verification)
    @user.update!(email_address: "moved@example.com")

    get email_verification_path(token: token)

    assert_match(/invalid or expired/i, flash[:alert])
    assert_not_predicate @user.reload, :verified?
  end

  test "following the link twice is harmless and keeps the first timestamp" do
    token = @user.generate_token_for(:email_verification)

    get email_verification_path(token: token)
    verified_at = @user.reload.email_verified_at

    get email_verification_path(token: token)

    assert_equal verified_at.to_i, @user.reload.email_verified_at.to_i
  end

  test "a signed-in user can ask for another verification email" do
    sign_in_as @user

    assert_enqueued_email_with UserMailer, :email_verification, args: [ @user ] do
      post email_verifications_path
    end

    assert_response :redirect
    assert_match(/Verification email sent/i, flash[:notice])
  end

  test "a signed-out visitor cannot ask for a verification email" do
    assert_no_enqueued_emails do
      post email_verifications_path
    end

    assert_redirected_to new_session_path
  end
end
