class ProcessSubmissionJob < ApplicationJob
  queue_as :default

  def perform(submission)
    Publishing::Pipeline.process(submission)
    # The author is likely watching their dashboard; morph it with the verdict.
    Turbo::StreamsChannel.broadcast_refresh_to([ submission.user, :dashboard ])
  end
end
