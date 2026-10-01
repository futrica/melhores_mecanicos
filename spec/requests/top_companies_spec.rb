require 'rails_helper'

RSpec.describe "Admin Top Companies & Outreach", type: :request do
  let!(:state) { State.find_by(acronym: 'SP') || State.create!(acronym: 'SP', name: 'São Paulo') }
  let!(:city) { City.find_by(slug: 'guaratingueta', state: state) || City.create!(state: state, name: 'Guaratinguetá', ibge_code: '3518404') }

  let!(:admin_user) do
    u = User.new(name: "Admin Geral", email: "admin_top@teste.com", password: "password123", role: "admin", terms_accepted: "1")
    u.skip_confirmation!
    u.save!
    u
  end

  let!(:company_high_views) do
    Company.create!(
      trade_name: "Oficina Das Flores",
      legal_name: "Oficina Das Flores LTDA",
      cnpj: "11111111000199",
      email: "contato@oficinaflores.com.br",
      status: "ATIVA",
      cnae_principal: "4520-0/01",
      city: city,
      state: state,
      views_count: 100
    )
  end

  let!(:company_opted_out) do
    comp = Company.create!(
      trade_name: "Oficina Recusada",
      legal_name: "Oficina Recusada LTDA",
      cnpj: "33333333000177",
      email: "recusado@oficina.com.br",
      status: "ATIVA",
      cnae_principal: "4520-0/01",
      city: city,
      state: state,
      views_count: 50
    )
    CompanyEmailOptOut.create!(
      company: comp,
      email: "recusado@oficina.com.br",
      reason: "not_interested",
      feedback: "Não quero receber e-mails de propaganda"
    )
    comp
  end

  def login_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end

  before { login_as(admin_user) }

  describe "GET /app/admin/top_companies" do
    it "renders the top companies listing sorted by views" do
      get app_admin_top_companies_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Empresas Mais Acessadas")
      expect(response.body).to include("Oficina Das Flores")
      expect(response.body).to include("100")
      expect(response.body).to include("Guaratinguetá / SP")
    end

    it "filters by email_status" do
      get app_admin_top_companies_path(email_status: "not_sent")
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Oficina Das Flores")
    end
  end

  describe "GET /app/admin/top_companies/:id" do
    it "renders company details and outreach history" do
      get app_admin_top_company_path(company_high_views)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Oficina Das Flores")
      expect(response.body).to include("Histórico de E-mails Enviados")
    end

    it "disables email button and shows opt-out reason when company opted out" do
      get app_admin_top_company_path(company_opted_out)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Recusado pelo Destinatário (Opt-Out / Spam)")
      expect(response.body).to include("Não quero receber e-mails de propaganda")
      expect(response.body).to include("Disparo de E-mail Desativado")
    end
  end

  describe "POST /app/admin/top_companies/:id/send_email" do
    it "dispatches outreach email using CompanyOutreachService" do
      allow(EmailValidatorService).to receive(:valid_format?).and_return(true)
      allow(EmailValidatorService).to receive(:has_valid_mx?).and_return(true)

      expect {
        post send_email_app_admin_top_company_path(company_high_views)
      }.to change { CompanyOutreachLog.count }.by(1)

      expect(response).to redirect_to(app_admin_top_company_path(company_high_views))
      follow_redirect!
      expect(response.body).to include("E-mail de apresentação enviado com sucesso")
    end
  end

  describe "DevelopmentMailInterceptor" do
    it "intercepts development email and overrides recipient to jmfutrica@gmail.com" do
      allow(Rails.env).to receive(:development?).and_return(true)
      mail = OutreachMailer.profile_presentation(company_high_views, "token123")
      DevelopmentMailInterceptor.delivering_email(mail) if defined?(DevelopmentMailInterceptor)

      expect(mail.to).to eq([ "jmfutrica@gmail.com" ])
      expect(mail.subject).to include("[DEV -> contato@oficinaflores.com.br]")
    end
  end
end
