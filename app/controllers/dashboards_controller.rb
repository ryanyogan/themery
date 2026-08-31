class DashboardsController < ApplicationController
  def show
    @themes = Current.user.themes.includes(versions: []).order(:name)

    submissions = Current.user.submissions.newest_first.includes(:theme, :version).limit(60)
    @processing = submissions.select(&:received?)
    @accepted = submissions.select(&:accepted?)
    @failed = submissions.select { |submission| submission.failed? || submission.skipped? }
  end
end
