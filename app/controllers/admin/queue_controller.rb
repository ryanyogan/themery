module Admin
  class QueueController < BaseController
    def show
      @pending = Version.pending.includes(theme: :author).order(:created_at)
      @recent = Version.where(state: %w[approved rejected]).includes(theme: :author)
        .order(updated_at: :desc).limit(10)
    end
  end
end
