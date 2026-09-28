module App
  module Admin
    class BaseController < App::BaseController
      before_action :ensure_admin!

      private

      def ensure_admin!
        unless current_user&.admin?
          redirect_to app_root_path, alert: "Acesso restrito a administradores."
        end
      end
    end
  end
end
