require 'rails_helper'

RSpec.describe "Locations", type: :request do
  let!(:state) { State.find_by(acronym: 'SP') || State.create!(acronym: 'SP', name: 'São Paulo') }
  let!(:city) { City.find_by(slug: 'guaratingueta', state: state) || City.create!(state: state, name: 'Guaratinguetá', ibge_code: '3518404') }
  let!(:neighborhood) { Neighborhood.find_by(slug: 'centro', city: city) || Neighborhood.create!(city: city, name: 'Centro') }
  let!(:neighborhood2) { Neighborhood.create!(city: city, name: 'Vila Bella', slug: 'vila-bella') }
  let!(:company) { Company.find_by!(cnpj: '12345678000101') }

  describe "GET /:state_slug/:city_slug" do
    it "renders the city page successfully with search panel form" do
      get city_page_path(state_slug: state.slug, city_slug: city.slug)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Hospedagens em Guaratinguetá / SP")
      expect(response.body).to include("data-controller=\"search-form\"")
      expect(response.body).to include("Bairro")
    end

    it "filters companies by selected neighborhood_ids" do
      expect {
        get city_page_path(state_slug: state.slug, city_slug: city.slug, neighborhood_ids: [ neighborhood.id ])
      }.to have_enqueued_job(TrackMetricJob).at_least(:once)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Pousada do Zé")
    end

    it "sorts neighborhood names starting with numbers at the end of the list in API" do
      digit_neighborhood = Neighborhood.create!(city: city, name: '14 Distrito Lapa', slug: '14-distrito-lapa')
      Company.create!(
        cnpj: "11111111000111",
        legal_name: "Empresa Lapa Ltda",
        trade_name: "Empresa Lapa",
        slug: "empresa-lapa-11111111000111",
        cnae_principal: "5510-8/01",
        status: "Ativa",
        street: "Rua Lapa",
        number: "100",
        zip_code: "12500-000",
        state: state,
        city: city,
        neighborhood: digit_neighborhood
      )

      get "/api/neighborhoods?city_ids[]=#{city.id}"
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      names = json.map { |n| n["name"] }

      expect(names.last).to eq("14 Distrito Lapa")
    end
  end

  describe "GET /:state_slug" do
    it "renders the state page successfully displaying cities grid and companies" do
      get state_page_path(state_slug: state.slug)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Hospedagens em São Paulo (SP)")
      expect(response.body).to include("Guaratinguetá")
      expect(response.body).to include("Pousada do Zé")
    end

    it "returns HTTP 404 Not Found without redirect when state slug is invalid" do
      get "/invalid-state-slug-here"
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("The page you were looking for doesn't exist")
    end
  end
end
