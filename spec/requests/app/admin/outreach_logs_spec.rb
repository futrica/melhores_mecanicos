require 'rails_helper'

RSpec.describe "App::Admin::OutreachLogs", type: :request do
  let!(:admin_user) { User.create!(email: "admin@teste.com", password: "password123", role: "admin", terms_accepted: "1") }
  let!(:regular_user) { User.create!(email: "user@teste.com", password: "password123", role: "client", terms_accepted: "1") }

  describe "GET /app/admin/outreach_logs" do
    context "when logged in as admin" do
      before do
        sign_in admin_user
      end

      it "returns http success and renders outreach logs dashboard" do
        CompanyEmailOptOut.create!(email: "enviado@teste.com", token: "token123", unsubscribed_at: nil)
        CompanyEmailOptOut.create!(email: "optout@teste.com", token: "token456", unsubscribed_at: Time.current, reason: "not_interested")

        get app_admin_outreach_logs_path(status: "opt_out")
        expect(response).to have_http_status(:success)
        expect(response.body).to include("E-mails de Apresentação de Empresas")
        expect(response.body).to include("optout@teste.com")
        expect(response.body).not_to include("enviado@teste.com")
      end
    end

    context "when logged in as non-admin user" do
      before do
        sign_in regular_user
      end

      it "redirects or denies access" do
        get app_admin_outreach_logs_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when not logged in" do
      it "redirects to login page" do
        get app_admin_outreach_logs_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
