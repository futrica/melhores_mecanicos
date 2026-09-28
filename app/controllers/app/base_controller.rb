module App
  class BaseController < ApplicationController
    before_action :authenticate_user!
    layout "app"

    private

    def ensure_client!
      unless current_user.client?
        redirect_to app_root_path, alert: "Área exclusiva para clientes."
      end
    end
  end
end
