# Rolls raw fetch telemetry into the install/update counters and pushes the
# new numbers to anyone watching a theme page. Runs on a schedule (see
# config/recurring.yml) rather than per-clone — Solid Cable is poll-backed,
# and a hot theme's clone burst shouldn't become a broadcast storm.
class RecountFetchesJob < ApplicationJob
  queue_as :default

  def perform
    Theme.where(id: FetchEvent.where(created_at: 10.minutes.ago..).select(:theme_id)).find_each do |theme|
      before = [ theme.installs_count, theme.updates_count ]
      FetchEvent.recount!(theme)
      theme.reload
      next if before == [ theme.installs_count, theme.updates_count ]

      Turbo::StreamsChannel.broadcast_replace_to(
        theme, target: ActionView::RecordIdentifier.dom_id(theme, :counts),
        partial: "themes/counts", locals: { theme: }
      )
    end
  end
end
