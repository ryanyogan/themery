require "test_helper"

class VersionTest < ActiveSupport::TestCase
  # --- At most one pending Version per Theme ---------------------------------
  #
  # Guarded by a partial unique index, so the rule survives concurrent
  # submissions rather than merely a validation race.

  test "a second pending version for the same theme is refused by the database" do
    assert_raises ActiveRecord::RecordNotUnique do
      Version.create!(theme: themes(:aurora), number: 3, state: "pending")
    end
  end

  test "a new pending version is allowed once the previous one is approved" do
    versions(:aurora_v2).update!(state: "approved", approved_at: Time.current)

    version = Version.create!(theme: themes(:aurora), number: 3)

    assert version.persisted?
    assert_predicate version, :pending?
  end

  test "a new pending version is allowed once the previous one is rejected" do
    versions(:aurora_v2).update!(state: "rejected", review_note: "Name squats an upstream project.")

    assert Version.create!(theme: themes(:aurora), number: 3).persisted?
  end

  test "a pending version is allowed on a theme that has none" do
    assert Version.create!(theme: themes(:sherbet), number: 2).persisted?
  end

  test "several approved versions may coexist on one theme" do
    versions(:aurora_v2).update!(state: "approved", approved_at: Time.current)

    Version.create!(theme: themes(:aurora), number: 3, state: "approved")

    assert_equal 3, themes(:aurora).versions.approved.count
  end

  test "a version defaults to pending" do
    assert_predicate Version.new, :pending?
  end

  # --- Numbering -------------------------------------------------------------

  test "next number for a theme follows its highest existing version" do
    assert_equal 3, Version.next_number_for(themes(:aurora))
    assert_equal 2, Version.next_number_for(themes(:sherbet))
  end

  test "next number for a theme with no versions is one" do
    theme = Theme.create!(author: users(:one), name: "tidepool")

    assert_equal 1, Version.next_number_for(theme)
  end

  test "next number ignores state, counting rejected versions too" do
    versions(:aurora_v2).update!(state: "rejected")

    assert_equal 3, Version.next_number_for(themes(:aurora))
  end

  test "numbers are unique within a theme but not across themes" do
    duplicate = Version.new(theme: themes(:aurora), number: 1, state: "approved")
    assert_not duplicate.valid?

    assert Version.create!(theme: themes(:sherbet), number: 2, state: "approved").persisted?
  end

  test "a version requires a number" do
    assert_not Version.new(theme: themes(:sherbet)).valid?
  end

  # --- Changelog -------------------------------------------------------------

  test "a changelog is optional but capped at two thousand characters" do
    assert Version.new(theme: themes(:sherbet), number: 2, changelog: nil).valid?
    assert Version.new(theme: themes(:sherbet), number: 2, changelog: "a" * 2_000).valid?
    assert_not Version.new(theme: themes(:sherbet), number: 2, changelog: "a" * 2_001).valid?
  end

  test "the git tag name is derived from the number" do
    assert_equal "v1", versions(:aurora_v1).tag_name
  end

  test "newest first orders by descending number" do
    assert_equal [ versions(:aurora_v2), versions(:aurora_v1) ], themes(:aurora).versions.newest_first.to_a
  end
end
