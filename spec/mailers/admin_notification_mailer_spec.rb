require "rails_helper"

RSpec.describe AdminNotificationMailer, type: :mailer do
  let(:state) { State.find_by(acronym: 'SP') || State.create!(acronym: 'SP', name: 'São Paulo', slug: 'sp', ibge_code: '35') }
  let(:city) { City.find_by(slug: 'sao-paulo', state: state) || City.create!(state: state, name: 'São Paulo', slug: 'sao-paulo', ibge_code: '3550308') }
  let(:user) { User.create!(name: "João Teste", email: "joao@example.com", password: "password123", password_confirmation: "password123", terms_accepted: "1", confirmed_at: Time.current) }
  let(:company) do
    Company.create!(
      legal_name: "Empresa Teste LTDA",
      trade_name: "Oficina Teste",
      cnpj: "12345678000199",
      cnae_principal: "4520-0/01",
      status: "ATIVA",
      state: state,
      city: city,
      user: user
    )
  end

  describe "#company_claim_notification" do
    let(:mail) { AdminNotificationMailer.company_claim_notification(company, user, "reivindicação") }

    it "renders the headers" do
      expect(mail.to).to eq([ "jmfutrica@gmail.com" ])
      expect(mail.subject).to include("Nova reivindicação de empresa: Oficina Teste")
    end

    it "renders the body with company info" do
      expect(mail.body.encoded).to include("Oficina Teste")
      expect(mail.body.encoded).to include("12345678000199")
    end
  end

  describe "#company_removal_notification" do
    let(:mail) do
      AdminNotificationMailer.company_removal_notification(
        company,
        name: "Carlos Solicitante",
        email: "carlos@example.com",
        reason: "Solicito a exclusão de dados pessoais."
      )
    end

    it "renders the headers" do
      expect(mail.to).to eq([ "jmfutrica@gmail.com" ])
      expect(mail.subject).to include("Solicitação de remoção LGPD: Oficina Teste")
    end

    it "renders the body with removal request info" do
      expect(mail.body.encoded).to include("Carlos Solicitante")
      expect(mail.body.encoded).to include("carlos@example.com")
      expect(mail.body.encoded).to include("Solicito a exclusão de dados pessoais.")
    end
  end
end
