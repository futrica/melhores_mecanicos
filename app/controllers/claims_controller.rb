class ClaimsController < ApplicationController
  before_action :check_existing_company

  def new
    @company = Company.find_by(id: params[:company_id])
    session[:claim_company_id] = @company.id if @company.present?

    if @company.nil? && params[:q].present?
      raw_query = params[:q].to_s.strip
      clean_cnpj = raw_query.gsub(/\D/, "")
      query = "%#{raw_query.downcase}%"

      scope = Company.where(claim_status: :unclaimed)
      if clean_cnpj.length >= 8
        @companies = scope.where("replace(replace(replace(cnpj, '.', ''), '/', ''), '-', '') LIKE ? OR lower(trade_name) LIKE ? OR lower(legal_name) LIKE ?", "%#{clean_cnpj}%", query, query).limit(10)
      else
        @companies = scope.where("lower(trade_name) LIKE ? OR lower(legal_name) LIKE ?", query, query).limit(10)
      end
    end
  end

  def create
    @company = Company.find_by(id: params[:company_id])
    flash[:notice] = "Solicitação de reivindicação enviada com sucesso! Analisaremos seus dados e entraremos em contato em até 24 horas."

    if @company
      redirect_to company_page_path(
        state_slug: @company.state.slug,
        city_slug: @company.city.slug,
        neighborhood_slug: @company.neighborhood&.slug || "centro",
        slug: @company.slug
      )
    else
      redirect_to root_path
    end
  end

  private

  def check_existing_company
    if user_signed_in? && (current_user.company.present? || current_user.admin?)
      redirect_to app_root_path, alert: "Você já possui uma empresa reivindicada ou em processo de verificação."
    end
  end
end
