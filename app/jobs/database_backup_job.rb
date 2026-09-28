class DatabaseBackupJob < ApplicationJob
  queue_as :default

  def perform
    DatabaseBackupService.perform!
  end
end
