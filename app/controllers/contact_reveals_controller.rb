class ContactRevealsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :create ], if: -> { request.format.json? }

  def create
    @company = Company.find(params[:company_id])
    contact_type = params[:contact_type].presence || "unknown"

    ContactRevealLog.create!(
      company: @company,
      user: current_user,
      contact_type: contact_type,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      disclaimer_accepted: true
    )

    render json: { success: true }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Empresa não encontrada" }, status: :not_found
  rescue StandardError => e
    Rails.logger.error("Error creating ContactRevealLog: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
