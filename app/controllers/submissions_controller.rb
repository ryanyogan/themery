class SubmissionsController < ApplicationController
  before_action :require_verified_email, only: %i[ new create ]
  rate_limit to: 10, within: 1.hour, only: :create, with: -> { redirect_to new_submission_path, alert: "Too many submissions — try again in a bit." }

  def new
    @submission = Submission.new(theme_name: params[:theme_name])
  end

  def create
    @submission = Current.user.submissions.new(submission_params.merge(kind: "git_import"))

    if @submission.save
      ProcessSubmissionJob.perform_later(@submission)
      redirect_to dashboard_path, notice: "Submission received — validating now."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Only dead submissions can be cleared — accepted ones are the audit trail.
  def destroy
    submission = Current.user.submissions.find(params[:id])
    unless submission.failed? || submission.skipped?
      return redirect_to dashboard_path, alert: "Only failed submissions can be removed."
    end

    submission.destroy!
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(submission) }
      format.html { redirect_to dashboard_path, notice: "Submission removed." }
    end
  end

  private
    def submission_params
      params.expect(submission: [ :theme_name, :source_url, :changelog ])
    end

    def require_verified_email
      return if Current.user.verified?
      redirect_to dashboard_path, alert: "Verify your email address before publishing — check your inbox, or resend the link below."
    end
end
