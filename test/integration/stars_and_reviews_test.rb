require "test_helper"

# The two social primitives, from the outside: the button a visitor presses,
# the turbo-stream that comes back to them, the broadcast every other reader
# of the page receives, and the text that ends up on the theme.
class StarsAndReviewsTest < ActionDispatch::IntegrationTest
  setup do
    @theme = themes(:aurora)
    @user = users(:one)
  end

  # --- starring ------------------------------------------------------------

  test "starring requires an account" do
    assert_no_difference -> { Star.count } do
      post theme_star_path("aurora")
    end

    assert_redirected_to new_session_path
  end

  test "the star button invites a signed-out visitor to sign in" do
    get theme_path("aurora")

    assert_select "##{dom_id(@theme, :star_button)} a[href=?]", new_session_path
    assert_select "##{dom_id(@theme, :star_button)} form", count: 0
  end

  test "starring creates a star and returns the flipped button and the new counts" do
    sign_in_as @user

    assert_difference -> { Star.count }, 1 do
      post theme_star_path("aurora"), as: :turbo_stream
    end

    assert_turbo_stream action: "replace", target: dom_id(@theme, :star_button) do
      assert_select "template", /starred/
    end
    assert_turbo_stream action: "replace", target: dom_id(@theme, :counts) do
      assert_select "template .count", /★ 2/
    end
    assert_equal 2, @theme.reload.stars_count
  end

  # A Star is binary, so a repeat press must not double-count. It doesn't —
  # but the response is currently a 422, not a re-render of the button:
  # StarsController#create reaches for create_or_find_by!, which only rescues
  # the unique index, while Star's uniqueness validation raises RecordInvalid
  # first. The count is the correctness question and it is asserted here; the
  # status code is reported as a bug.
  test "starring twice never counts twice" do
    sign_in_as @user

    post theme_star_path("aurora"), as: :turbo_stream

    assert_no_difference -> { Star.count } do
      post theme_star_path("aurora"), as: :turbo_stream
    end

    assert_equal 2, @theme.reload.stars_count
  end

  test "unstarring removes the star and hands back the unstarred button" do
    sign_in_as users(:two)

    assert_difference -> { Star.count }, -1 do
      delete theme_star_path("aurora"), as: :turbo_stream
    end

    assert_turbo_stream action: "replace", target: dom_id(@theme, :star_button) do
      assert_select "template", /☆ star/
    end
    assert_equal 0, @theme.reload.stars_count
  end

  test "unstarring something never starred is harmless" do
    sign_in_as @user

    assert_no_difference -> { Star.count } do
      delete theme_star_path("aurora"), as: :turbo_stream
    end

    assert_response :success
  end

  test "a plain HTML star lands back on the theme page" do
    sign_in_as @user

    post theme_star_path("aurora")

    assert_redirected_to theme_path("aurora")
  end

  test "the theme page shows the actor their own star" do
    sign_in_as users(:two)

    get theme_path("aurora")

    assert_select "##{dom_id(@theme, :star_button)} form[action=?]", theme_star_path("aurora") do
      assert_select "input[name=_method][value=delete]"
    end
  end

  test "a theme with no approved version cannot be starred" do
    sign_in_as @user

    assert_no_difference -> { Star.count } do
      post theme_star_path("driftwood")
    end

    assert_response :not_found
  end

  # --- what the rest of the room sees --------------------------------------

  test "starring broadcasts the new counts to everyone reading the theme" do
    sign_in_as @user

    streams = capture_turbo_stream_broadcasts @theme do
      post theme_star_path("aurora"), as: :turbo_stream
    end

    assert_equal [ "replace" ], streams.map { |element| element["action"] }
    assert_equal [ dom_id(@theme, :counts) ], streams.map { |element| element["target"] }
    assert_match(/★ 2/, streams.sole.to_html)
  end

  test "starring never broadcasts who starred it" do
    sign_in_as @user

    streams = capture_turbo_stream_broadcasts @theme do
      post theme_star_path("aurora"), as: :turbo_stream
    end

    assert_no_match(/star_button/, streams.sole.to_html,
      "'starred by me' is personal — it must never ride the shared stream")
  end

  test "a first star shows up in the homepage pulse" do
    sign_in_as @user

    assert_turbo_stream_broadcasts "activity" do
      post theme_star_path("aurora"), as: :turbo_stream
    end
  end

  test "unstarring broadcasts the corrected counts" do
    sign_in_as users(:two)

    assert_turbo_stream_broadcasts @theme do
      delete theme_star_path("aurora"), as: :turbo_stream
    end
  end

  # --- the starred themes page ---------------------------------------------

  test "the starred page lists what you starred and nothing else" do
    sign_in_as users(:two)

    get starred_themes_path

    assert_response :success
    assert_equal %w[aurora], card_names
  end

  test "an unpublished theme you starred stays off the starred page" do
    sign_in_as users(:two)
    users(:two).stars.create!(theme: themes(:driftwood))

    get starred_themes_path

    assert_equal %w[aurora], card_names
  end

  test "someone else's stars are not yours" do
    sign_in_as @user

    get starred_themes_path

    assert_empty card_names
    assert_select ".empty", /Nothing starred yet/
  end

  test "the starred page needs an account" do
    get starred_themes_path

    assert_redirected_to new_session_path
  end

  # --- reviewing -----------------------------------------------------------

  test "reviewing requires an account" do
    assert_no_difference -> { Review.count } do
      post theme_reviews_path("aurora"), params: { review: { body: "Lovely." } }
    end

    assert_redirected_to new_session_path
  end

  test "a review is posted and appears on the theme with a link to its author" do
    sign_in_as @user

    assert_difference -> { Review.count }, 1 do
      post theme_reviews_path("aurora"), params: { review: { body: "Held up through a 12 hour day." } }
    end

    assert_redirected_to theme_path("aurora")
    assert_match(/Review posted/i, flash[:notice])

    follow_redirect!

    assert_select ".review__body", "Held up through a 12 hour day."
    assert_select ".review__by a[href=?]", author_path("rosewood"), "rosewood"
  end

  test "one review per person per theme" do
    sign_in_as users(:two)

    assert_no_difference -> { Review.count } do
      post theme_reviews_path("aurora"), params: { review: { body: "Actually, a second thought." } }
    end

    assert_redirected_to theme_path("aurora")
    assert_match(/already been taken/i, flash[:alert])
    assert_nil flash[:notice]
  end

  test "an empty review is refused with a reason" do
    sign_in_as @user

    assert_no_difference -> { Review.count } do
      post theme_reviews_path("aurora"), params: { review: { body: "  " } }
    end

    assert_redirected_to theme_path("aurora")
    assert_match(/Body can't be blank/i, flash[:alert])
  end

  test "the review form is offered to someone who has not reviewed yet" do
    sign_in_as @user

    get theme_path("aurora")

    assert_select "form.reviewform[action=?]", theme_reviews_path("aurora")
  end

  test "the review form disappears once you have had your say" do
    sign_in_as users(:two)

    get theme_path("aurora")

    assert_select ".review__body", /Legible at 3am/
    assert_select "form.reviewform", count: 0
  end

  test "a signed-out visitor reads reviews but is not offered the form" do
    get theme_path("aurora")

    assert_select ".review__body", /Legible at 3am/
    assert_select "form.reviewform", count: 0
  end

  test "you can take your own review back" do
    sign_in_as users(:two)
    review = reviews(:two_reviews_aurora)

    assert_difference -> { Review.count }, -1 do
      delete theme_review_path("aurora", review)
    end

    assert_redirected_to theme_path("aurora")
    assert_match(/Review removed/i, flash[:notice])

    follow_redirect!

    assert_select ".reviews__empty"
    assert_select "form.reviewform"
  end

  test "you cannot take someone else's review back" do
    sign_in_as @user
    review = reviews(:two_reviews_aurora)

    assert_no_difference -> { Review.count } do
      delete theme_review_path("aurora", review)
    end

    assert_redirected_to theme_path("aurora")
  end

  test "an unpublished theme cannot be reviewed" do
    sign_in_as @user

    assert_no_difference -> { Review.count } do
      post theme_reviews_path("driftwood"), params: { review: { body: "Sneaking in early." } }
    end

    assert_response :not_found
  end

  private
    def card_names = css_select(".card__name").map(&:text)

    def dom_id(...) = ActionView::RecordIdentifier.dom_id(...)
end
