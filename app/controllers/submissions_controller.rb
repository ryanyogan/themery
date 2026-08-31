class SubmissionsController < ApplicationController
  before_action :require_verified_email
  rate_limit to: 10, within: 1.hour, only: :create, with: -> { redirect_to new_submission_path, alert: "Too many submissions — try again in a bit." }

  MAX_ARCHIVE_BYTES = 50.megabytes

  def new
    @submission = Submission.new(theme_name: params[:theme_name])
  end

  def create
    @submission = Current.user.submissions.new(submission_params)
    @submission.kind = @submission.archive.attached? ? "archive_upload" : "git_import"

    if oversized?
      @submission.errors.add(:archive, "is larger than 50MB")
      return render :new, status: :unprocessable_entity
    end

    if @submission.save
      ProcessSubmissionJob.perform_later(@submission)
      redirect_to dashboard_path, notice: "Submission received — validating now."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def submission_params
      params.expect(submission: [ :theme_name, :source_url, :changelog, :archive ])
    end

    def oversized?
      @submission.archive.attached? && @submission.archive.blob.byte_size > MAX_ARCHIVE_BYTES
    end

    def require_verified_email
      return if Current.user.verified?
      redirect_to dashboard_path, alert: "Verify your email address before publishing — check your inbox, or resend the link below."
    end
end
