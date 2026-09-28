class UnsubscribesController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :create ], if: -> { request.format.json? || request.headers["List-Unsubscribe"].present? }

  def show
    @token = params[:token]
    @opt_out = CompanyEmailOptOut.find_by(token: @token)

    if @opt_out.nil?
      flash.now[:alert] = "Link de descadastramento inválido ou expirado."
    end
  end

  def create
    @token = params[:token]
    @opt_out = CompanyEmailOptOut.find_by(token: @token)

    if @opt_out.nil?
      email = params[:email]
      if email.present?
        @opt_out = CompanyEmailOptOut.find_or_create_by_token_or_email!(
          email: email,
          reason: params[:reason],
          feedback: params[:feedback],
          unsubscribed: true
        )
      else
        redirect_to root_path, alert: "Link ou e-mail inválido para descadastramento."
        return
      end
    else
      @opt_out.update!(
        reason: params[:reason],
        feedback: params[:feedback],
        unsubscribed_at: Time.current
      )
    end

    respond_to do |format|
      format.html
      format.json { render json: { status: "ok", message: "Unsubscribed successfully" } }
    end
  end
end
