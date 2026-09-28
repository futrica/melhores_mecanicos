namespace :tmp do
  desc "Clear custom temp directories (backups, cnpj_download)"
  task clear: :environment do
    dirs = [
      Rails.root.join("tmp", "backups"),
      Rails.root.join("tmp", "cnpj_download")
    ]

    dirs.each do |dir|
      if Dir.exist?(dir)
        FileUtils.rm_rf(Dir.glob(dir.join("*")))
      end
    end
  end
end
