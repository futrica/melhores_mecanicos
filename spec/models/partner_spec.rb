require 'rails_helper'

RSpec.describe Partner, type: :model do
  let(:state) { State.find_by(acronym: 'SP') || State.create!(acronym: 'SP', name: 'São Paulo') }
  let(:city) { City.find_by(slug: 'guaratingueta', state: state) || City.create!(state: state, name: 'Guaratinguetá', ibge_code: '3518404') }
  let(:company) do
    Company.create!(
      state: state,
      city: city,
      cnpj: '11223344000199',
      legal_name: 'Empresa Teste Ltda',
      cnae_principal: '5510801',
      status: 'Ativa'
    )
  end

  it 'creates a partner associated with a company' do
    partner = company.partners.create!(
      name: 'João da Silva',
      document: '***123456**',
      qualification: 'Sócio-Administrador',
      person_type: 'Pessoa Física',
      age_range: '41 a 50 anos'
    )

    expect(partner).to be_persisted
    expect(partner.company).to eq(company)
    expect(company.partners).to include(partner)
  end
end
