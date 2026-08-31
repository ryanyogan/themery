# The hourly upstream check (see config/recurring.yml): for every theme
# published from a git repo, one cheap ls-remote decides whether upstream
# moved. A moved HEAD auto-submits through the normal pipeline — so an
# upstream change still passes Validation, Normalization, and human
# Approval before any installed user can receive it. The recorded commit
# advances at check time, so a broken or unchanged upstream costs exactly
# one ls-remote per hour, never a re-clone loop.
class SyncUpstreamThemesJob < ApplicationJob
  queue_as :default

  def perform
    Theme.published.where.not(source_url: nil).find_each do |theme|
      next if theme.pending_version.present?

      head = Publishing::GitImport.remote_head(theme.source_url)
      next if head.nil? || head == theme.upstream_commit

      theme.update!(upstream_commit: head)
      submission = theme.author.submissions.create!(
        kind: "git_import", theme_name: theme.name, source_url: theme.source_url,
        changelog: "Synced from upstream (#{head.first(7)})"
      )
      ProcessSubmissionJob.perform_later(submission)
    end
  end
end
