module Admin
  class BaseController < ApplicationController
    # Skip the sign-in redirect: a signed-out probe of /admin must get the
    # same 404 as a wrong URL, not a redirect that confirms something is
    # here. The admin check below covers authentication and authorization
    # in one gesture — the queue's existence is nobody else's business.
    allow_unauthenticated_access
    before_action :resume_session
    before_action :require_admin

    private
      def require_admin
        raise ActiveRecord::RecordNotFound unless Current.user&.admin?
      end
  end
end
