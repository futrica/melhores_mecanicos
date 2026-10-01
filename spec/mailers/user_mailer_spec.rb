require 'rails_helper'

RSpec.describe UserMailer, type: :mailer do
  let!(:state) { State.find_or_create_by!(acronym: "SP") { |s| s.name = "São Paulo"; s.slug = "sp" } }
  let!(:city) { City.find_or_create_by!(slug: "sao-paulo", state: state) { |c| c.name = "São Paulo"; c.ibge_code = "3550308" } }

  let(:client_user) do
    User.create!(
      email: "cliente@teste.com",
      password: "password123",
      name: "João Silva",
      role: "client",
      terms_accepted: "1"
    )
  end

  let(:company_user) do
    User.create!(
      email: "empresa@teste.com",
      password: "password123",
      name: "Maria Oliveira",
      role: "company",
      terms_accepted: "1"
    )
  end

  describe "#client_welcome" do
    it "renders the client welcome email successfully" do
      mail = UserMailer.client_welcome(client_user)

      expect(mail.subject).to include("Bem-vindo(a) ao Melhores Mecânicos, João!")
      expect(mail.to).to eq([ "cliente@teste.com" ])
      expect(mail.from).to eq([ "contato@melhoresmecanicos.com.br" ])
      expect(mail.html_part.body.decoded).to include("João")
      expect(mail.html_part.body.decoded).to include("sem intermediários e sem taxas de comissão")
    end
  end

  describe "#company_welcome" do
    it "renders the company welcome email successfully" do
      mail = UserMailer.company_welcome(company_user)

      expect(mail.subject).to include("Bem-vindo(a) ao Melhores Mecânicos! Gerencie seu perfil de oficina")
      expect(mail.to).to eq([ "empresa@teste.com" ])
      expect(mail.from).to eq([ "contato@melhoresmecanicos.com.br" ])
      expect(mail.html_part.body.decoded).to include("Maria")
      expect(mail.html_part.body.decoded).to include("Acessar Meu Painel de Empresa")
    end
  end

  describe "#company_approved" do
    let(:company) do
      Company.create!(
        state: state,
        city: city,
        cnpj: "11222333000199",
        legal_name: "Auto Mecânica Teste LTDA",
        trade_name: "Oficina Teste",
        email: "oficina@teste.com",
        cnae_principal: "4520-0/01",
        status: "Ativa",
        user: company_user
      )
    end

    it "renders the company approved email successfully with bcc to jmfutrica@gmail.com" do
      mail = UserMailer.company_approved(company)

      expect(mail.subject).to eq("🎉 Seu perfil no Melhores Mecânicos foi aprovado!")
      expect(mail.to).to eq([ "empresa@teste.com" ])
      expect(mail.bcc).to eq([ "jmfutrica@gmail.com" ])
      expect(mail.from).to eq([ "contato@melhoresmecanicos.com.br" ])
      body_content = (mail.html_part&.body || mail.body).decoded
      expect(body_content).to include("Maria")
      expect(body_content).to include("Oficina Teste")
      expect(body_content).to include("foram aprovadas com sucesso")
    end
  end
end
