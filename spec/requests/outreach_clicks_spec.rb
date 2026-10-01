require 'rails_helper'

RSpec.describe "OutreachClicks", type: :request do
  let!(:state) { State.find_by(acronym: 'SP') || State.create!(acronym: 'SP', name: 'São Paulo') }
  let!(:city) { City.find_by(slug: 'ubatuba', state: state) || City.create!(state: state, name: 'Ubatuba', ibge_code: '3555406') }

  let!(:company) do
    Company.create!(
      trade_name: 'Oficina Auto Mar',
      legal_name: 'Oficina Auto Mar LTDA',
      cnpj: '33.333.333/0001-33',
      email: 'contato@oficinaautomar.com.br',
      views_count: 10,
      claim_status: :unclaimed,
      status: 'ATIVA',
      cnae_principal: '4520-0/01',
      state: state,
      city: city
    )
  end

  let!(:opt_out) { CompanyEmailOptOut.find_or_create_by_token_or_email!(email: company.email, company_id: company.id) }

  let!(:outreach_log) do
    CompanyOutreachLog.create!(
      company: company,
      email: company.email,
      campaign_name: 'profile_presentation',
      sent_at: 1.hour.ago,
      status: 'sent'
    )
  end

  it 'records click timestamp and redirects to company profile page with UTMs' do
    expect(outreach_log.clicked_at).to be_nil

    get outreach_click_path(token: opt_out.token)

    expect(response).to have_http_status(:see_other)
    outreach_log.reload
    expect(outreach_log.clicked_at).not_to be_nil

    redirect_url = URI.parse(response.location)
    expect(redirect_url.path).to include(company.slug)
    expect(redirect_url.query).to include('utm_source=email')
    expect(redirect_url.query).to include('utm_medium=outreach')
    expect(redirect_url.query).to include('utm_campaign=profile_presentation')
    expect(redirect_url.query).to include("ref=#{opt_out.token}")
  end

  it 'redirects to root path if token is invalid' do
    get outreach_click_path(token: 'invalid_token_123')
    expect(response).to redirect_to(root_path)
  end
end
