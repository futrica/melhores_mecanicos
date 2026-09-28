class OutreachMailer < ApplicationMailer
  default from: "Hospedagem Direta <no-reply@hospedagemdireta.com.br>"

  def profile_presentation(company, token)
    @company = company
    @token = token
    @company_name = company.trade_name.presence || company.legal_name
    @views_count = company.views_count
    @unsubscribe_url = unsubscribe_url(token: token)
    @tracking_url = outreach_click_url(token: token)

    headers["List-Unsubscribe"] = "<#{@unsubscribe_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"

    mail(
      to: company.email,
      subject: "[#{@company_name}]: seu perfil teve #{@views_count} acessos no Hospedagem Direta"
    )
  end
end
