class ProcessSubmissionJob < ApplicationJob
  queue_as :default

  def perform(submission)
    Publishing::Pipeline.process(submission)
  end
end
