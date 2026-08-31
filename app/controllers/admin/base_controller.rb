module Admin
  class BaseController < ApplicationController
    before_action :require_admin

    private
      # Non-admins get the same 404 as a wrong URL — the queue's existence
      # is nobody else's business.
      def require_admin
        raise ActiveRecord::RecordNotFound unless Current.user&.admin?
      end
  end
end
