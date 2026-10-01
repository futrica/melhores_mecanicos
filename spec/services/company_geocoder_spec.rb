require 'rails_helper'

RSpec.describe CompanyGeocoder do
  let(:state) { State.find_or_create_by!(acronym: "SP") { |s| s.name = "São Paulo" } }
  let(:city) { City.find_or_create_by!(ibge_code: "3550308", state: state) { |c| c.name = "São Paulo" } }
  let(:company) do
    Company.find_or_create_by!(cnpj: "01.001.000/0001-00") do |c|
      c.legal_name = "EMPRESA TESTE GEOCODE"
      c.trade_name = "Teste Geocode"
      c.zip_code = "01001-000"
      c.street = "Praça da Sé"
      c.number = "1"
      c.cnae_principal = "4520-0/01"
      c.status = "Ativa"
      c.state = state
      c.city = city
    end
  end

  describe '.geocode' do
    it 'returns existing coordinates if already present' do
      company.update_columns(latitude: -23.55052, longitude: -46.633308)

      coords = described_class.geocode(company)
      expect(coords.first(2)).to eq([ -23.55052, -46.633308 ])
    end

    it 'fetches coordinates and updates company columns if nil' do
      company.update_columns(latitude: nil, longitude: nil)

      coords = described_class.geocode(company)
      company.reload

      if coords.present?
        expect(company.latitude).to be_present
        expect(company.longitude).to be_present
      end
    end
  end
end
