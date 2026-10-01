require 'rails_helper'

RSpec.describe "Companies", type: :request do
  let!(:state) { State.find_by(acronym: 'SP') || State.create!(acronym: 'SP', name: 'São Paulo') }
  let!(:city) { City.find_by(slug: 'guaratingueta', state: state) || City.create!(state: state, name: 'Guaratinguetá', ibge_code: '3518404') }
  let!(:neighborhood) { Neighborhood.find_by(slug: 'centro', city: city) || Neighborhood.create!(city: city, name: 'Centro') }
  let!(:company) { Company.find_by!(cnpj: '12345678000101') }

  describe "GET company page" do
    it "renders the company page successfully when company exists" do
      get company_page_path(state_slug: state.slug, city_slug: city.slug, neighborhood_slug: neighborhood.slug, slug: company.slug)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Auto Mecânica do Zé")
    end

    it "returns HTTP 404 Not Found without redirect when company does not exist" do
      get company_page_path(state_slug: state.slug, city_slug: city.slug, neighborhood_slug: neighborhood.slug, slug: "nonexistent-company-slug")
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("The page you were looking for doesn't exist")
    end

    it "returns HTTP 410 Gone when company status is inactive (e.g. baixada)" do
      company.update!(status: "Baixada")
      get company_page_path(state_slug: state.slug, city_slug: city.slug, neighborhood_slug: neighborhood.slug, slug: company.slug)
      expect(response).to have_http_status(:gone)
    end


    it "includes optimized title, meta description, and Schema.org JSON-LD" do
      get company_page_path(state_slug: state.slug, city_slug: city.slug, neighborhood_slug: neighborhood.slug, slug: company.slug)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Orçamento Direto")
      expect(response.body).to include('"@type":"AutoRepair"')
    end
  end

  describe "301 Redirects for www domain" do
    it "redirects www.melhoresmecanicos.com.br to canonical domain with 301" do
      get "http://www.melhoresmecanicos.com.br/sp/guaratingueta"
      expect(response).to have_http_status(:moved_permanently)
      expect(response.redirect_url).to eq("https://melhoresmecanicos.com.br/sp/guaratingueta")
    end
  end

  describe "PATCH /app/companies/:id photo preservation" do
    let(:owner) { User.create!(email: "photo_owner@example.com", password: "password123", role: "company", confirmed_at: Time.current, terms_accepted: "1") }

    before do
      company.update!(user: owner, claim_status: :approved)
      company.photos.attach(
        io: StringIO.new("fake image content"),
        filename: "test.jpg",
        content_type: "image/jpeg"
      )
      login_as(owner, scope: :user)
    end

    it "preserves existing attached photos when updating other company fields" do
      expect(company.photos.count).to eq(1)

      patch app_company_path(company), params: {
        company: {
          trade_name: "Pousada Atualizada",
          description: "Nova descrição"
        }
      }

      expect(response).to redirect_to(app_root_path)
      company.reload
      expect(company.trade_name).to eq("Pousada Atualizada")
      expect(company.photos.count).to eq(1)
    end
  end
end
