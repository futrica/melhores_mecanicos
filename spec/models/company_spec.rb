# spec/models/company_spec.rb
require 'rails_helper'

RSpec.describe Company, type: :model do
  # Reuse preloaded fixtures or fallback to create
  let(:state) { State.find_by(acronym: 'SP') || State.create!(acronym: 'SP', name: 'São Paulo') }
  let(:city) { City.find_by(slug: 'guaratingueta', state: state) || City.create!(state: state, name: 'Guaratinguetá', ibge_code: '3518404') }
  let(:neighborhood) { Neighborhood.find_by(slug: 'centro', city: city) || Neighborhood.create!(city: city, name: 'Centro') }

  describe 'validations' do
    it 'is valid with all required fields' do
      company = Company.new(
        state: state,
        city: city,
        neighborhood: neighborhood,
        cnpj: '55443322000111', # unique CNPJ
        legal_name: 'Nova Loja Ltda',
        trade_name: 'Nova Loja',
        cnae_principal: '5510801',
        status: 'Ativa'
      )
      expect(company).to be_valid
    end

    it 'is invalid without a cnpj' do
      company = Company.new(cnpj: nil)
      expect(company).not_to be_valid
      expect(company.errors[:cnpj]).to be_present
    end

    it 'enforces uniqueness of cnpj' do
      # CNPJ '12345678000101' is already preloaded by the companies.yml fixture
      duplicate = Company.new(
        state: state,
        city: city,
        cnpj: '12345678000101',
        legal_name: 'Mais Um Depósito',
        cnae_principal: '5510801',
        status: 'Ativa'
      )
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:cnpj]).to be_present
    end
  end

  describe 'plan methods' do
    it 'defaults to free plan' do
      company = Company.new
      expect(company.free_plan?).to be true
      expect(company.premium?).to be false
    end

    it 'returns true for premium? when plan is premium' do
      premium_company = Company.new(plan: 'premium')
      expect(premium_company.premium?).to be true
      expect(premium_company.free_plan?).to be false
    end
  end

  describe 'callbacks' do
    it 'automatically generates a slug on creation' do
      company = Company.create!(
        state: state,
        city: city,
        cnpj: '11998877000122',
        legal_name: 'Pedregulho Novo Eireli',
        trade_name: 'Pedregulho Novo',
        cnae_principal: '4744001',
        status: 'Ativa'
      )
      expect(company.slug).to eq('pedregulho-novo-11998877000122')
    end

    it 'uses legal_name for slug if trade_name is blank' do
      company = Company.create!(
        state: state,
        city: city,
        cnpj: '22887766000133',
        legal_name: 'Sem Nome Fantasia S/A',
        trade_name: '',
        cnae_principal: '4744001',
        status: 'Ativa'
      )
      expect(company.slug).to eq('sem-nome-fantasia-s-a-22887766000133')
    end
  end

  describe 'categories association' do
    it 'can have multiple associated Category records' do
      cat1 = Category.find_by(slug: 'hoteis-e-pousadas') || Category.create!(name: 'Hotéis e Pousadas', slug: 'hoteis-e-pousadas')
      cat2 = Category.find_by(slug: 'apart-hoteis') || Category.create!(name: 'Apart-hotéis', slug: 'apart-hoteis')

      company = Company.create!(
        state: state,
        city: city,
        cnpj: '99887766000155',
        legal_name: 'Loja Completa Ltda',
        cnae_principal: '5510801',
        status: 'Ativa'
      )
      company.categories << cat1
      company.categories << cat2

      expect(company.categories).to contain_exactly(cat1, cat2)
    end
  end

  describe '.find_matching_company_for' do
    it 'finds company by exact email' do
      comp = Company.create!(
        state: state, city: city, cnpj: '88776655000101',
        legal_name: 'Exact Match Ltda', email: 'contato@exactpousada.com.br',
        cnae_principal: '5510801', status: 'Ativa'
      )
      match = Company.find_matching_company_for('contato@exactpousada.com.br')
      expect(match).to eq(comp)
    end

    it 'finds company by domain match if email domain is custom' do
      comp = Company.create!(
        state: state, city: city, cnpj: '88776655000102',
        legal_name: 'Domain Match Ltda', email: 'vendas@pousadadojoao.com.br',
        cnae_principal: '5510801', status: 'Ativa'
      )
      match = Company.find_matching_company_for('joao@pousadadojoao.com.br')
      expect(match).to eq(comp)
    end

    it 'ignores public domains like gmail.com for domain matching' do
      Company.create!(
        state: state, city: city, cnpj: '88776655000103',
        legal_name: 'Public Domain Ltda', email: 'vendas@gmail.com',
        cnae_principal: '5510801', status: 'Ativa'
      )
      match = Company.find_matching_company_for('joao@gmail.com')
      expect(match).to be_nil
    end
  end

  describe '.by_search_priority' do
    it 'prioritizes approved (verified) companies first before unclaimed/pending ones' do
      unclaimed_comp = Company.create!(
        state: state, city: city, cnpj: '88776655000188',
        legal_name: 'Unclaimed Pousada', claim_status: 'unclaimed',
        cnae_principal: '5510801', status: 'Ativa'
      )
      approved_comp = Company.create!(
        state: state, city: city, cnpj: '88776655000199',
        legal_name: 'Approved Pousada', claim_status: 'approved',
        cnae_principal: '5510801', status: 'Ativa'
      )

      results = Company.where(id: [ unclaimed_comp.id, approved_comp.id ]).by_search_priority
      expect(results.first).to eq(approved_comp)
      expect(results.second).to eq(unclaimed_comp)
    end
  end

  describe '.indexable scope and #indexable? method alignment' do
    it 'includes active lodging companies with valid >= 8 digit phones' do
      valid_comp = Company.create!(
        state: state, city: city, cnpj: '88776655000201',
        legal_name: 'Pousada Sol', phone_1: '(51) 82722347',
        cnae_principal: '5510801', status: 'Ativa'
      )
      expect(Company.indexable).to include(valid_comp)
      expect(valid_comp.indexable?).to be true
    end

    it 'excludes companies with malformed/short phones like (35) 0 and no email/partners' do
      invalid_comp = Company.create!(
        state: state, city: city, cnpj: '88776655000202',
        legal_name: 'Pousada Invalida', phone_1: '(35) 0',
        cnae_principal: '5510801', status: 'Ativa'
      )
      expect(Company.indexable).not_to include(invalid_comp)
      expect(invalid_comp.indexable?).to be false
    end
  end

  describe '#soft_delete!' do
    it 'sets deleted_at, resets user_id, claim_status, is_claimed, and removal_requested' do
      company = Company.create!(
        state: state, city: city, cnpj: '88776655000999',
        legal_name: 'Soft Delete Test Ltda', claim_status: 'pending',
        removal_requested: true, cnae_principal: '5510801', status: 'Ativa'
      )
      company.soft_delete!
      company.reload

      expect(company.deleted_at).to be_present
      expect(company.user_id).to be_nil
      expect(company.claim_status).to eq('unclaimed')
      expect(company.is_claimed).to be false
      expect(company.removal_requested).to be false
    end
  end
end
