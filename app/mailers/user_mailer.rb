class UserMailer < ApplicationMailer
  default from: "Melhores Mecânicos <contato@melhoresmecanicos.com.br>"

  def client_welcome(user)
    @user = user
    @first_name = user.name.presence&.split&.first || "Motorista"

    mail(
      to: user.email,
      subject: "Bem-vindo(a) ao Melhores Mecânicos, #{@first_name}! 🚗"
    )
  end

  def company_welcome(user)
    @user = user
    @company = user.company
    @first_name = user.name.presence&.split&.first || "Parceiro"
    @company_name = @company&.trade_name.presence || @company&.legal_name || "sua oficina"

    mail(
      to: user.email,
      subject: "Bem-vindo(a) ao Melhores Mecânicos! Gerencie seu perfil de oficina 🔧"
    )
  end

  def company_approved(company, user = nil)
    @company = company
    @user = user || company.user
    @recipient_email = @user&.email.presence || company.email
    return if @recipient_email.blank?

    @first_name = @user&.name.presence&.split&.first || "Parceiro"
    @company_name = company.trade_name.presence || company.legal_name || "sua oficina"

    mail(
      to: @recipient_email,
      bcc: "jmfutrica@gmail.com",
      subject: "🎉 Seu perfil no Melhores Mecânicos foi aprovado!"
    )
  end
end
