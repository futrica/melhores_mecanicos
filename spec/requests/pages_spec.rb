# spec/requests/pages_spec.rb
require 'rails_helper'

RSpec.describe "SEO Pages", type: :request do
  # Retrieve preloaded fixtures or create inline
  let!(:state) { State.find_by(acronym: 'SP') || State.create!(acronym: 'SP', name: 'São Paulo') }
  let!(:city) { City.find_by(slug: 'guaratingueta', state: state) || City.create!(state: state, name: 'Guaratinguetá', ibge_code: '3518404') }
  let!(:neighborhood) { Neighborhood.find_by(slug: 'centro', city: city) || Neighborhood.create!(city: city, name: 'Centro') }

  # Fetch preloaded fixture
  let!(:company) { Company.find_by!(cnpj: '12345678000101') }

  describe "GET /" do
    it "renders the home page successfully with categories and no CNAE badge" do
      get root_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Melhores Mecânicos")
      expect(response.body).to include("São Paulo")
      expect(response.body).to include("SERVIÇOS DE FREIOS")
      expect(response.body).not_to include("CNAE 5510-8/01")
    end
  end

  describe "GET /:state_slug/:city_slug" do
    it "renders the city listing page successfully with categories and no CNAE" do
      expect {
        get city_page_path(state_slug: state.slug, city_slug: city.slug)
      }.to have_enqueued_job(TrackMetricJob).at_least(:once)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Oficinas Mecânicas em Guaratinguetá")
      expect(response.body).to include("Auto Mecânica do Zé")
      expect(response.body).to include("Mecânica Geral")
      expect(response.body).not_to include("CNAE 4520-0/01")
    end

    it "paginates the companies listing when there are more than 15 companies" do
      1.upto(20) do |i|
        Company.create!(
          cnpj: "%014d" % (10000000000000 + i),
          legal_name: "Legal Name #{i} Ltda",
          trade_name: "Store Number #{i}",
          slug: "store-number-#{i}",
          cnae_principal: "4520-0/01",
          status: "Ativa",
          street: "Rua Teste #{i}",
          number: i.to_s,
          zip_code: "12501-000",
          phone_1: "(12) 3122-000#{i}",
          email: "test#{i}@example.com",
          latitude: 1.5,
          longitude: 1.5,
          state: state,
          city: city,
          neighborhood: neighborhood
        )
      end

      get city_page_path(state_slug: state.slug, city_slug: city.slug)
      expect(response).to have_http_status(:success)
      expect(response.body.scan("Store Number").length).to be <= 15
      expect(response.body).to include("class=\"pagy series-nav\"")
      expect(response.body).to include("page=2")

      get city_page_path(state_slug: state.slug, city_slug: city.slug, page: 2)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("page=1")
    end
  end

  describe "GET /:state_slug/:city_slug/:neighborhood_slug" do
    it "renders the neighborhood filtered page successfully with categories and no CNAE" do
      expect {
        get neighborhood_page_path(state_slug: state.slug, city_slug: city.slug, neighborhood_slug: neighborhood.slug)
      }.to have_enqueued_job(TrackMetricJob).at_least(:once)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Oficinas Mecânicas no Centro em Guaratinguetá")
      expect(response.body).to include("Auto Mecânica do Zé")
      expect(response.body).to include("Mecânica Geral")
      expect(response.body).not_to include("CNAE 4520-0/01")
    end

    it "paginates the neighborhood companies listing when there are more than 15 companies" do
      1.upto(20) do |i|
        Company.create!(
          cnpj: "%014d" % (20000000000000 + i),
          legal_name: "Legal Name N #{i} Ltda",
          trade_name: "N Store Number #{i}",
          slug: "n-store-number-#{i}",
          cnae_principal: "4520-0/01",
          status: "Ativa",
          street: "Rua Teste N #{i}",
          number: i.to_s,
          zip_code: "12501-000",
          phone_1: "(12) 3122-100#{i}",
          email: "testn#{i}@example.com",
          latitude: 1.5,
          longitude: 1.5,
          state: state,
          city: city,
          neighborhood: neighborhood
        )
      end

      get neighborhood_page_path(state_slug: state.slug, city_slug: city.slug, neighborhood_slug: neighborhood.slug)
      expect(response).to have_http_status(:success)
      expect(response.body.scan("N Store Number").length).to be <= 15
      expect(response.body).to include("class=\"pagy series-nav\"")
      expect(response.body).to include("page=2")

      get neighborhood_page_path(state_slug: state.slug, city_slug: city.slug, neighborhood_slug: neighborhood.slug, page: 2)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("page=1")
    end
  end

  describe "GET /:state_slug/:city_slug/:neighborhood_slug/:slug" do
    it "renders the company details page successfully with both categories and CNAE" do
      expect {
        get company_page_path(
          state_slug: company.state.slug,
          city_slug: company.city.slug,
          neighborhood_slug: company.neighborhood&.slug || 'centro',
          slug: company.slug
        )
      }.to have_enqueued_job(TrackMetricJob).at_least(:once)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Auto Mecânica do Zé")
      expect(response.body).to include("12345678000101")
      expect(response.body).to include("4520-0/01")
      expect(response.body).to include("Mecânica Geral")
    end
  end

  describe "Institutional Pages" do
    it "renders the about page successfully" do
      get about_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Quem Somos")
      expect(response.body).to include("Por que criamos o")
      expect(response.body).to include("Intermediários")
    end

    it "renders the terms of use page successfully" do
      get terms_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Termos de Uso")
    end

    it "renders the privacy policy page successfully" do
      get privacy_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Política de Privacidade")
    end

    it "renders the contact page successfully" do
      get contact_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Contato")
    end
  end
end
