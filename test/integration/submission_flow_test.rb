require "test_helper"

# Publishing, from the author's side of the glass: the form, the upload, the
# redirect, and the dashboard row that tells them what happened to it. The
# pipeline itself is tested at seam 2 — here it only ever runs to prove the
# dashboard reports its verdict truthfully.
class SubmissionFlowTest < ActionDispatch::IntegrationTest
  setup { @author = users(:one) }

  # --- the form ------------------------------------------------------------

  test "a verified author gets the submission form" do
    sign_in_as @author

    get new_submission_path

    assert_response :success
    assert_select "form[action=?]", submissions_path do
      assert_select "input[name=?]", "submission[theme_name]"
      assert_select "input[name=?]", "submission[source_url]"
      # Publishing is git-only: no archive upload in the product.
      assert_select "input[type=file]", count: 0
    end
  end

  test "the form prefills the theme name when publishing a next version" do
    sign_in_as @author

    get new_submission_path(theme_name: "aurora")

    assert_select "input[name=?][value=?]", "submission[theme_name]", "aurora"
  end

  # --- submitting ----------------------------------------------------------

  test "a repo URL creates a git_import submission and queues the pipeline" do
    sign_in_as @author

    assert_difference -> { Submission.count }, 1 do
      assert_enqueued_with job: ProcessSubmissionJob do
        post submissions_path, params: {
          submission: { theme_name: "tidepool",
                        source_url: "https://github.com/rosewood/omarchy-tidepool-theme",
                        changelog: "First cut." }
        }
      end
    end

    submission = Submission.last

    assert_redirected_to dashboard_path
    assert_match(/Submission received/i, flash[:notice])
    assert_equal "git_import", submission.kind
    assert_equal "tidepool", submission.theme_name
    assert_equal "https://github.com/rosewood/omarchy-tidepool-theme", submission.source_url
    assert_equal "First cut.", submission.changelog
    assert_equal @author, submission.user
    assert_predicate submission, :received?
  end

  test "a submission without a repo URL is refused with the form and an error" do
    sign_in_as @author

    assert_no_difference -> { Submission.count } do
      assert_no_enqueued_jobs only: ProcessSubmissionJob do
        post submissions_path, params: { submission: { theme_name: "tidepool" } }
      end
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors", /Source url can't be blank/i
    assert_select "form[action=?]", submissions_path
  end

  test "a nameless submission is refused" do
    sign_in_as @author

    assert_no_difference -> { Submission.count } do
      post submissions_path, params: {
        submission: { theme_name: "", source_url: "https://github.com/rosewood/omarchy-tidepool-theme" }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors", /Theme name can't be blank/i
  end

  # --- who may publish -----------------------------------------------------

  test "an unverified author is sent to the dashboard to verify first" do
    sign_in_as users(:two)

    get new_submission_path

    assert_redirected_to dashboard_path
    assert_match(/Verify your email address/i, flash[:alert])
  end

  test "an unverified author cannot post a submission at all" do
    sign_in_as users(:two)

    assert_no_difference -> { Submission.count } do
      post submissions_path, params: { submission: { theme_name: "tidepool", source_url: "https://github.com/rosewood/omarchy-tidepool-theme" } }
    end

    assert_redirected_to dashboard_path
    assert_match(/Verify your email address/i, flash[:alert])
  end

  test "the unverified author's dashboard offers to resend the link" do
    sign_in_as users(:two)

    get dashboard_path

    assert_response :success
    assert_select ".notice--warn form[action=?]", email_verifications_path
  end

  test "a signed-out visitor is sent to sign in before publishing" do
    get new_submission_path

    assert_redirected_to new_session_path

    assert_no_difference -> { Submission.count } do
      post submissions_path, params: { submission: { theme_name: "tidepool", source_url: "https://github.com/rosewood/omarchy-tidepool-theme" } }
    end

    assert_redirected_to new_session_path
  end

  # --- the dashboard -------------------------------------------------------

  test "the dashboard lists the author's themes with their newest version's state" do
    sign_in_as @author

    get dashboard_path

    assert_response :success
    assert_select ".dashtable" do
      assert_select "a[href=?]", theme_path("aurora"), "aurora"
      assert_select "td", "v2"
      assert_select ".state--pending", "pending"
    end
    assert_select "a[href=?]", new_submission_path(theme_name: "aurora")
  end

  test "an author with nothing published sees the invitation, not a table" do
    sign_in_as users(:admin)
    themes(:sherbet).destroy!

    get dashboard_path

    assert_select ".dashtable", count: 0
    assert_select ".empty", /haven't published anything yet/
  end

  test "the pipeline turns a submission into a version that is not installable yet" do
    sign_in_as @author

    submission = pipeline_submission("saltmarsh", "denied-files-theme.zip")

    assert_predicate submission, :accepted?
    assert_predicate submission.version, :pending?
    assert_equal "saltmarsh", submission.theme.name
    assert_equal 6, submission.version.normalization_ledger.size

    get theme_path("saltmarsh")

    assert_response :not_found, "a theme is not public until a human approves its first version"
  end

  test "a failed submission reports its errors on the dashboard" do
    sign_in_as @author

    pipeline_submission("nord", "good-theme.zip")

    get dashboard_path

    assert_select ".sub .state--failed", "failed"
    assert_select ".sub__errors li", /stock omarchy theme name/
  end

  test "an accepted submission reports its version and the normalization ledger" do
    sign_in_as @author

    submission = pipeline_submission("saltmarsh", "denied-files-theme.zip")

    assert_predicate submission, :accepted?
    assert_predicate submission.version, :pending?

    get dashboard_path

    assert_select "##{ActionView::RecordIdentifier.dom_id(submission)}" do
      assert_select ".state--accepted", "accepted"
      assert_select ".sub__name", "saltmarsh"
      assert_select ".sub__kind", "archive upload"
      assert_select ".sub__accepted", /became\s+v1\s+—\s+waiting for review/
      assert_select "details.sub__ledger summary", /6 files changed at normalization/
      assert_select "details.sub__ledger li code", "neovim.lua"
    end
    assert_select ".dashtable a[href=?]", new_submission_path(theme_name: "saltmarsh")
  end

  private
    # The product takes git URLs only, but the pipeline's internal archive
    # path is the deterministic way to materialize a submission in tests —
    # no network, same Validation/Normalization/verdict.
    def pipeline_submission(theme_name, archive_name)
      submission = @author.submissions.create!(kind: "archive_upload", theme_name:)
      submission.archive.attach(io: file_fixture("archives/#{archive_name}").open, filename: archive_name)
      Publishing::Pipeline.process(submission)
      submission.reload
    end
end
