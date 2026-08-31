require "test_helper"

class StarTest < ActiveSupport::TestCase
  test "a user may star a theme only once" do
    duplicate = Star.new(user: users(:two), theme: themes(:aurora))

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "the database refuses a duplicate star even when validation is skipped" do
    assert_raises ActiveRecord::RecordNotUnique do
      Star.new(user: users(:two), theme: themes(:aurora)).save!(validate: false)
    end
  end

  test "different users may star the same theme" do
    assert Star.create!(user: users(:one), theme: themes(:aurora)).persisted?
  end

  test "one user may star different themes" do
    assert Star.create!(user: users(:two), theme: themes(:driftwood)).persisted?
  end

  test "starring raises the theme's star count" do
    assert_difference -> { themes(:driftwood).reload.stars_count }, 1 do
      Star.create!(user: users(:one), theme: themes(:driftwood))
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

  test "a star belongs to both a user and a theme" do
    assert_not Star.new(theme: themes(:aurora)).valid?
    assert_not Star.new(user: users(:one)).valid?
  end
end
