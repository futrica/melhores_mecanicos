class SubscriptionMailer < ApplicationMailer
  default from: "Hospedagem Direta <noreply@hospedagemdireta.com.br>"

  def subscription_activated_email(subscription)
    @subscription = subscription
    @company = subscription.company
    @price = subscription.stripe_price
    @product = subscription.stripe_product
    @user = @company.user

    recipient_email = @company.email.presence || @user&.email
    return if recipient_email.blank?

    mail(
      to: recipient_email,
      subject: "🎉 Assinatura do #{@product.name} Ativada com Sucesso - Hospedagem Direta"
    )
  end

  def subscription_canceled_email(subscription)
    @subscription = subscription
    @company = subscription.company
    @product = subscription.stripe_product
    @user = @company.user

    recipient_email = @company.email.presence || @user&.email
    return if recipient_email.blank?

    mail(
      to: recipient_email,
      subject: "Confirmação de Cancelamento de Plano - Hospedagem Direta"
    )
  end
end
