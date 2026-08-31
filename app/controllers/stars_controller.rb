class StarsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 60, within: 1.hour, with: -> { head :too_many_requests }
  before_action :set_theme

  def create
    star = begin
      Star.find_or_create_by!(theme: @theme, voter_key: current_voter_key) do |new_star|
        new_star.user = Current.user
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      Star.find_by!(theme: @theme, voter_key: current_voter_key)
    end
    broadcast_counts
    broadcast_pulse(star) if star.previously_new_record?
    respond_with_button
  end

  def destroy
    Star.destroy_by(theme: @theme, voter_key: current_voter_key)
    broadcast_counts
    respond_with_button
  end

  private
    def set_theme
      @theme = Theme.published.find_by!(name: params[:theme_name])
    end

    # Everyone watching the page gets the new count; only the actor's own
    # button flips, via this response — "starred by me" never broadcasts.
    def broadcast_counts
      @theme.reload
      Turbo::StreamsChannel.broadcast_replace_to(
        @theme, target: ActionView::RecordIdentifier.dom_id(@theme, :counts),
        partial: "themes/counts", locals: { theme: @theme }
      )
    end

    def broadcast_pulse(star)
      Turbo::StreamsChannel.broadcast_prepend_to(
        "activity", target: "activity_pulse", partial: "activity/item",
        locals: { kind: :starred, theme_name: @theme.name,
                  username: star.user&.username, at: star.created_at }
      )
    end

    def respond_with_button
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(ActionView::RecordIdentifier.dom_id(@theme, :star_button),
              partial: "themes/star_button", locals: { theme: @theme }),
            turbo_stream.replace(ActionView::RecordIdentifier.dom_id(@theme, :counts),
              partial: "themes/counts", locals: { theme: @theme })
          ]
        end
        format.html { redirect_to theme_path(@theme.name) }
      end
    end
end
