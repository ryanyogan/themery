class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_voter_key

  private
    # The identity a star belongs to: the account when signed in, otherwise
    # a stable, unreversible hash of the visitor's address — starring costs
    # one click, not a signup.
    def current_voter_key
      if authenticated?
        "user:#{Current.user.id}"
      else
        digest = Digest::SHA256.hexdigest("star:#{request.remote_ip}:#{Rails.application.secret_key_base}")
        "anon:#{digest.first(16)}"
      end
    end
end
