require 'rails_helper'

RSpec.describe "Company Profiles, Claims & Domain Matching", type: :request do
  let(:state) { State.find_by(acronym: 'SP') || State.create!(acronym: 'SP', name: 'São Paulo', slug: 'sp') }
  let(:city) { City.find_by(slug: 'guaratingueta', state: state) || City.create!(state: state, name: 'Guaratinguetá', slug: 'guaratingueta', ibge_code: '3518404') }
  let(:neighborhood) { Neighborhood.find_by(slug: 'centro', city: city) || Neighborhood.create!(city: city, name: 'Centro', slug: 'centro') }
  let!(:company) do
    Company.create!(
      state: state, city: city, neighborhood: neighborhood,
      cnpj: '11222333000199', legal_name: 'Oficina Trevo LTDA', trade_name: 'Oficina Trevo',
      email: 'contato@oficinatrevo.com.br', cnae_principal: '4520-0/01', status: 'Ativa'
    )
  end

  let(:client_user) do
    User.create!(
      email: "cliente@gmail.com",
      password: "password",
      password_confirmation: "password",
      role: "client",
      terms_accepted: "1",
      confirmed_at: Time.current
    )
  end

  describe "GET /reivindicar" do
    it "renders the claim page" do
      get new_claim_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Reivindicar Perfil de Empresa")
    end

    it "searches for unclaimed companies by name" do
      get new_claim_path(q: "Trevo")
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Oficina Trevo")
    end

    it "searches for unclaimed companies by CNPJ" do
      get new_claim_path(q: "11.222.333/0001-99")
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Oficina Trevo")
    end

    it "allows user with role company but no company attached to access claim page" do
      client_user.update!(role: "company")
      login_as(client_user)

      get new_claim_path
      expect(response).to have_http_status(:success)
    end

    it "redirects user with attached company away from claim page" do
      client_user.update!(role: "company")
      company.update!(user: client_user)
      login_as(client_user)

      get new_claim_path
      expect(response).to redirect_to(app_root_path)
    end

    it "renders Reivindicar Empresa button in layout for company users without attached company" do
      client_user.update!(role: "company")
      login_as(client_user)

      get root_path
      expect(response.body).to include("Reivindicar Empresa")
    end
  end

  describe "Domain auto-association on email confirmation" do
    it "automatically links user to company if domain matches custom corporate email" do
      user = User.create!(
        email: "joao@oficinatrevo.com.br",
        password: "password",
        password_confirmation: "password",
        role: "client",
        terms_accepted: "1"
      )

      user.confirm
      expect(user.reload.role).to eq("company")
      expect(user.company).to eq(company)
      expect(company.reload.is_claimed).to be_truthy
      expect(company.claim_status).to eq("approved")
    end
  end

  describe "POST /app/companies/:id/claim" do
    it "allows logged in user to claim an unclaimed company profile and redirects to verify" do
      login_as(client_user)
      post claim_app_company_path(company)

      expect(response).to redirect_to(verify_app_company_path(company))
      expect(company.reload.user).to eq(client_user)
      expect(client_user.reload.role).to eq("company")
      expect(company.claim_status).to eq("pending")
    end

    it "automatically links an existing unclaimed company when user creates with that CNPJ" do
      login_as(client_user)

      post app_companies_path, params: {
        company: {
          cnpj: company.cnpj,
          trade_name: "Novo Nome Oficina",
          phone_1: "(11) 97777-6666",
          phone_1_whatsapp: "1"
        }
      }

      expect(response).to redirect_to(verify_app_company_path(company))
      expect(company.reload.user).to eq(client_user)
      expect(company.phone_1).to eq("(11) 97777-6666")
      expect(company.claim_status).to eq("pending")
      expect(client_user.reload.role).to eq("company")
    end

    it "blocks access to edit page if company is not approved" do
      company.update!(user: client_user, claim_status: :pending)
      login_as(client_user)

      get edit_app_company_path(company)
      expect(response).to redirect_to(verify_app_company_path(company))
    end

    it "allows access to edit page once company is approved" do
      company.update!(user: client_user, claim_status: :approved)
      login_as(client_user)

      get edit_app_company_path(company)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /remover-perfil/:company_id" do
    it "creates an LGPD removal request for a company" do
      post removals_path(company_id: company.id), params: {
        name: "João Silva",
        email: "joao@pousadatrevo.com.br",
        reason: "Solicitação LGPD"
      }

      expect(response).to redirect_to(root_path)
      expect(company.reload.removal_requested).to be_truthy
      expect(company.removal_request_name).to eq("João Silva")
      expect(company.removal_request_email).to eq("joao@pousadatrevo.com.br")
    end
  end

  describe "DELETE /app/companies/:id/soft_delete (LGPD Deletion)" do
    it "requires EXCLUIR confirmation and soft-deletes company and destroys user" do
      company.update!(user: client_user, claim_status: :approved)
      login_as(client_user)

      delete soft_delete_app_company_path(company), params: { confirm_text: "EXCLUIR" }

      expect(response).to redirect_to(root_path)
      expect(company.reload.deleted_at).to be_present
      expect(User.exists?(client_user.id)).to be_falsey
    end
  end
end
