class AuthorsController < ApplicationController
  allow_unauthenticated_access

  def show
    @author = User.find_by!(username: params[:username])
    @themes = @author.themes.published.with_latest_version.order(stars_count: :desc)
  end
end
