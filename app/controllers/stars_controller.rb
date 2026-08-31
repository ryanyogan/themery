class StarsController < ApplicationController
  before_action :set_theme

  def create
    # find-first makes a repeat tap a no-op; the rescue covers the race
    # where two requests pass the find simultaneously (the unique index and
    # model validation stop the loser).
    star = begin
      Current.user.stars.find_or_create_by!(theme: @theme)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      Current.user.stars.find_by!(theme: @theme)
    end
    broadcast_counts
    broadcast_pulse(star) if star.previously_new_record?
    respond_with_button
  end

  def destroy
    Current.user.stars.destroy_by(theme: @theme)
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
                  username: Current.user.username, at: star.created_at }
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
