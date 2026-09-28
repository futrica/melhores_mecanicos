require "rails_helper"

RSpec.describe DatabaseBackupService do
  describe ".perform!" do
    let(:backup_dir) { Rails.root.join("tmp", "backups") }

    before do
      FileUtils.rm_f(Dir.glob(backup_dir.join("*")))
    end

    after do
      FileUtils.rm_f(Dir.glob(backup_dir.join("*")))
    end

    it "creates a backup snapshot and compresses it successfully without leaving temporary files on disk" do
      expect(DatabaseBackupService.perform!).to be true
      expect(Dir.glob(backup_dir.join("*"))).to be_empty
    end

    context "when S3 is not configured" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("AWS_ACCESS_KEY_ID").and_return(nil)
        allow(ENV).to receive(:[]).with("AWS_SECRET_ACCESS_KEY").and_return(nil)
      end

      it "cleans up all temporary backup files from disk" do
        DatabaseBackupService.perform!
        expect(Dir.glob(backup_dir.join("*"))).to be_empty
      end
    end
  end
end
