require 'rails_helper'

RSpec.describe "Contacts", type: :request do
  describe "GET /contato" do
    it "renders the contact form successfully" do
      get contact_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Contato")
      expect(response.body).to include("Atendimento Rápido")
    end
  end

  describe "POST /contato" do
    context "with valid parameters" do
      let(:valid_params) do
        {
          contact: {
            name: "John Doe",
            email: "john@example.com",
            subject: "Help",
            message: "I need help with my page."
          }
        }
      end

      it "creates a new Contact" do
        expect {
          post contacts_path, params: valid_params
        }.to change(Contact, :count).by(1)
      end

      it "redirects to the contact page with a success message" do
        post contacts_path, params: valid_params
        expect(response).to redirect_to(contact_path)
        follow_redirect!
        expect(response.body).to include("Sua mensagem foi enviada com sucesso! Entraremos em contato em breve.")
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          contact: {
            name: "",
            email: "invalid-email",
            subject: "",
            message: ""
          }
        }
      end

      it "does not create a new Contact" do
        expect {
          post contacts_path, params: invalid_params
        }.not_to change(Contact, :count)
      end

      it "renders the new template with unprocessable_entity status" do
        post contacts_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Por favor, corrija os erros abaixo:")
      end
    end
  end
end
