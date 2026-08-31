require "test_helper"

class SessionFlowTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "the sign-in form is reachable while signed out" do
    get new_session_path

    assert_response :success
    assert_select "form[action=?]", session_path
    assert_select "input[name=email_address]"
    assert_select "input[name=password]"
  end

  test "signing in with an email address and password sets a session cookie" do
    assert_difference -> { @user.sessions.count }, 1 do
      post session_path, params: { email_address: @user.email_address, password: "password" }
    end

    assert_response :redirect
    assert cookies[:session_id].present?
  end

  test "the email address is matched after normalization" do
    post session_path, params: { email_address: "  ONE@Example.COM  ", password: "password" }

    assert cookies[:session_id].present?
  end

  test "a username is not accepted in place of an email address" do
    assert_no_difference -> { @user.sessions.count } do
      post session_path, params: { email_address: @user.username, password: "password" }
    end

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id].presence

    follow_redirect!
    assert_select ".flash", /Try another email address or password/
  end

  test "the wrong password is refused" do
    assert_no_difference -> { @user.sessions.count } do
      post session_path, params: { email_address: @user.email_address, password: "not-the-password" }
    end

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id].presence
  end

  test "an unknown email address is refused with the same message" do
    post session_path, params: { email_address: "nobody@example.com", password: "password" }

    assert_redirected_to new_session_path

    follow_redirect!
    assert_select ".flash", /Try another email address or password/
  end

  test "a blank password is refused" do
    post session_path, params: { email_address: @user.email_address, password: "" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id].presence
  end

  test "a protected page redirects a signed-out visitor to sign in, then back afterwards" do
    post email_verifications_path
    assert_redirected_to new_session_path

    post session_path, params: { email_address: @user.email_address, password: "password" }
    assert_redirected_to email_verifications_url
  end

  test "signing out drops the session cookie and the session record" do
    sign_in_as @user

    assert_difference -> { Session.count }, -1 do
      delete session_path
    end

    assert_redirected_to new_session_path
    assert_response :see_other
    assert_empty cookies[:session_id]
  end

  test "a signed-out browser cannot reach a page that requires authentication" do
    sign_in_as @user
    delete session_path

    post email_verifications_path
    assert_redirected_to new_session_path
  end
end
