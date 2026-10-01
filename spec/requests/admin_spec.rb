require 'rails_helper'

RSpec.describe "Admin Profile and Dashboard", type: :request do
  let!(:state) { State.find_by(acronym: 'SP') || State.create!(acronym: 'SP', name: 'São Paulo') }
  let!(:city) { City.find_by(slug: 'guaratingueta', state: state) || City.create!(state: state, name: 'Guaratinguetá', ibge_code: '3518404') }

  let!(:client_user) do
    u = User.new(name: "Cliente Comum", email: "cliente@teste.com", password: "password123", role: "client", terms_accepted: "1")
    u.skip_confirmation!
    u.save!
    u
  end

  let!(:admin_user) do
    u = User.new(name: "Admin Geral", email: "admin@teste.com", password: "password123", role: "admin", terms_accepted: "1")
    u.skip_confirmation!
    u.save!
    u
  end

  let!(:contact) do
    Contact.create!(name: "Maria Santos", email: "maria@teste.com", subject: "Orçamento de Pedras", message: "Gostaria de tirar uma dúvida sobre entrega.")
  end

  def login_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end

  describe "Access Control" do
    it "redirects client user away from admin dashboard" do
      login_as(client_user)
      get app_admin_dashboard_path
      expect(response).to redirect_to(app_root_path)
      follow_redirect!
      expect(response.body).to include("Acesso restrito a administradores.")
    end

    it "redirects client user away from admin users list" do
      login_as(client_user)
      get app_admin_users_path
      expect(response).to redirect_to(app_root_path)
    end

    it "redirects admin user to /app/admin after login" do
      login_as(admin_user)
      get app_root_path
      expect(response).to redirect_to(app_admin_dashboard_path)
    end
  end

  describe "Admin Dashboard" do
    before { login_as(admin_user) }

    it "renders the dashboard index with total counts" do
      get app_admin_dashboard_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Painel de Administração")
      expect(response.body).to include("Usuários Cadastrados")
      expect(response.body).to include("Formulário de Contato")
    end
  end

  describe "Admin Users Management" do
    before { login_as(admin_user) }

    it "lists registered users" do
      get app_admin_users_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("cliente@teste.com")
      expect(response.body).to include("admin@teste.com")
    end

    it "filters users by role" do
      get app_admin_users_path(role: "client")
      expect(response).to have_http_status(:success)
      expect(response.body).to include("cliente@teste.com")
    end

    it "displays user detail page" do
      get app_admin_user_path(client_user)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Cliente Comum")
      expect(response.body).to include("cliente@teste.com")
    end
  end

  describe "Admin Contact Form Submissions Management" do
    before { login_as(admin_user) }

    it "lists contact form messages" do
      get app_admin_contacts_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Maria Santos")
      expect(response.body).to include("Orçamento de Pedras")
    end

    it "displays contact message detail page" do
      get app_admin_contact_path(contact)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Gostaria de tirar uma dúvida sobre entrega.")
    end
  end

  describe "Company Approval Email Trigger" do
    before { login_as(admin_user) }

    let!(:company) do
      Company.create!(
        state: state,
        city: city,
        cnpj: "11222333000199",
        legal_name: "Oficina Sol LTDA",
        trade_name: "Oficina Sol",
        email: "sol@oficina.com",
        cnae_principal: "4520-0/01",
        status: "Ativa",
        claim_status: :pending,
        user: client_user
      )
    end

    it "approves company profile and enqueues approval email with bcc" do
      expect {
        post app_approve_company_path(id: company.id)
      }.to have_enqueued_email(UserMailer, :company_approved)

      expect(company.reload.claim_status).to eq("approved")
    end
  end
end
