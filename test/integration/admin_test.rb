require "test_helper"

# Approval is the only human gate in the pipeline, and the only thing that
# makes a Version reachable by a git client. So the assertions here are the
# admin's screen, the author's stream, and — for the approval itself — a real
# Hosted Repo on disk built by a real pipeline run.
#
# Themes that get approved are given unique names: bare repos live outside the
# test database, in one directory shared by every parallel worker.
class AdminTest < ActionDispatch::IntegrationTest
  setup do
    HostedRepo.root.mkpath
    @repo_paths = []
  end

  teardown do
    @repo_paths.each { |path| FileUtils.rm_rf(path) }
  end

  # --- who may look --------------------------------------------------------

  test "a signed-in non-admin gets a 404, not a forbidden" do
    sign_in_as users(:one)

    get admin_root_path

    assert_response :not_found
  end

  test "a non-admin cannot open a review screen either" do
    sign_in_as users(:one)

    get admin_version_path(versions(:driftwood_v1))

    assert_response :not_found
  end

  test "a non-admin cannot approve or reject" do
    sign_in_as users(:one)
    version = versions(:driftwood_v1)

    post approve_admin_version_path(version)

    assert_response :not_found

    post reject_admin_version_path(version), params: { note: "no" }

    assert_response :not_found
    assert_predicate version.reload, :pending?
  end

  # Signed-out probes get the same 404 as a wrong URL — no redirect that
  # confirms an admin area exists.
  test "a signed-out visitor gets a 404" do
    get admin_root_path

    assert_response :not_found
  end

  test "the queue is not linked for anyone but the admin" do
    sign_in_as users(:one)

    get root_path

    assert_select "a[href=?]", admin_root_path, count: 0

    sign_out
    sign_in_as users(:admin)

    get root_path

    assert_select "a[href=?]", admin_root_path, text: "queue"
  end

  # --- the queue -----------------------------------------------------------

  test "the queue lists every pending version with its author" do
    sign_in_as users(:admin)

    get admin_root_path

    assert_response :success
    assert_select ".queue__count", "2 waiting"

    names = css_select(".queue__name").map { |node| node.text.split.join(" ") }

    assert_equal [ "aurora v2", "driftwood v1" ], names.sort
    assert_select ".queue__link[href=?]", admin_version_path(versions(:aurora_v2))
    assert_select ".queue__author", /rosewood/
  end

  test "the queue tells a new theme apart from an update" do
    sign_in_as users(:admin)

    get admin_root_path

    assert_select ".queue__link[href=?]", admin_version_path(versions(:driftwood_v1)) do
      assert_select ".queue__kind", "new theme"
    end
    assert_select ".queue__link[href=?]", admin_version_path(versions(:aurora_v2)) do
      assert_select ".queue__kind", "update"
    end
  end

  test "an empty queue says so rather than showing an empty list" do
    Version.pending.destroy_all
    sign_in_as users(:admin)

    get admin_root_path

    assert_select ".queue__count", "0 waiting"
    assert_select ".empty", /Queue's clear/
  end

  # --- the review screen ---------------------------------------------------

  test "the review screen names the theme, its author, and what changed" do
    sign_in_as users(:admin)

    get admin_version_path(versions(:aurora_v2))

    assert_response :success
    assert_select ".dash__title", /aurora/
    assert_select ".dash__title .versions__tag", "v2"
    assert_select ".queue__author a[href=?]", author_path("rosewood")
    assert_select ".review-screen__changelog", /Warmer terminal palette/
    assert_select ".review-screen__half figcaption", "live now (v1)"
    assert_select ".review-screen__half figcaption", "proposed (v2)"
  end

  test "the review screen offers both verdicts as forms with a note" do
    sign_in_as users(:admin)
    version = versions(:driftwood_v1)

    get admin_version_path(version)

    assert_select "form[action=?]", approve_admin_version_path(version) do
      assert_select "input[name=note]"
      assert_select "input[type=submit].verdict__approve"
    end
    assert_select "form[action=?]", reject_admin_version_path(version) do
      assert_select "input[name=note]"
      assert_select "input[type=submit].verdict__reject"
    end
  end

  test "the review screen lists the files a first version would publish" do
    version = staged_version(archive: "denied-files-theme.tar.gz")
    sign_in_as users(:admin)

    get admin_version_path(version)

    assert_response :success

    ledger, manifest = css_select(".review-screen__block")

    assert_match(/normalization ledger/, ledger.text)
    assert_includes ledger.css("code").map(&:text), "neovim.lua",
      "the admin sees what the author was told was stripped"

    files = manifest.css("code").map(&:text)

    assert_includes files, "colors.toml"
    assert_includes files, "backgrounds/1-dawn.png"
    assert_includes files, "icons.theme"
    assert_not_includes files, "neovim.lua", "a stripped file is not part of the proposed tree"
  end

  test "a version that has already been decided has no review screen" do
    sign_in_as users(:admin)

    get admin_version_path(versions(:aurora_v1))

    assert_response :not_found
  end

  # --- rejection -----------------------------------------------------------

  test "a rejection without a note is refused, because it would teach nothing" do
    sign_in_as users(:admin)
    version = versions(:driftwood_v1)

    post reject_admin_version_path(version), params: { note: "  " }

    assert_redirected_to admin_version_path(version)
    assert_match(/needs a note/i, flash[:alert])
    assert_predicate version.reload, :pending?
    assert_nil version.review_note
  end

  test "a rejection with a note records the verdict and the reason" do
    sign_in_as users(:admin)
    version = versions(:driftwood_v1)

    post reject_admin_version_path(version), params: { note: "The background is a stock wallpaper." }

    assert_redirected_to admin_root_path
    assert_match(/Rejected driftwood v1/, flash[:notice])
    assert_predicate version.reload, :rejected?
    assert_equal "The background is a stock wallpaper.", version.review_note

    get admin_root_path

    assert_select ".sublist .state--rejected", "rejected"
    assert_select ".sublist .sub__accepted", /stock wallpaper/
  end

  test "a rejected theme stays unreachable and off the queue" do
    sign_in_as users(:admin)

    post reject_admin_version_path(versions(:driftwood_v1)), params: { note: "Not yet." }

    get admin_root_path

    assert_select ".queue__count", "1 waiting"

    get theme_path("driftwood")

    assert_response :not_found
  end

  test "rejecting tells the author's dashboard to catch up" do
    sign_in_as users(:admin)

    assert_turbo_stream_broadcasts [ users(:two), :dashboard ] do
      post reject_admin_version_path(versions(:driftwood_v1)), params: { note: "Not yet." }
    end
  end

  # --- approval, on something the pipeline really built --------------------

  test "approving makes a theme cloneable, public, and shareable" do
    version = staged_version
    theme = version.theme
    sign_in_as users(:admin)

    post approve_admin_version_path(version), params: { note: "Lovely palette." }

    assert_redirected_to admin_root_path
    assert_match(/it's installable now/, flash[:notice])

    version.reload

    assert_predicate version, :approved?
    assert_not_nil version.approved_at
    assert_equal "Lovely palette.", version.review_note
    assert_predicate HostedRepo.for(theme), :exists?, "approval must put the tree in the Hosted Repo"
    assert_predicate version.og_card, :attached?, "approval renders the share card once"
    assert_predicate theme.reload, :published?

    get theme_path(theme.name)

    assert_response :success
    assert_select ".install__cmd", /omarchy theme install http:\/\/www.example.com\/#{theme.name}.git/
  end

  test "approving clears the version out of the queue" do
    version = staged_version
    sign_in_as users(:admin)

    post approve_admin_version_path(version)

    get admin_root_path

    assert_select ".queue__link[href=?]", admin_version_path(version), count: 0
    assert_select ".sublist .state--approved", "approved"
  end

  test "approving tells the author's dashboard, in real time" do
    version = staged_version
    author = version.theme.author
    sign_in_as users(:admin)

    streams = capture_turbo_stream_broadcasts [ author, :dashboard ] do
      post approve_admin_version_path(version)
    end

    assert_equal [ "refresh" ], streams.map { |element| element["action"] }
  end

  test "approving pulses the homepage" do
    version = staged_version
    sign_in_as users(:admin)

    assert_turbo_stream_broadcasts "activity" do
      post approve_admin_version_path(version)
    end
  end

  test "the same version cannot be approved twice" do
    version = staged_version
    sign_in_as users(:admin)

    post approve_admin_version_path(version)

    assert_no_changes -> { version.reload.approved_at.to_i } do
      post approve_admin_version_path(version)
    end

    assert_response :not_found
  end

  private
    # A real pipeline run, stopped one step short of Approval: exactly what
    # sits in the admin's queue in production.
    def staged_version(archive: "good-theme.tar.gz", user: users(:one), theme_name: nil)
      path = file_fixture("archives/#{archive}")
      submission = user.submissions.create!(kind: "archive_upload", theme_name: theme_name || unique_name)
      submission.archive.attach(io: path.open("rb"), filename: path.basename.to_s, content_type: "application/gzip")
      Publishing::Pipeline.process(submission)
      submission.reload

      assert_predicate submission, :accepted?, "staging fixture failed: #{submission.error_report.inspect}"
      @repo_paths << HostedRepo.for(submission.theme).path
      submission.version
    end

    def unique_name = "queued-#{SecureRandom.hex(6)}"
end
