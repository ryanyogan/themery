require "test_helper"

class RegistrationFlowTest < ActionDispatch::IntegrationTest
  test "the sign-up form is reachable while signed out" do
    get new_registration_path

    assert_response :success
    assert_select "form[action=?]", registration_path
    assert_select "input[name='user[username]']"
    assert_select "input[name='user[email_address]']"
  end

  test "signing up creates the account, signs the browser in, and mails a verification link" do
    assert_difference -> { User.count }, 1 do
      post registration_path, params: { user: valid_params }
    end

    assert_redirected_to root_path
    assert cookies[:session_id].present?, "expected a signed session cookie"
    assert_enqueued_email_with UserMailer, :email_verification, args: [ User.find_by(username: "seaglass") ]

    user = User.find_by(username: "seaglass")
    assert_equal "seaglass@example.com", user.email_address
    assert_not_predicate user, :verified?
    assert_equal 1, user.sessions.count
  end

  test "a signed-up browser stays signed in on the next request" do
    post registration_path, params: { user: valid_params }

    get new_session_path
    assert_response :success
    assert cookies[:session_id].present?
  end

  test "sign-up normalizes the email address and username before storing them" do
    post registration_path, params: {
      user: valid_params(username: "  SeaGlass  ", email_address: "  SeaGlass@Example.COM ")
    }

    user = User.last
    assert_equal "seaglass", user.username
    assert_equal "seaglass@example.com", user.email_address
  end

  test "a mismatched password confirmation re-renders the form unprocessable" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: valid_params(password_confirmation: "something-else") }
    end

    assert_response :unprocessable_entity
    assert_select "form[action=?]", registration_path
    assert_select ".form-errors", /Password confirmation/
    assert_nil cookies[:session_id].presence
    assert_no_enqueued_emails
  end

  test "a malformed email address re-renders the form unprocessable" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: valid_params(email_address: "not-an-address") }
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors", /Email address is invalid/
  end

  test "an unusable username re-renders the form unprocessable" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: valid_params(username: "sea glass") }
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors", /letters, numbers, and hyphens/
  end

  test "an already registered email address is refused" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: valid_params(email_address: users(:one).email_address) }
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors", /Email address has already been taken/
  end

  test "an already taken username is refused, whatever its casing" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: valid_params(username: "RoseWood") }
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors", /Username has already been taken/
  end

  private
    def valid_params(**overrides)
      {
        username: "seaglass",
        email_address: "seaglass@example.com",
        password: "a-long-enough-passphrase",
        password_confirmation: "a-long-enough-passphrase"
      }.merge(overrides)
    end
end
