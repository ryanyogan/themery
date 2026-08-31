require "test_helper"

# Try It: the site reskins itself in a theme's palette. Every UI color flows
# through the token layer, so the whole feature is observable as one style
# block plus the bar that offers the way out — which is exactly what a
# visitor sees, and all this test looks at.
class TryItTest < ActionDispatch::IntegrationTest
  test "trying a theme sends the visitor back to it wearing its palette" do
    post try_theme_path("aurora")

    assert_redirected_to theme_path("aurora")

    follow_redirect!

    assert_response :success
    assert_select "style[data-turbo-permanent]", /--t-bg: #11121a;/
    assert_select "style[data-turbo-permanent]", /--t-ink: #c8d3f5;/
    assert_select "style[data-turbo-permanent]", /--t-accent: #82aaff;/
    assert_select "style[data-turbo-permanent]", /color-scheme: dark;/
  end

  test "the trybar names the theme being worn and offers a way out" do
    post try_theme_path("aurora")
    follow_redirect!

    assert_select ".trybar strong", "aurora"
    assert_select ".trybar form[action=?]", stop_trying_path
    assert_select ".trybar__link[href=?]", theme_path("aurora")
  end

  test "the palette follows the visitor to every other page" do
    post try_theme_path("sherbet")

    get root_path

    assert_response :success
    assert_select "style[data-turbo-permanent]", /--t-bg: #fff7f2;/
    assert_select "style[data-turbo-permanent]", /color-scheme: light;/
    assert_select ".trybar strong", "sherbet"
  end

  test "trying a different theme replaces the palette rather than stacking" do
    post try_theme_path("aurora")
    post try_theme_path("sherbet")

    get root_path

    assert_select "style[data-turbo-permanent]", count: 1
    assert_select "style[data-turbo-permanent]", /--t-bg: #fff7f2;/
    assert_select ".trybar strong", "sherbet"
  end

  test "exiting Try It puts the site back in its own skin" do
    post try_theme_path("aurora")
    follow_redirect!

    assert_select ".trybar"

    delete stop_trying_path

    assert_response :redirect

    get root_path

    assert_select "style[data-turbo-permanent]", count: 0
    assert_select ".trybar", count: 0
  end

  test "no palette is worn until a visitor asks for one" do
    get root_path

    assert_select "style[data-turbo-permanent]", count: 0
    assert_select ".trybar", count: 0
  end

  test "a theme with no approved version cannot be tried on" do
    post try_theme_path("driftwood")

    assert_response :not_found

    get root_path

    assert_select ".trybar", count: 0
  end

  test "an unknown theme cannot be tried on" do
    post try_theme_path("nosuchtheme")

    assert_response :not_found
  end

  test "trying a theme returns the visitor to the page they were on" do
    post try_theme_path("aurora"), headers: { "HTTP_REFERER" => root_url }

    assert_redirected_to root_url
  end
end
