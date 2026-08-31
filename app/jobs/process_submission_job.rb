class ProcessSubmissionJob < ApplicationJob
  queue_as :default

  def perform(submission)
    Publishing::Pipeline.process(submission)
    # The author is likely watching their dashboard; morph it with the verdict.
    Turbo::StreamsChannel.broadcast_refresh_to([ submission.user, :dashboard ])
    # And the admin never refreshes to see new work arrive.
    Turbo::StreamsChannel.broadcast_refresh_to(:admin_queue)
  end
end
