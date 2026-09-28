require 'vcr'
require 'webmock/rspec'

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.ignore_localhost = true
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = true

  config.filter_sensitive_data('<STRIPE_SECRET_KEY>') do
    Rails.configuration.stripe[:secret_key]
  end
end
