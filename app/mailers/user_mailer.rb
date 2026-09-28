class UserMailer < ApplicationMailer
  default from: "Hospedagem Direta <contato@hospedagemdireta.com.br>"

  def client_welcome(user)
    @user = user
    @first_name = user.name.presence&.split&.first || "Viajante"

    mail(
      to: user.email,
      subject: "Bem-vindo(a) ao Hospedagem Direta, #{@first_name}! 🏨"
    )
  end

  def company_welcome(user)
    @user = user
    @company = user.company
    @first_name = user.name.presence&.split&.first || "Parceiro"
    @company_name = @company&.trade_name.presence || @company&.legal_name || "seu estabelecimento"

    mail(
      to: user.email,
      subject: "Bem-vindo(a) ao Hospedagem Direta! Gerencie seu perfil de hospedagem 🏨"
    )
  end

  def company_approved(company, user = nil)
    @company = company
    @user = user || company.user
    @recipient_email = @user&.email.presence || company.email
    return if @recipient_email.blank?

    @first_name = @user&.name.presence&.split&.first || "Parceiro"
    @company_name = company.trade_name.presence || company.legal_name || "seu estabelecimento"

    mail(
      to: @recipient_email,
      bcc: "jmfutrica@gmail.com",
      subject: "🎉 Seu perfil no Hospedagem Direta foi aprovado!"
    )
  end
end
