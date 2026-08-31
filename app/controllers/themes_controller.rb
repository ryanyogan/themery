class ThemesController < ApplicationController
  allow_unauthenticated_access

  SORTS = {
    "stars" => { stars_count: :desc, created_at: :desc },
    "installs" => { installs_count: :desc, created_at: :desc },
    "new" => { created_at: :desc }
  }.freeze

  def index
    @sort = SORTS.key?(params[:sort]) ? params[:sort] : "stars"
    @mode = params[:mode].presence_in(%w[light dark])
    @query = params[:q].presence

    themes = Theme.published.with_latest_version.order(SORTS[@sort])
    themes = themes.where(mode: @mode) if @mode
    themes = themes.where("themes.name LIKE ?", "%#{Theme.sanitize_sql_like(@query.downcase)}%") if @query
    @themes = themes
  end

  def show
    @theme = Theme.published.find_by!(name: params[:name])
    @version = @theme.latest_approved_version
    @versions = @theme.versions.approved.newest_first
    @reviews = @theme.reviews.newest_first.includes(:user)
  end

  def try
    theme = Theme.published.find_by!(name: params[:name])
    session[:trying_theme] = theme.name
    redirect_back fallback_location: theme_path(theme.name)
  end

  def stop_trying
    session.delete(:trying_theme)
    redirect_back fallback_location: root_path
  end
end
