require 'rails_helper'

RSpec.describe CompanySchemaMapper do
  let(:state) { State.find_by(acronym: 'SP') || State.create!(acronym: 'SP', name: 'São Paulo') }
  let(:city) { City.find_by(slug: 'sao-paulo', state: state) || City.create!(state: state, name: 'São Paulo', ibge_code: '3550308') }

  def build_company(cnae)
    Company.new(
      cnpj: '11222333000199',
      legal_name: 'Empresa Teste LTDA',
      trade_name: 'Empresa Teste',
      cnae_principal: cnae,
      status: 'Ativa',
      slug: 'empresa-teste',
      state: state,
      city: city,
      street: 'Rua Exemplo',
      number: '100',
      zip_code: '01000-000',
      phone_1: '(11) 99999-8888'
    )
  end

  describe '#schema_type' do
    it 'maps hotel CNAE to Hotel' do
      company = build_company('5510801')
      mapper = described_class.new(company)
      expect(mapper.schema_type).to eq('Hotel')
    end

    it 'maps hostel CNAE to Hostel' do
      company = build_company('5590601')
      mapper = described_class.new(company)
      expect(mapper.schema_type).to eq('Hostel')
    end

    it 'maps pharmacy CNAE to Pharmacy' do
      company = build_company('4771701')
      mapper = described_class.new(company)
      expect(mapper.schema_type).to eq('Pharmacy')
    end

    it 'maps restaurant CNAE to Restaurant' do
      company = build_company('5611201')
      mapper = described_class.new(company)
      expect(mapper.schema_type).to eq('Restaurant')
    end

    it 'defaults unknown CNAE to LocalBusiness' do
      company = build_company('9999999')
      mapper = described_class.new(company)
      expect(mapper.schema_type).to eq('LocalBusiness')
    end
  end

  describe '#to_schema_hash' do
    it 'returns valid JSON-LD schema structure' do
      company = build_company('5510801')
      mapper = described_class.new(company, base_url: 'https://hospedagemdireta.com.br')
      hash = mapper.to_schema_hash

      expect(hash['@context']).to eq('https://schema.org')
      expect(hash['@type']).to eq('Hotel')
      expect(hash['name']).to eq('Empresa Teste')
      expect(hash['taxID']).to eq('11222333000199')
      expect(hash['address']['addressLocality']).to eq('São Paulo')
    end
  end
end
