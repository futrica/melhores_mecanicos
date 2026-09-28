class ServerHealthMailer < ApplicationMailer
  default from: "Hospedagem Direta <noreply@hospedagemdireta.com.br>"

  def health_report(stats)
    @stats = stats
    @recipient = ENV.fetch("ADMIN_EMAIL", "jmfutrica@gmail.com")

    mail(
      to: @recipient,
      subject: "[Diagnóstico de Saúde] Servidor-Projetos - #{Time.current.strftime('%d/%m/%Y')}"
    )
  end
end
