class ContactMailer < ApplicationMailer
  default from: "contato@hospedagemdireta.com.br"

  def contact_email(contact)
    @contact = contact
    mail(
      to: ENV.fetch("ADMIN_EMAIL", "jmfutrica@gmail.com"),
      subject: "[Hospedagem Direta] Nova mensagem de contato: #{@contact.subject}"
    )
  end

  def owner_inquiry_reply(recipient_email:, recipient_name: nil, subject: nil)
    @name = recipient_name.presence || "Proprietário(a)"
    mail(
      from: "Hospedagem Direta <contato@hospedagemdireta.com.br>",
      to: recipient_email,
      bcc: "jmfutrica@gmail.com",
      subject: subject || "Re: Como funciona o Hospedagem Direta"
    )
  end
end
