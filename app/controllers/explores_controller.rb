class ExploresController < ApplicationController
  allow_unauthenticated_access

  def show
    @most_installed = Theme.published.with_latest_version
      .order(installs_count: :desc, stars_count: :desc).limit(6)
    @newest = Theme.published.with_latest_version
      .joins(:versions).where(versions: { state: "approved" })
      .group("themes.id").order(Arel.sql("MIN(versions.approved_at) DESC")).limit(6)
    @maintainers = active_maintainers
    @builds = BuildKind::KINDS.index_with do |kind|
      {
        count: Theme.published.where(build_kind: kind).distinct.count(:id),
        themes: Theme.published.with_latest_version.where(build_kind: kind)
          .order(stars_count: :desc, installs_count: :desc).limit(3)
      }
    end
  end

  private
    # Authors ranked by shipping: approved versions in the last 90 days
    # first, catalog size as the tiebreak.
    def active_maintainers
      recent = Version.approved.where(approved_at: 90.days.ago..)
        .joins(:theme).group("themes.user_id").count

      User.where(id: recent.keys).includes(themes: :latest_version)
        .sort_by { |user| [ -recent[user.id], -user.themes.size ] }
        .first(6)
        .map { |user| [ user, recent[user.id] ] }
    end
end
