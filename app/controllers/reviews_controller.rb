class ReviewsController < ApplicationController
  before_action :set_theme

  def create
    review = Current.user.reviews.new(theme: @theme, body: params.expect(review: [ :body ])[:body])
    if review.save
      redirect_to theme_path(@theme.name), notice: "Review posted."
    else
      redirect_to theme_path(@theme.name), alert: review.errors.full_messages.to_sentence
    end
  end

  def destroy
    Current.user.reviews.destroy_by(theme: @theme)
    redirect_to theme_path(@theme.name), notice: "Review removed."
  end

  private
    def set_theme
      @theme = Theme.published.find_by!(name: params[:theme_name])
    end
end
