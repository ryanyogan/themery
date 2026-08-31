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
    @category = params[:category].presence_in(PaletteTaxonomy::CATEGORIES)
    @mood = params[:mood].presence_in(PaletteTaxonomy::MOODS)
    @build = params[:build].presence_in(BuildKind::KINDS)
    @query = params[:q].presence

    themes = Theme.published.with_latest_version.order(SORTS[@sort])
    themes = themes.where(mode: @mode) if @mode
    themes = themes.where(category: @category) if @category
    themes = themes.where(mood: @mood) if @mood
    themes = themes.where(build_kind: @build) if @build
    themes = themes.where("themes.name LIKE ?", "%#{Theme.sanitize_sql_like(@query.downcase)}%") if @query
    @themes = themes
    @filtered = [ @mode, @category, @mood, @build, @query ].any?
    @pulse = recent_pulse
  end

  def show
    @theme = Theme.published.find_by!(name: params[:name])
    @version = @theme.latest_approved_version
    @versions = @theme.versions.approved.newest_first
    @reviews = @theme.reviews.newest_first.includes(:user)
  end

  def og
    theme = Theme.published.find_by!(name: params[:name])
    version = theme.versions.approved.where.not(og_card_attachment: { id: nil })
      .joins(:og_card_attachment).order(:number).last
    raise ActiveRecord::RecordNotFound unless version

    expires_in 1.hour, public: true
    send_data version.og_card.download, type: "image/png", disposition: "inline"
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

  private
    # The homepage's quiet sign of life: recent approvals and stars, merged.
    def recent_pulse
      published = Version.approved.where.not(approved_at: nil).includes(:theme)
        .order(approved_at: :desc).limit(4).map do |version|
          { kind: :published, theme_name: version.theme.name, version_number: version.number, at: version.approved_at }
        end
      starred = Star.includes(:theme, :user).order(created_at: :desc).limit(4).map do |star|
        { kind: :starred, theme_name: star.theme.name, username: star.user&.username, at: star.created_at }
      end
      (published + starred).sort_by { |item| item[:at] }.reverse.first(5)
    end
end
