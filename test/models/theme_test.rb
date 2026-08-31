require "test_helper"

class ThemeTest < ActiveSupport::TestCase
  setup { @author = users(:one) }

  # --- Name canonicalization -------------------------------------------------
  #
  # The stock client derives the install directory from the clone URL with this
  # exact transform, so two names that canonicalize alike are the same theme on
  # the user's disk.

  test "canonicalizes a fully decorated name down to its bare identity" do
    theme = Theme.create!(author: @author, name: "omarchy-tidepool-theme.git")

    assert_equal "tidepool", theme.reload.name
  end

  # The stored name must be a FIXED POINT of the client's transform
  # (basename | sed -E 's/^omarchy-//; s/-theme$//' | tr A-Z a-z): we serve
  # the repo under this name, and the client re-derives its install dir from
  # our URL — so stripping must run to exhaustion, case-insensitively.
  test "canonicalization reaches the client's fixed point" do
    assert_equal "aurora", Theme.new(name: "Omarchy-Aurora-Theme.git").name
    assert_equal "aurora", Theme.new(name: "omarchy-omarchy-aurora-theme-theme").name
  end

  test "canonicalization strips the omarchy prefix" do
    assert_equal "driftglass", Theme.new(name: "omarchy-driftglass").name
  end

  test "canonicalization strips the theme suffix" do
    assert_equal "driftglass", Theme.new(name: "driftglass-theme").name
  end

  test "canonicalization strips the git suffix" do
    assert_equal "driftglass", Theme.new(name: "driftglass.git").name
  end

  test "canonicalization downcases and trims surrounding whitespace" do
    assert_equal "driftglass", Theme.new(name: "  DriftGlass  ").name
  end

  test "canonicalization leaves an already bare name alone" do
    assert_equal "driftglass", Theme.new(name: "driftglass").name
  end

  test "canonicalization only strips the suffixes at their own ends" do
    assert_equal "theme-omarchy", Theme.new(name: "theme-omarchy").name
  end

  # --- Uniqueness holds under canonicalization -------------------------------

  test "a decorated name colliding with an existing bare name is rejected" do
    theme = Theme.new(author: users(:two), name: "omarchy-aurora-theme")

    assert_not theme.valid?
    assert_includes theme.errors[:name], "has already been taken"
  end

  test "a differently cased bare name colliding with an existing name is rejected" do
    assert_not Theme.new(author: users(:two), name: "AURORA.git").valid?
  end

  test "two names that canonicalize differently both persist" do
    assert Theme.create!(author: @author, name: "omarchy-tidepool-theme").persisted?
    assert Theme.create!(author: @author, name: "tidepool-dark").persisted?
  end

  # --- Reserved stock names --------------------------------------------------

  test "every reserved stock name is rejected" do
    Theme::RESERVED_NAMES.each do |reserved|
      theme = Theme.new(author: @author, name: reserved)

      assert_not theme.valid?, "expected #{reserved.inspect} to be reserved"
      assert_includes theme.errors[:name], "is a stock omarchy theme name"
    end
  end

  test "a decorated name that canonicalizes onto a reserved name is rejected" do
    theme = Theme.new(author: @author, name: "omarchy-nord-theme.git")

    assert_not theme.valid?
    assert_includes theme.errors[:name], "is a stock omarchy theme name"
  end

  test "a name merely containing a reserved name is allowed" do
    assert Theme.create!(author: @author, name: "nordlys").persisted?
  end

  # --- Name format -----------------------------------------------------------

  test "hyphens, underscores and digits are allowed inside a name" do
    assert Theme.create!(author: @author, name: "retro_82-remix").persisted?
  end

  test "a name may not contain spaces" do
    assert_not Theme.new(author: @author, name: "sea glass").valid?
  end

  # Charset per the omarchy manual: start with letter/digit/underscore, then
  # letters, digits, ., _, +, - — so "flexoki_light" and "c++" are legal.
  test "a name follows the client's directory-name rules" do
    assert_not Theme.new(author: @author, name: "-seaglass").valid?
    assert_not Theme.new(author: @author, name: "sea/glass").valid?
    assert_not Theme.new(author: @author, name: ".seaglass").valid?
    assert Theme.new(author: @author, name: "_seaglass").valid?
    assert Theme.new(author: @author, name: "sea.glass").valid?
    assert Theme.new(author: @author, name: "c++").valid?
  end

  test "a name may not be blank" do
    assert_not Theme.new(author: @author, name: "   ").valid?
  end

  test "a name may not exceed fifty characters" do
    assert Theme.new(author: @author, name: "a" * 50).valid?
    assert_not Theme.new(author: @author, name: "a" * 51).valid?
  end

  # --- Publication state -----------------------------------------------------

  test "a theme with an approved version is published" do
    assert themes(:aurora).published?
    assert_includes Theme.published, themes(:aurora)
  end

  test "a theme whose only version is pending is not published" do
    assert_not themes(:driftwood).published?
    assert_not_includes Theme.published, themes(:driftwood)
  end

  test "published themes are listed once even with several approved versions" do
    Version.create!(theme: themes(:sherbet), number: 2, state: "approved")

    assert_equal 1, Theme.published.where(name: "sherbet").count
  end

  test "latest approved version ignores newer pending work" do
    assert_equal versions(:aurora_v1), themes(:aurora).latest_approved_version
    assert_equal versions(:aurora_v2), themes(:aurora).pending_version
  end
end
