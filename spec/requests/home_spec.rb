require 'rails_helper'

RSpec.describe "HomeController", type: :request do
  describe "GET /" do
    let!(:state) { State.find_or_create_by!(acronym: "SP") { |s| s.name = "São Paulo"; s.slug = "sp" } }
    let!(:city) { City.find_or_create_by!(slug: "sao-paulo", state: state) { |c| c.name = "São Paulo"; c.ibge_code = "3550308" } }

    it "returns HTTP success and renders featured companies" do
      company = Company.create!(
        legal_name: "Pousada Teste Ltda",
        trade_name: "Pousada Teste",
        cnpj: "12345678000199",
        status: "ATIVA",
        cnae_principal: "5510-8/01",
        city: city,
        state: state
      )

      get "/"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Pousada Teste")
    end

    it "prioritizes claimed companies and rotates featured companies" do
      unclaimed = 10.times.map do |i|
        Company.create!(
          legal_name: "Unclaimed #{i} Ltda",
          trade_name: "Unclaimed #{i}",
          cnpj: "1000000000010#{i}",
          status: "ATIVA",
          cnae_principal: "5510-8/01",
          city: city,
          state: state,
          updated_at: Time.current - i.hours
        )
      end

      claimed = Company.create!(
        legal_name: "Claimed Pousada Ltda",
        trade_name: "Claimed Pousada",
        cnpj: "20000000000100",
        status: "ATIVA",
        cnae_principal: "5510-8/01",
        city: city,
        state: state,
        is_claimed: true,
        claim_status: "approved",
        updated_at: Time.current
      )

      get "/"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Claimed Pousada")
    end
  end
end
