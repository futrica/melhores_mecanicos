class CompanyOutreachJob < ApplicationJob
  queue_as :default

  def perform(limit: nil, min_views: 0, cooldown_days: 60, dry_run: false)
    service = CompanyOutreachService.new(
      limit: limit,
      min_views: min_views,
      cooldown_days: cooldown_days,
      dry_run: dry_run
    )
    results = service.perform
    Rails.logger.info("[CompanyOutreachJob] Disparos concluídos: #{results[:sent]} enviados de #{results[:processed]} processados.")
  end
end
