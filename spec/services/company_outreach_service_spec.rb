require 'rails_helper'

RSpec.describe CompanyOutreachService, type: :service do
  let!(:state) { State.find_by(acronym: 'SP') || State.create!(acronym: 'SP', name: 'São Paulo') }
  let!(:city) { City.find_by(slug: 'sao-paulo', state: state) || City.create!(state: state, name: 'São Paulo', ibge_code: '3550308') }

  let!(:eligible_company) do
    Company.create!(
      trade_name: 'Pousada Exemplo 1',
      legal_name: 'Pousada Exemplo 1 LTDA',
      cnpj: '11.111.111/0001-11',
      email: 'contato@pousada1.com.br',
      views_count: 15,
      claim_status: :unclaimed,
      status: 'ATIVA',
      cnae_principal: '5510801',
      state: state,
      city: city
    )
  end

  let!(:claimed_company) do
    Company.create!(
      trade_name: 'Pousada Reivindicada',
      legal_name: 'Pousada Reivindicada LTDA',
      cnpj: '22.222.222/0001-22',
      email: 'contato@pousadaclaimed.com.br',
      views_count: 20,
      claim_status: :approved,
      is_claimed: true,
      status: 'ATIVA',
      cnae_principal: '5510801',
      state: state,
      city: city
    )
  end

  before do
    EmailValidatorService.clear_cache!
    allow(EmailValidatorService).to receive(:valid_email?).and_return(true)
    allow(EmailValidatorService).to receive(:valid_format?).and_return(true)
    allow(EmailValidatorService).to receive(:has_valid_mx?).and_return(true)
  end

  it 'sends emails only to unclaimed eligible companies in dry_run=false mode' do
    service = CompanyOutreachService.new(limit: 10, min_views: 10, dry_run: false, sleep_seconds: 0)

    expect {
      results = service.perform
      expect(results[:sent]).to eq(1)
    }.to change { CompanyOutreachLog.count }.by(1)

    log = CompanyOutreachLog.last
    expect(log.company).to eq(eligible_company)
    expect(log.email).to eq('contato@pousada1.com.br')
    expect(log.status).to eq('sent')
  end

  it 'does not send emails in dry_run=true mode but returns simulated metrics' do
    service = CompanyOutreachService.new(limit: 10, min_views: 10, dry_run: true, sleep_seconds: 0)

    expect {
      results = service.perform
      expect(results[:sent]).to eq(1)
    }.not_to change { CompanyOutreachLog.count }
  end

  it 'skips companies that have opted out' do
    CompanyEmailOptOut.create!(email: 'contato@pousada1.com.br', reason: 'not_interested')

    service = CompanyOutreachService.new(limit: 10, min_views: 10, dry_run: false, sleep_seconds: 0)
    results = service.perform

    expect(results[:sent]).to eq(0)
    expect(results[:skipped_opt_out]).to eq(1)
  end

  it 'skips companies sent recently within cooldown' do
    CompanyOutreachLog.create!(
      company: eligible_company,
      email: eligible_company.email,
      campaign_name: 'profile_presentation',
      sent_at: 5.days.ago,
      status: 'sent'
    )

    service = CompanyOutreachService.new(limit: 10, min_views: 10, cooldown_days: 60, dry_run: false, sleep_seconds: 0)
    results = service.perform

    expect(results[:sent]).to eq(0)
    expect(results[:skipped_recently_sent]).to eq(1)
  end

  it 'skips companies with UOL email domains (uol/bol/zipmail/folha)' do
    eligible_company.update!(email: 'pousada@uol.com.br')

    service = CompanyOutreachService.new(limit: 10, min_views: 10, dry_run: false, sleep_seconds: 0)
    results = service.perform

    expect(results[:sent]).to eq(0)
    expect(results[:skipped_uol_paused]).to eq(1)
  end

  it 'allows companies with Microsoft email domains (hotmail/outlook/live/msn) now that MS is released' do
    eligible_company.update!(email: 'pousada@hotmail.com')

    service = CompanyOutreachService.new(limit: 10, min_views: 10, dry_run: false, sleep_seconds: 0)
    results = service.perform

    expect(results[:sent]).to eq(1)
    expect(results[:skipped_uol_paused]).to eq(0)
  end
end
