class DashboardsController < ApplicationController
  def show
    @themes = Current.user.themes.includes(versions: []).order(:name)
    @submissions = Current.user.submissions.newest_first.includes(:theme, :version).limit(20)
  end
end
