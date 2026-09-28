require "test_helper"

class UserConfirmationTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "unconfirmed user sign in attempt automatically resends confirmation email and sets flash message" do
    # Create unconfirmed user
    user = User.create!(
      email: "test_unconfirmed@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: "1",
      role: "client"
    )
    user.update_column(:confirmed_at, nil)

    assert_emails 1 do
      post user_session_path, params: {
        user: {
          email: user.email,
          password: "password123"
        }
      }
    end

    assert_redirected_to new_user_session_path
    follow_redirect!

    assert_match "Você precisa confirmar seu endereço de e-mail antes de continuar", flash[:alert]
    assert_match "Reenviamos", flash[:alert]
    assert_match "Spam", flash[:alert]

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ user.email ], mail.to
    assert_equal "Confirme seu e-mail - Hospedagem Direta", mail.subject
    assert_match "Confirmar meu e-mail", mail.html_part.body.to_s
    assert_match "Spam", mail.html_part.body.to_s
    assert_match "Hospedagem Direta", mail.text_part.body.to_s
  end

  test "confirmation email contains Portuguese text and anti-spam tip" do
    user = User.new(email: "novousuario@example.com", name: "Maria Silva")
    token = "sample_token_123"

    mail = Devise::Mailer.confirmation_instructions(user, token)

    assert_equal [ user.email ], mail.to
    assert_equal "Confirme seu e-mail - Hospedagem Direta", mail.subject
    assert_match "Maria Silva", mail.html_part.body.to_s
    assert_match "Confirmar meu e-mail", mail.html_part.body.to_s
    assert_match "Lixo Eletrônico", mail.html_part.body.to_s
    assert_match "Não é spam", mail.html_part.body.to_s
  end
end
