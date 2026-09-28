require 'rails_helper'

RSpec.describe "Admin User Impersonation", type: :request do
  let!(:admin_user) do
    User.create!(
      email: "admin_impersonate@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "admin",
      terms_accepted: "1",
      confirmed_at: Time.current
    )
  end

  let!(:another_admin) do
    User.create!(
      email: "other_admin@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "admin",
      terms_accepted: "1",
      confirmed_at: Time.current
    )
  end

  let!(:client_user) do
    User.create!(
      email: "client_target@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "client",
      terms_accepted: "1",
      confirmed_at: Time.current
    )
  end

  let!(:company_user) do
    User.create!(
      email: "company_target@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "company",
      terms_accepted: "1",
      confirmed_at: Time.current
    )
  end

  describe "POST /app/admin/users/:id/impersonate" do
    context "when logged in as admin" do
      before { login_as(admin_user) }

      it "allows admin to impersonate a client user" do
        post impersonate_app_admin_user_path(client_user)

        expect(response).to redirect_to(app_root_path)
        follow_redirect!

        expect(response.body).to include("Modo Personificação Ativo")
        expect(response.body).to include("Client Target")
        expect(response.body).to include("admin_impersonate@example.com")
      end

      it "allows admin to impersonate a company user" do
        post impersonate_app_admin_user_path(company_user)

        expect(response).to redirect_to(app_root_path)
        follow_redirect!

        expect(response.body).to include("Modo Personificação Ativo")
        expect(response.body).to include("Company Target")
        expect(response.body).to include("admin_impersonate@example.com")
      end

      it "prevents admin from impersonating another admin" do
        post impersonate_app_admin_user_path(another_admin)

        expect(response).to redirect_to(app_admin_users_path)
        follow_redirect!
        expect(response.body).to include("Não é permitido personificar outros administradores")
        expect(response.body).not_to include("Modo Personificação Ativo")
      end
    end

    context "when logged in as non-admin" do
      before { login_as(client_user) }

      it "redirects non-admin away" do
        post impersonate_app_admin_user_path(company_user)

        expect(response).to redirect_to(app_root_path)
        follow_redirect!
        expect(response.body).not_to include("Modo Personificação Ativo")
      end
    end
  end

  describe "POST /app/stop_impersonating" do
    context "when impersonating" do
      before do
        login_as(admin_user)
        post impersonate_app_admin_user_path(company_user)
      end

      it "stops impersonating and restores admin session" do
        post app_stop_impersonating_path

        expect(response).to redirect_to(app_admin_users_path)
        follow_redirect!

        expect(response.body).to include("Você saiu do modo de personificação")
        expect(response.body).not_to include("Modo Personificação Ativo")
        expect(response.body).to include("Admin Impersonate")
      end
    end

    context "when not impersonating" do
      before { login_as(client_user) }

      it "redirects to root with alert" do
        post app_stop_impersonating_path

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("Você não está no modo de personificação")
      end
    end
  end

  describe "UI Impersonation Banner" do
    it "renders the impersonation banner on all pages when impersonating" do
      login_as(admin_user)
      post impersonate_app_admin_user_path(company_user)

      get app_root_path
      expect(response.body).to include("Modo Personificação Ativo")
      expect(response.body).to include("Company Target")
      expect(response.body).to include("Sair da Personificação")

      get root_path
      expect(response.body).to include("Modo Personificação Ativo")
      expect(response.body).to include("Company Target")
    end
  end
end
