class ApplicationController < ActionController::Base
  include Pagy::Method
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from ActiveRecord::RecordNotFound, with: :render_404

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :block_heavy_scrapers
  before_action :set_global_cache_headers

  def bot_request?
    user_agent = request.user_agent.to_s
    return false if Rails.env.test? && user_agent.blank?
    return true if user_agent.blank?

    user_agent.match?(/(bot|crawler|spider|slurp|yandex|bytespider|gptbot|claudebot|diffbot|perplexity|ccbot|semrush|ahrefs|sleepbot|amzn-searchbot|headless|curl|wget|python|php|ruby)/i).present?
  end
  helper_method :bot_request?

  def impersonating?
    session[:impersonator_user_id].present?
  end
  helper_method :impersonating?

  def true_user
    if impersonating?
      User.find_by(id: session[:impersonator_user_id]) || current_user
    else
      current_user
    end
  end
  helper_method :true_user

  def stop_impersonating
    unless impersonating?
      redirect_to root_path, alert: "Você não está no modo de personificação." and return
    end

    admin_user = User.find_by(id: session[:impersonator_user_id])
    session[:impersonator_user_id] = nil

    if admin_user
      sign_in(:user, admin_user, bypass: true)
      redirect_to app_admin_users_path, notice: "Você saiu do modo de personificação e retornou à sua conta de Administrador."
    else
      sign_out(:user)
      redirect_to new_user_session_path, alert: "Sessão de personificação encerrada."
    end
  end

  private

  def set_global_cache_headers
    if user_signed_in?
      response.headers["Cache-Control"] = "no-cache, no-store, private, must-revalidate"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "0"
    end
  end

  def block_heavy_scrapers
    user_agent = request.user_agent.to_s
    if user_agent.match?(/(Bytespider|CCBot|Diffbot|SleepBot|DotBot|PetalBot)/i)
      head :forbidden
    end
  end

  def render_404
    render file: Rails.root.join("public", "404.html"), status: :not_found, layout: false
  end


  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up) do |u|
      u.permit(:email, :password, :password_confirmation, :name, :phone, :terms_accepted, :role).tap do |p|
        p[:role] = "client" unless %w[client company].include?(p[:role])
      end
    end
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name, :phone ])
  end

  def ensure_confirmed!
    return if current_user&.admin?
    unless current_user&.confirmed?
      flash[:alert] = "Por favor, confirme seu endereço de e-mail para realizar esta ação. Verifique sua caixa de entrada."
      redirect_back(fallback_location: root_path)
    end
  end

  def after_sign_in_path_for(resource_or_scope)
    resource = resource_or_scope
    stored_location = stored_location_for(resource)

    is_company_or_admin = resource.is_a?(User) && (resource.company? || resource.company.present? || resource.admin?)

    if is_company_or_admin
      app_root_path
    elsif stored_location.present? && stored_location != root_path
      stored_location
    else
      app_root_path
    end
  end
end
