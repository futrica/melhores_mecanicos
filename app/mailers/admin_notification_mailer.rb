class AdminNotificationMailer < ApplicationMailer
  default from: "Hospedagem Direta <noreply@hospedagemdireta.com.br>",
          to: -> { ENV.fetch("ADMIN_EMAIL", "jmfutrica@gmail.com") }

  def company_claim_notification(company, user = nil, verification_type = "reivindicação")
    @company = company
    @user = user || company.user
    @verification_type = verification_type
    company_name = company.trade_name.presence || company.legal_name
    mail(
      subject: "[Hospedagem Direta] Nova #{@verification_type} de empresa: #{company_name}"
    )
  end

  def company_removal_notification(company, name:, email:, reason: nil)
    @company = company
    @name = name
    @email = email
    @reason = reason
    company_name = company.trade_name.presence || company.legal_name
    mail(
      subject: "[Hospedagem Direta] Solicitação de remoção LGPD: #{company_name}"
    )
  end

  def monthly_sync_started(app_name:, start_time:, initial_stats:)
    @app_name = app_name
    @start_time = start_time
    @initial_stats = initial_stats
    mail(
      to: "jmfutrica@gmail.com",
      subject: "[#{@app_name}] 🚀 Sincronização Mensal da Receita Federal Iniciada - #{@start_time.strftime('%d/%m/%Y %H:%M')}"
    )
  end

  def monthly_sync_completed(app_name:, start_time:, end_time:, duration_minutes:, stats:)
    @app_name = app_name
    @start_time = start_time
    @end_time = end_time
    @duration_minutes = duration_minutes
    @stats = stats
    mail(
      to: "jmfutrica@gmail.com",
      subject: "[#{@app_name}] 🎉 Sincronização Mensal Concluída com Sucesso (#{@duration_minutes} min)"
    )
  end

  def monthly_sync_failed(app_name:, start_time:, end_time:, duration_minutes:, error_message:, backtrace: nil)
    @app_name = app_name
    @start_time = start_time
    @end_time = end_time
    @duration_minutes = duration_minutes
    @error_message = error_message
    @backtrace = backtrace
    mail(
      to: "jmfutrica@gmail.com",
      subject: "[#{@app_name}] ❌ ERRO na Sincronização Mensal da Receita Federal"
    )
  end
end
