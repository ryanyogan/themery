require "test_helper"

class UserTest < ActiveSupport::TestCase
  # --- Email address ---------------------------------------------------------

  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "an email address must look like an email address" do
    assert_not User.new(email_address: "not-an-address").valid?
  end

  test "an email address must be unique after normalization" do
    duplicate = build_user(email_address: " ONE@Example.com ")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email_address], "has already been taken"
  end

  # --- Username --------------------------------------------------------------

  test "downcases and strips username" do
    assert_equal "quattro", User.new(username: "  Quattro  ").username
  end

  test "a username must be unique after normalization" do
    duplicate = build_user(username: "  ROSEWOOD ")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:username], "has already been taken"
  end

  test "a username allows letters, digits and inner hyphens" do
    assert build_user(username: "sherbet-42").valid?
  end

  test "a username may not contain underscores, spaces or dots" do
    assert_not build_user(username: "sea_glass").valid?
    assert_not build_user(username: "sea glass").valid?
    assert_not build_user(username: "sea.glass").valid?
  end

  test "a username may not start with a hyphen" do
    assert_not build_user(username: "-seaglass").valid?
  end

  test "a username must be between two and thirty characters" do
    assert_not build_user(username: "a").valid?
    assert build_user(username: "ab").valid?
    assert build_user(username: "a" * 30).valid?
    assert_not build_user(username: "a" * 31).valid?
  end

  test "a username is required" do
    assert_not build_user(username: "  ").valid?
  end

  # --- Email verification ----------------------------------------------------

  test "a fresh account is not verified" do
    assert_not_predicate users(:two), :verified?
    assert_nil users(:two).email_verified_at
  end

  test "an email verification token round-trips back to its user" do
    token = users(:two).generate_token_for(:email_verification)

    assert_equal users(:two), User.find_by_token_for(:email_verification, token)
  end

  test "a garbage token resolves to nobody" do
    assert_nil User.find_by_token_for(:email_verification, "not-a-real-token")
    assert_nil User.find_by_token_for(:email_verification, "")
    assert_nil User.find_by_token_for(:email_verification, nil)
  end

  test "an email verification token expires after two days" do
    token = users(:two).generate_token_for(:email_verification)

    travel 2.days + 1.minute do
      assert_nil User.find_by_token_for(:email_verification, token)
    end
  end

  test "changing the email address invalidates outstanding verification tokens" do
    token = users(:two).generate_token_for(:email_verification)
    users(:two).update!(email_address: "moved@example.com")

    assert_nil User.find_by_token_for(:email_verification, token)
  end

  test "one user's token never resolves to another user" do
    token = users(:two).generate_token_for(:email_verification)

    assert_not_equal users(:one), User.find_by_token_for(:email_verification, token)
  end

  test "verifying an email records the moment it happened" do
    user = users(:two)

    assert_changes -> { user.reload.verified? }, from: false, to: true do
      user.verify_email!
    end
  end

  test "verifying an already verified email leaves the original timestamp alone" do
    user = users(:one)
    original = user.email_verified_at

    user.verify_email!

    assert_equal original.to_i, user.reload.email_verified_at.to_i
  end

  private
    def build_user(**attributes)
      User.new({
        username: "newcomer",
        email_address: "newcomer@example.com",
        password: "secret-passphrase",
        password_confirmation: "secret-passphrase"
      }.merge(attributes))
    end
end
