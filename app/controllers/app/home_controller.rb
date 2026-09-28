module App
  class HomeController < BaseController
    before_action :ensure_admin, only: [ :approve_company, :reject_company ]

    def index
      case current_user.role
      when "client"
        if current_user.company.present?
          current_user.convert_to_company!
          @company = Company.includes(:state, :city, :neighborhood, :reviews).find_by(id: current_user.company.id)
          render :company_dashboard
        else
          @favorited_companies = current_user.favorited_companies
                                             .includes(:state, :city, :neighborhood, :categories)
                                             .order(:trade_name)
          @reviews = current_user.reviews
                                 .includes(company: [ :state, :city ])
                                 .order(created_at: :desc)
          render :client_dashboard
        end
      when "company"
        @company = Company.includes(:state, :city, :neighborhood, :reviews).find_by(user_id: current_user.id) || current_user.company
        if @company.blank? && params[:search_query].present?
          query = "%#{params[:search_query].downcase}%"
          @search_results = Company.where(claim_status: :unclaimed)
                                   .where("lower(trade_name) LIKE ? OR lower(legal_name) LIKE ?", query, query)
                                   .limit(10)
        end
        render :company_dashboard
      when "admin"
        redirect_to app_admin_dashboard_path
      else
        redirect_to root_path, alert: "Área não encontrada."
      end
    end

    def approve_company
      company = Company.unscoped.find(params[:id])
      if company.removal_requested?
        company.soft_delete!
        redirect_back fallback_location: app_admin_companies_path, notice: "Perfil de #{company.trade_name.presence || company.legal_name} foi removido com sucesso (LGPD)!"
      else
        company.update!(claim_status: :approved, claim_expiration_date: nil)
        UserMailer.company_approved(company).deliver_later
        redirect_back fallback_location: app_admin_companies_path, notice: "Perfil de #{company.trade_name.presence || company.legal_name} aprovado e verificado com sucesso!"
      end
    end

    def reject_company
      company = Company.unscoped.find(params[:id])
      if company.removal_requested?
        company.update!(
          claim_status: :unclaimed,
          removal_requested: false,
          removal_request_name: nil,
          removal_request_email: nil,
          document_submitted_at: nil,
          document_proof_url: nil,
          selfie_proof_url: nil
        )
        redirect_back fallback_location: app_admin_companies_path, notice: "Solicitação de remoção de #{company.trade_name.presence || company.legal_name} rejeitada. O perfil permanece ativo."
      else
        company.update!(
          user: nil,
          claim_status: :unclaimed,
          claimed_at: nil,
          document_submitted_at: nil,
          document_proof_url: nil,
          selfie_proof_url: nil,
          claim_expiration_date: nil
        )
        redirect_back fallback_location: app_admin_companies_path, notice: "Reivindicação de #{company.trade_name.presence || company.legal_name} rejeitada. O perfil foi liberado."
      end
    end

    private

    def ensure_admin
      unless current_user.admin?
        redirect_to app_root_path, alert: "Acesso não autorizado."
      end
    end
  end
end
