require 'rails_helper'

RSpec.describe OutreachMailer, type: :mailer do
  let!(:state) { State.find_by(acronym: 'SP') || State.create!(acronym: 'SP', name: 'São Paulo') }
  let!(:city) { City.find_by(slug: 'guaratingueta', state: state) || City.create!(state: state, name: 'Guaratinguetá', ibge_code: '3518404') }
  let!(:company) do
    Company.create!(
      trade_name: 'Oficina Teste BCC',
      legal_name: 'Oficina Teste BCC LTDA',
      cnpj: '99.999.999/0001-99',
      email: 'oficina@teste.com.br',
      views_count: 50,
      status: 'ATIVA',
      cnae_principal: '4520-0/01',
      state: state,
      city: city
    )
  end

  describe '#profile_presentation' do
    let(:mail) { OutreachMailer.profile_presentation(company, 'token123') }

    it 'does not include BCC' do
      expect(mail.bcc).to be_nil.or be_empty
    end

    it 'sets recipient and subject correctly' do
      expect(mail.to).to eq([ 'oficina@teste.com.br' ])
      expect(mail.subject).to include('Oficina Teste BCC')
    end
  end
end
