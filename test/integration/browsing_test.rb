require "test_helper"

# Seam 1: what a signed-out visitor sees. The gallery is the front door, so
# everything asserted here is a thing a browser renders — the names on the
# cards and the order they come in, the install command a visitor pastes, the
# palette the page paints — never the queries behind them.
class BrowsingTest < ActionDispatch::IntegrationTest
  # --- the gallery ---------------------------------------------------------

  test "the gallery lists published themes and nothing else" do
    get root_path

    assert_response :success
    assert_equal %w[aurora sherbet], card_names.sort
    assert_not_includes card_names, "driftwood", "a theme with no approved version is not installable"
  end

  test "a theme's card carries its counts and mode" do
    themes(:aurora).update_columns(stars_count: 7, installs_count: 312)

    get root_path

    assert_select "##{dom_id(themes(:aurora), :card)}" do
      assert_select ".card__stats", /★ 7/
      assert_select ".card__stats", /↓ 312/
      assert_select ".card__mode--dark"
    end
  end

  test "the default sort is by stars" do
    rank(aurora: { stars_count: 9 }, sherbet: { stars_count: 2 })

    get root_path

    assert_equal %w[aurora sherbet], card_names
  end

  test "sorting by installs reorders the gallery" do
    rank(aurora: { installs_count: 3 }, sherbet: { installs_count: 900 })

    get root_path(sort: "installs")

    assert_response :success
    assert_equal %w[sherbet aurora], card_names
  end

  test "sorting by new puts the freshest theme first" do
    themes(:aurora).update_columns(created_at: 2.weeks.ago)
    themes(:sherbet).update_columns(created_at: 1.hour.ago)

    get root_path(sort: "new")

    assert_response :success
    assert_equal %w[sherbet aurora], card_names
  end

  test "an unknown sort falls back to the default instead of erroring" do
    rank(aurora: { stars_count: 9 }, sherbet: { stars_count: 2 })

    get root_path(sort: "whatever")

    assert_response :success
    assert_equal %w[aurora sherbet], card_names
  end

  test "the mode filter narrows the gallery to light or dark" do
    get root_path(mode: "light")

    assert_response :success
    assert_equal %w[sherbet], card_names

    get root_path(mode: "dark")

    assert_equal %w[aurora], card_names
  end

  test "search matches a substring of the name" do
    get root_path(q: "uror")

    assert_response :success
    assert_equal %w[aurora], card_names
  end

  test "a search that matches nothing shows the empty state and says what was searched" do
    get root_path(q: "nothinglikethis")

    assert_response :success
    assert_empty card_names
    assert_select ".empty", /No themes match/
    assert_select ".empty", /nothinglikethis/
  end

  test "search and mode and sort survive together" do
    get root_path(q: "r", mode: "light", sort: "new")

    assert_response :success
    assert_equal %w[sherbet], card_names
  end

  # --- the theme page ------------------------------------------------------

  test "the theme page shows the one-line install command with the clone URL" do
    get theme_path("aurora")

    assert_response :success
    assert_select ".install__cmd", "omarchy theme install http://www.example.com/aurora.git"
  end

  test "the theme page paints the palette it publishes" do
    get theme_path("aurora")

    assert_select ".palette__chip[title=?]", "background #11121a"
    assert_select ".palette__chip[title=?]", "accent #82aaff"
    assert_select ".palette__chip[style=?]", "--chip: #82aaff"
    assert_operator css_select(".palette__chip").size, :>=, 10
  end

  test "the theme page lists approved versions only" do
    get theme_path("aurora")

    tags = css_select(".versions__tag").map(&:text)

    assert_equal %w[v1], tags, "a pending version must not appear in public version history"
    assert_select ".versions__changelog", "First cut."
  end

  test "the theme page shows reviews with a link to their author" do
    get theme_path("aurora")

    assert_select ".review__body", /Legible at 3am/
    assert_select ".review__by a[href=?]", author_path("fernbrook"), "fernbrook"
  end

  test "the theme page names the author and the mode" do
    get theme_path("aurora")

    assert_select ".theme__name", "aurora"
    assert_select ".theme__byline a[href=?]", author_path("rosewood"), "rosewood"
    assert_select ".theme__byline", /dark/
  end

  test "the theme page shows the live counts" do
    themes(:aurora).update_columns(installs_count: 42, updates_count: 5)

    get theme_path("aurora")

    assert_select "##{dom_id(themes(:aurora), :counts)}" do
      assert_select ".count", /★ 1/
      assert_select ".count", /↓ 42/
      assert_select ".count", /⟳ 5/
    end
  end

  test "a theme with no approved version is not a page at all" do
    get theme_path("driftwood")

    assert_response :not_found
  end

  test "an unknown theme name 404s" do
    get theme_path("nosuchtheme")

    assert_response :not_found
  end

  # --- author pages and the guide ------------------------------------------

  test "an author page lists that author's published themes only" do
    get author_path("rosewood")

    assert_response :success
    assert_equal %w[aurora], card_names
    assert_select ".author__name", "~/rosewood"
    assert_select ".author__meta", /1 published theme/
  end

  test "an author with nothing approved yet gets an empty profile, not a 404" do
    get author_path("fernbrook")

    assert_response :success
    assert_empty card_names
    assert_select ".empty", /Nothing published yet/
  end

  test "an unknown author 404s" do
    get author_path("nobody")

    assert_response :not_found
  end

  test "the guide renders for a signed-out visitor" do
    get guide_path

    assert_response :success
    assert_select "h1", "create an omarchy theme"
    assert_select "a[href=?]", new_submission_path
  end

  private
    def card_names = css_select(".card__name").map(&:text)

    def dom_id(...) = ActionView::RecordIdentifier.dom_id(...)

    def rank(counters)
      counters.each { |name, columns| themes(name).update_columns(columns) }
    end
end
