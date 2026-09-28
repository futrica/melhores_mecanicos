Sentry.init do |config|
  config.dsn = "https://63d73603ea9b352b6014fcca32227f1e@o4511893313617920.ingest.us.sentry.io/4511893327314944"
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.send_default_pii = true
  config.enabled_environments = %w[production]

  # Enable Performance Monitoring (traces_sample_rate: 1.0 means 100% of transactions are captured)
  # You can adjust this value in production if volume is high (e.g. 0.2 = 20%)
  config.traces_sample_rate = 0.2
end
