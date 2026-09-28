require 'rails_helper'

RSpec.describe "Unsubscribes", type: :request do
  let!(:opt_out) { CompanyEmailOptOut.create!(email: "cliente@teste.com.br") }

  describe "GET /descadastrar/:token" do
    it "renders the opt-out reason selection form" do
      get unsubscribe_path(token: opt_out.token)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Descadastramento de E-mails")
      expect(response.body).to include(opt_out.email)
    end
  end

  describe "POST /descadastrar/:token" do
    it "updates the opt-out record with reason and feedback" do
      post unsubscribe_path(token: opt_out.token), params: {
        reason: "not_interested",
        feedback: "Não tenho interesse em divulgacão"
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Descadastramento Confirmado")

      opt_out.reload
      expect(opt_out.reason).to eq("not_interested")
      expect(opt_out.feedback).to eq("Não tenho interesse em divulgacão")
      expect(opt_out.unsubscribed_at).to be_present
    end
  end
end
