class RemovalsController < ApplicationController
  def new
    @company = Company.find_by!(id: params[:company_id])
  end

  def create
    @company = Company.find_by!(id: params[:company_id])
    name = params[:name]
    email = params[:email]
    reason = params[:reason]

    if name.blank? || email.blank?
      flash.now[:alert] = "Por favor, informe seu nome e e-mail de contato para solicitar a remoção."
      render :new, status: :unprocessable_entity and return
    end

    @company.update!(
      claim_status: :pending,
      removal_requested: true,
      removal_request_name: name,
      removal_request_email: email,
      document_submitted_at: Time.current
    )

    AdminNotificationMailer.company_removal_notification(
      @company,
      name: name,
      email: email,
      reason: reason
    ).deliver_later

    redirect_to root_path, notice: "Solicitação de remoção enviada com sucesso em conformidade com a LGPD. Analisaremos seu pedido em até 5 dias úteis."
  end
end
