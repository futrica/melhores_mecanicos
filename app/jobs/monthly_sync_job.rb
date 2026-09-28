class MonthlySyncJob < ApplicationJob
  queue_as :default

  def perform
    log_dir = Rails.root.join("log")
    FileUtils.mkdir_p(log_dir)
    log_file = log_dir.join("monthly_sync.log").to_s
    pid = Process.spawn(
      { "RAILS_ENV" => Rails.env },
      "bin/rails",
      "import:monthly_sync",
      out: [ log_file, "a" ],
      err: [ log_file, "a" ]
    )
    Process.detach(pid)
    Rails.logger.info "MonthlySyncJob spawned background process with PID #{pid} (logging to #{log_file})"
  end
end
