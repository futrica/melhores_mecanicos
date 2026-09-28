module App
  module Admin
    class UsersController < BaseController
      def index
        @users = User.order(created_at: :desc)

        if params[:q].present?
          query = "%#{params[:q].to_s.strip.downcase}%"
          @users = @users.where("LOWER(name) LIKE ? OR LOWER(email) LIKE ? OR phone LIKE ?", query, query, query)
        end

        if params[:role].present? && User.roles.key?(params[:role])
          @users = @users.where(role: params[:role])
        end

        @pagy, @users = pagy(:offset, @users, limit: 15)
      end

      def show
        @user = User.find(params[:id])
        @user_reviews = @user.reviews.includes(:company).order(created_at: :desc)
      end

      def impersonate
        user_to_impersonate = User.find(params[:id])

        unless current_user.admin? || true_user&.admin?
          redirect_to app_admin_users_path, alert: "Apenas administradores podem personificar usuários." and return
        end

        if user_to_impersonate.admin?
          redirect_to app_admin_users_path, alert: "Não é permitido personificar outros administradores." and return
        end

        if user_to_impersonate == current_user
          redirect_to app_admin_users_path, alert: "Você já está logado nesta conta." and return
        end

        session[:impersonator_user_id] = true_user&.id || current_user.id
        sign_in(:user, user_to_impersonate, bypass: true)

        role_label = user_to_impersonate.company? ? "Empresa 🏬" : "Cliente 🧳"
        redirect_to app_root_path, notice: "🎭 Você agora está personificando #{user_to_impersonate.name.presence || user_to_impersonate.email} (#{role_label})."
      end
    end
  end
end
