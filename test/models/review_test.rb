require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  test "a user may review a theme only once" do
    duplicate = Review.new(user: users(:two), theme: themes(:aurora), body: "Second thoughts.")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "the database refuses a duplicate review even when validation is skipped" do
    assert_raises ActiveRecord::RecordNotUnique do
      Review.new(user: users(:two), theme: themes(:aurora), body: "Second thoughts.").save!(validate: false)
    end
  end

  test "different users may review the same theme" do
    assert Review.create!(user: users(:one), theme: themes(:aurora), body: "Holds up on a 4K panel.").persisted?
  end

  test "one user may review different themes" do
    assert Review.create!(user: users(:two), theme: themes(:driftwood), body: "Gentle in daylight.").persisted?
  end

  test "a review requires a body" do
    assert_not build_review(body: nil).valid?
    assert_not build_review(body: "").valid?
    assert_not build_review(body: "   ").valid?
  end

  test "a review body is capped at a thousand characters" do
    assert build_review(body: "a" * 1_000).valid?
    assert_not build_review(body: "a" * 1_001).valid?
  end

  test "a review belongs to both a user and a theme" do
    assert_not Review.new(theme: themes(:aurora), body: "Nice.").valid?
    assert_not Review.new(user: users(:one), body: "Nice.").valid?
  end

  test "newest first orders by descending creation time" do
    newer = Review.create!(user: users(:one), theme: themes(:aurora), body: "Added later.", created_at: 1.day.from_now)

    assert_equal [ newer, reviews(:two_reviews_aurora) ], themes(:aurora).reviews.newest_first.to_a
  end

  private
    def build_review(**attributes)
      Review.new({ user: users(:one), theme: themes(:aurora), body: "Perfectly readable." }.merge(attributes))
    end
end
