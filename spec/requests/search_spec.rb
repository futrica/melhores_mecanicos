# spec/requests/search_spec.rb
require 'rails_helper'

RSpec.describe "Search and Autocomplete APIs", type: :request do
  let!(:state) { State.find_by(acronym: 'SP') || State.create!(acronym: 'SP', name: 'São Paulo') }
  let!(:city) { City.find_by(slug: 'guaratingueta', state: state) || City.create!(state: state, name: 'Guaratinguetá', ibge_code: '3518404') }
  let!(:neighborhood) { Neighborhood.find_by(slug: 'centro', city: city) || Neighborhood.create!(city: city, name: 'Centro') }
  let!(:company) { Company.find_by!(cnpj: '12345678000101') }
  let!(:category) { Category.find_by(name: 'Hotéis e Pousadas') || Category.create!(name: 'Hotéis e Pousadas') }

  before do
    company.categories << category unless company.categories.include?(category)
  end

  describe "GET /busca" do
    it "renders the search results page successfully" do
      get search_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Resultados da Busca")
      expect(response.body).to include("Selecione um Estado")
    end

    it "filters results by state" do
      get search_path(state_id: state.id)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Hospedagens em São Paulo")
      expect(response.body).to include("Pousada do Zé")
    end

    it "filters results by category" do
      get search_path(state_id: state.id, category: "hoteis")
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Pousada do Zé")
    end

    it "returns no results for mismatching query term" do
      get search_path(state_id: state.id, q: "NonexistentStoreNameHere")
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Nenhum resultado encontrado")
    end

    it "filters by only_phone status" do
      # Company has phone_1 loaded in fixtures
      get search_path(state_id: state.id, only_phone: "1")
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Pousada do Zé")
    end

    it "filters by only_email status" do
      # Company has email loaded in fixtures
      get search_path(state_id: state.id, only_email: "1")
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Pousada do Zé")
    end

    it "filters by multiple neighborhood ids and tracks searches_count" do
      expect {
        get search_path(state_id: state.id, neighborhood_ids: [ neighborhood.id ])
      }.to have_enqueued_job(TrackMetricJob).at_least(:once)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Pousada do Zé")
    end

    it "filters by city_ids and tracks searches_count" do
      expect {
        get search_path(state_id: state.id, city_ids: [ city.id ])
      }.to have_enqueued_job(TrackMetricJob).at_least(:once)
      expect(response).to have_http_status(:success)
    end

    it "filters by neighborhood_id and tracks searches_count" do
      expect {
        get search_path(state_id: state.id, neighborhood_id: neighborhood.id)
      }.to have_enqueued_job(TrackMetricJob).at_least(:once)
      expect(response).to have_http_status(:success)
    end

    it "sorts results based on updated_at descending" do
      # Create another company with newer updated_at
      newer_company = Company.create!(
        cnpj: "99999999000199",
        legal_name: "Newer Store Ltda",
        trade_name: "Newer Store",
        slug: "newer-store-99999999000199",
        cnae_principal: "5510-8/01",
        status: "Ativa",
        street: "Rua Nova",
        number: "10",
        zip_code: "12501-000",
        phone_1: "(12) 3333-4444",
        email: "newer@example.com",
        latitude: 1.5,
        longitude: 1.5,
        state: state,
        city: city,
        neighborhood: neighborhood,
        updated_at: Time.current + 1.hour
      )

      # Newer store should appear before Pousada do Zé
      get search_path(state_id: state.id)
      expect(response).to have_http_status(:success)

      # Newer store appears first in body
      newer_index = response.body.index("Newer Store")
      ze_index = response.body.index("Pousada do Zé")

      expect(newer_index).to be < ze_index
    end

    it "throttles /busca requests after 50 requests in a minute from the same IP" do
      Rack::Attack.cache.store.clear
      50.times do
        get search_path
        expect(response).to have_http_status(:success)
      end

      get search_path
      expect(response).to have_http_status(429)
      expect(response.body).to include("429 - Limite de Buscas Excedido")
    end
  end

  describe "GET /api/cities" do
    it "returns JSON list of cities in state with companies" do
      get "/api/cities", params: { state_id: state.id }
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("application/json")

      json_response = JSON.parse(response.body)
      expect(json_response).to be_an(Array)
      expect(json_response.map { |c| c["name"] }).to include("Guaratinguetá")
    end

    it "returns empty array for invalid state_id" do
      get "/api/cities", params: { state_id: 99999 }
      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response).to eq([])
    end
  end

  describe "GET /api/neighborhoods" do
    it "returns JSON list of neighborhoods in selected cities" do
      get "/api/neighborhoods", params: { city_ids: [ city.id ] }
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("application/json")

      json_response = JSON.parse(response.body)
      expect(json_response).to be_an(Array)
      expect(json_response.first["name"]).to eq("Centro")
    end

    it "returns empty array when city_ids is missing" do
      get "/api/neighborhoods"
      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response).to eq([])
    end
  end
end
