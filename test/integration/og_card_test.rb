require "test_helper"

# The share card endpoint: what Discord and X fetch when someone pastes a
# theme link. The card is rendered once at Approval, so the only way to test
# the endpoint honestly is on a theme a real pipeline built and a real
# approval published.
class OgCardTest < ActionDispatch::IntegrationTest
  PNG_MAGIC = "\x89PNG\r\n\x1A\n".b

  setup do
    HostedRepo.root.mkpath
    @repo_paths = []
  end

  teardown do
    @repo_paths.each { |path| FileUtils.rm_rf(path) }
  end

  test "an approved theme serves a PNG share card" do
    theme = published_theme

    get og_theme_path(theme.name)

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_operator response.body.bytesize, :>, 1_000, "an empty card is worse than no card"
    assert response.body.b.start_with?(PNG_MAGIC), "the endpoint must serve real PNG bytes"
  end

  test "the card is served inline and cacheable, because unfurlers refetch it" do
    theme = published_theme

    get og_theme_path(theme.name)

    assert_match(/inline/, response.headers["Content-Disposition"])
    assert_match(/public/, response.headers["Cache-Control"])
  end

  test "the theme page points unfurlers at the card" do
    theme = published_theme

    get theme_path(theme.name)

    assert_select "meta[property='og:image'][content=?]", og_theme_url(theme.name)
    assert_select "meta[name='twitter:card'][content=?]", "summary_large_image"
  end

  test "a theme with no approved version has no card" do
    get og_theme_path("driftwood")

    assert_response :not_found
  end

  test "an unknown theme has no card" do
    get og_theme_path("nosuchtheme")

    assert_response :not_found
  end

  test "a published theme whose version predates card rendering 404s rather than erroring" do
    get og_theme_path("aurora")

    assert_response :not_found
  end

  private
    # The whole publish path, because a share card is only worth serving from
    # an artifact the pipeline built and a human approved.
    def published_theme(archive: "good-theme.tar.gz", user: users(:one))
      path = file_fixture("archives/#{archive}")
      submission = user.submissions.create!(kind: "archive_upload", theme_name: "shared-#{SecureRandom.hex(6)}")
      submission.archive.attach(io: path.open("rb"), filename: path.basename.to_s, content_type: "application/gzip")
      Publishing::Pipeline.process(submission)
      submission.reload

      assert_predicate submission, :accepted?, "publish fixture failed: #{submission.error_report.inspect}"
      @repo_paths << HostedRepo.for(submission.theme).path
      Publishing::Release.approve(submission.version)

      assert_predicate submission.version.reload.og_card, :attached?, "approval did not render a card"
      submission.theme.reload
    end
end
