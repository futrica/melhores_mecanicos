require "zlib"
require "aws-sdk-s3"

class DatabaseBackupService
  RETENTION_DAYS = 30

  def self.perform!
    new.perform
  end

  def perform
    db_config_path = ActiveRecord::Base.connection_db_config.database
    db_path = db_config_path.present? ? Rails.root.join(db_config_path) : nil
    unless db_path.present? && File.exist?(db_path)
      Rails.logger.error("[DatabaseBackupService] Database file not found at: #{db_path.inspect}")
      return false
    end

    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    temp_dir = Rails.root.join("tmp", "backups")
    FileUtils.mkdir_p(temp_dir)

    raw_backup_file = temp_dir.join("backup_#{timestamp}.sqlite3").to_s
    gz_backup_file = "#{raw_backup_file}.gz"
    s3_key = "backups/db_backup_#{timestamp}.sqlite3.gz"

    begin
      Rails.logger.info("[DatabaseBackupService] Starting database backup snapshot...")

      quoted_path = ActiveRecord::Base.connection.quote(raw_backup_file)
      begin
        ActiveRecord::Base.connection.execute("VACUUM INTO #{quoted_path}")
      rescue ActiveRecord::StatementInvalid
        if ActiveRecord::Base.connection.transaction_open?
          FileUtils.cp(db_path, raw_backup_file)
        else
          raise
        end
      end

      unless File.exist?(raw_backup_file)
        Rails.logger.error("[DatabaseBackupService] Failed to create raw backup snapshot file.")
        return false
      end

      Rails.logger.info("[DatabaseBackupService] Compressing backup snapshot...")
      Zlib::GzipWriter.open(gz_backup_file) do |gz|
        File.open(raw_backup_file, "rb") do |file|
          while (chunk = file.read(16 * 1024 * 1024))
            gz.write(chunk)
          end
        end
      end

      if s3_configured?
        Rails.logger.info("[DatabaseBackupService] Uploading backup to S3 key: #{s3_key}")
        upload_to_s3(gz_backup_file, s3_key)
        cleanup_old_s3_backups
      else
        Rails.logger.warn("[DatabaseBackupService] S3 not configured or missing credentials. Backup saved locally at: #{gz_backup_file}")
      end

      Rails.logger.info("[DatabaseBackupService] Database backup completed successfully.")
      true
    rescue StandardError => e
      Rails.logger.error("[DatabaseBackupService] Backup failed: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
      Sentry.capture_exception(e) if defined?(Sentry)
      false
    ensure
      FileUtils.rm_f(raw_backup_file) if raw_backup_file && File.exist?(raw_backup_file)
      FileUtils.rm_f(gz_backup_file) if gz_backup_file && File.exist?(gz_backup_file)
    end
  end

  private

  def s3_configured?
    ENV["AWS_ACCESS_KEY_ID"].present? && ENV["AWS_SECRET_ACCESS_KEY"].present?
  end

  def s3_bucket_name
    ENV.fetch("AWS_BUCKET", "hospedagem-direta-storage")
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new(
      access_key_id: ENV["AWS_ACCESS_KEY_ID"],
      secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
      region: ENV.fetch("AWS_REGION", "us-east-2")
    )
  end

  def upload_to_s3(file_path, s3_key)
    File.open(file_path, "rb") do |file|
      s3_client.put_object(
        bucket: s3_bucket_name,
        key: s3_key,
        body: file,
        content_type: "application/gzip"
      )
    end
  end

  def cleanup_old_s3_backups
    cutoff_time = RETENTION_DAYS.days.ago
    response = s3_client.list_objects_v2(bucket: s3_bucket_name, prefix: "backups/")
    return unless response.contents.any?

    old_objects = response.contents.select do |obj|
      obj.last_modified < cutoff_time
    end

    if old_objects.any?
      delete_keys = old_objects.map { |obj| { key: obj.key } }
      s3_client.delete_objects(
        bucket: s3_bucket_name,
        delete: { objects: delete_keys }
      )
      Rails.logger.info("[DatabaseBackupService] Cleaned up #{old_objects.size} S3 backup(s) older than #{RETENTION_DAYS} days.")
    end
  rescue StandardError => e
    Rails.logger.warn("[DatabaseBackupService] Failed to cleanup old S3 backups: #{e.message}")
  end
end
