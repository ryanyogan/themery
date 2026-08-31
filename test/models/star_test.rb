require "test_helper"

class StarTest < ActiveSupport::TestCase
  test "a voter may star a theme only once" do
    duplicate = Star.new(voter_key: stars(:two_stars_aurora).voter_key, theme: themes(:aurora))

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:voter_key], "has already been taken"
  end

  test "the database refuses a duplicate star even when validation is skipped" do
    assert_raises ActiveRecord::RecordNotUnique do
      Star.new(voter_key: stars(:two_stars_aurora).voter_key, theme: themes(:aurora)).save!(validate: false)
    end
  end

  test "different voters may star the same theme" do
    assert Star.create!(voter_key: "anon:aaaa000011112222", theme: themes(:aurora)).persisted?
  end

  test "one voter may star different themes" do
    assert Star.create!(voter_key: stars(:two_stars_aurora).voter_key, theme: themes(:driftwood)).persisted?
  end

  test "a star does not need an account" do
    star = Star.create!(voter_key: "anon:bbbb000011112222", theme: themes(:aurora))

    assert star.persisted?
    assert_nil star.user
  end

  test "starring raises the theme's star count" do
    assert_difference -> { themes(:driftwood).reload.stars_count }, 1 do
      Star.create!(user: users(:one), voter_key: "user:#{users(:one).id}", theme: themes(:driftwood))
    end
  end

  test "unstarring lowers the theme's star count" do
    assert_difference -> { themes(:aurora).reload.stars_count }, -1 do
      stars(:two_stars_aurora).destroy
    end
  end

  test "the fixture star count matches the stars that exist" do
    assert_equal themes(:aurora).stars.count, themes(:aurora).stars_count
  end

  test "a star needs a theme and a voter key" do
    assert_not Star.new(voter_key: "anon:cccc000011112222").valid?
    assert_not Star.new(theme: themes(:aurora)).valid?
  end
end
