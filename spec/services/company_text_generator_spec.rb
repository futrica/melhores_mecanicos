require 'rails_helper'

RSpec.describe CompanyTextGenerator do
  let(:state) { State.find_or_create_by!(acronym: "SP") { |s| s.name = "São Paulo" } }
  let(:city) { City.find_or_create_by!(ibge_code: "3518404", state: state) { |c| c.name = "Guaratinguetá" } }
  let(:neighborhood) { Neighborhood.find_or_create_by!(city: city, name: "Vila Bela") }

  let(:company) do
    Company.find_or_create_by!(cnpj: "12.476.090/0001-70") do |c|
      c.legal_name = "KARAJA CONSTRUCOES E LOCACOES LTDA"
      c.trade_name = "Karaja Construções"
      c.opening_date = Date.new(2010, 8, 30)
      c.cnae_principal = "42.11-1-01 - Construção de rodovias e ferrovias"
      c.status = "Ativa"
      c.company_size = "Sem Enquadramento"
      c.capital_social = 3_500_000.00
      c.street = "Rua Raul Pompeia"
      c.number = "439"
      c.zip_code = "12522-480"
      c.phone_1 = "(12) 3152-0000"
      c.state = state
      c.city = city
      c.neighborhood = neighborhood
    end
  end

  describe '#generate_about' do
    it 'returns a non-empty string containing key information about the company' do
      generator = described_class.new(company)
      about_text = generator.generate_about

      expect(about_text).to include("Karaja Construções")
      expect(about_text).to include("Guaratinguetá")
      expect(about_text).to include("SP")
      expect(about_text).to include("Ativa")
    end

    it 'is strictly deterministic for the same CNPJ' do
      text_1 = described_class.new(company).generate_about
      text_2 = described_class.new(company).generate_about

      expect(text_1).to eq(text_2)
    end
    it 'does not raise KeyError for any seed or template variation' do
      (1..100).each do |i|
        company.cnpj = "12.476.090/0001-#{format('%02d', i)}"
        expect { described_class.new(company).generate_about }.not_to raise_error
      end
    end

    it 'handles companies without opening_date without raising error across seeds' do
      company.opening_date = nil
      (1..100).each do |i|
        company.cnpj = "12.476.090/0002-#{format('%02d', i)}"
        expect { described_class.new(company).generate_about }.not_to raise_error
      end
    end
  end

  describe '#generate_faq' do
    it 'returns 10 structured question-answer pairs' do
      generator = described_class.new(company)
      faq = generator.generate_faq

      expect(faq.size).to eq(10)
      expect(faq.first).to have_key(:question)
      expect(faq.first).to have_key(:answer)
      expect(faq.first[:question]).to include("12.476.090/0001-70")
    end
  end
end
