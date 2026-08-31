class StarredThemesController < ApplicationController
  def show
    @themes = Current.user.starred_themes.published.with_latest_version.order("stars.created_at DESC")
  end
end
