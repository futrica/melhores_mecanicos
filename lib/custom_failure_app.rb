class CustomFailureApp < Devise::FailureApp
  def respond
    if warden_message == :unconfirmed
      resend_confirmation_if_needed
    end
    super
  end

  def i18n_message(default = nil)
    if warden_message == :unconfirmed
      email = extract_email
      if email.present?
        "Você precisa confirmar seu endereço de e-mail antes de continuar. Reenviamos as instruções de confirmação para #{email}! Por favor, verifique sua caixa de entrada e também a pasta de Spam."
      else
        "Você precisa confirmar seu endereço de e-mail antes de continuar. Reenviamos o e-mail de confirmação! Por favor, verifique sua caixa de entrada e também a pasta de Spam."
      end
    else
      super
    end
  end

  private

  def resend_confirmation_if_needed
    email = extract_email
    return if email.blank?

    user = User.find_by(email: email.to_s.downcase.strip)
    return unless user && !user.confirmed?

    user.send_confirmation_instructions
  end

  def extract_email
    params.dig(:user, :email) || request.params.dig(:user, :email)
  end
end
