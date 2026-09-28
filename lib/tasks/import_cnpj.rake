# lib/tasks/import_cnpj.rake
require "csv"
require "net/http"
require "json"
require "fileutils"

def download_and_verify_zip(zip_name, zip_url, zip_path, token, min_size: 100_000, max_retries: 3)
  if File.exist?(zip_path) && system("unzip -t -q \"#{zip_path}\" > /dev/null 2>&1")
    puts "File #{zip_name} already exists and is valid. Skipping download."
    return true
  end

  if File.exist?(zip_path)
    puts "File #{zip_name} exists but is incomplete or corrupted. Attempting to resume/redownload..."
  else
    puts "Downloading #{zip_name}..."
  end

  retry_count = 0
  download_success = false

  while retry_count < max_retries && !download_success
    # -C - allows resuming download if it fails mid-way
    system("curl -L -C - -u \"#{token}:\" -o \"#{zip_path}\" \"#{zip_url}\"")

    if File.exist?(zip_path) && File.size(zip_path) >= min_size && system("unzip -t -q \"#{zip_path}\" > /dev/null 2>&1")
      download_success = true
    else
      if File.exist?(zip_path) && File.size(zip_path) < min_size
        puts "⚠️ Warning: Downloaded file is too small (#{File.size(zip_path)} bytes). Likely a server error page."
        File.delete(zip_path)
      elsif File.exist?(zip_path)
        puts "⚠️ Warning: Zip file integrity check failed."
        # If resume failed after 1 retry, delete corrupt partial file and restart fresh
        File.delete(zip_path) if retry_count >= 1
      end

      retry_count += 1
      if retry_count < max_retries
        wait_time = 10 * retry_count
        puts "⚠️ Retrying download in #{wait_time} seconds (Attempt #{retry_count + 1}/#{max_retries})..."
        sleep(wait_time)
      end
    end
  end

  unless download_success && File.exist?(zip_path)
    puts "❌ Error: Failed to download/verify #{zip_name} after #{max_retries} attempts."
    File.delete(zip_path) if File.exist?(zip_path)
    return false
  end

  true
end

namespace :import do
  desc "Seed all Brazilian States and Cities from official IBGE API"
  task ibge_cities: :environment do
    puts "=== Fetching States from IBGE API ==="
    states_uri = URI("https://servicodados.ibge.gov.br/api/v1/localidades/estados")
    states_response = Net::HTTP.get(states_uri)
    states_data = JSON.parse(states_response)

    states_by_id = {}
    states_data.sort_by { |s| s["sigla"] }.each do |state_info|
      acronym = state_info["sigla"]
      name = state_info["nome"]

      state = State.find_or_initialize_by(acronym: acronym)
      state.name = name
      state.save!
      states_by_id[state_info["id"]] = state
      print "."
    end
    puts "\nCreated #{State.count} states."

    puts "=== Fetching Cities from IBGE API ==="
    cities_uri = URI("https://servicodados.ibge.gov.br/api/v1/localidades/municipios")
    cities_response = Net::HTTP.get(cities_uri)
    cities_data = JSON.parse(cities_response)

    ActiveRecord::Base.transaction do
      cities_data.each_with_index do |city_info, index|
        name = city_info["nome"]
        ibge_code = city_info["id"].to_s
        state_acronym = city_info.dig("microrregiao", "mesorregiao", "UF", "sigla")
        state = state_acronym.present? ? State.find_by(acronym: state_acronym) : nil

        next unless state

        city = City.find_or_initialize_by(ibge_code: ibge_code)
        city.name = name
        city.state = state
        city.save!

        if index % 500 == 0
          print "#{index}..."
        end
      end
    end
    puts "\nCreated #{City.count} cities in total."
  end

  desc "Automatically download, extract, and import CNPJ data from Receita Federal"
  task download_and_import: :environment do
    base_url = "https://arquivos.receitafederal.gov.br/public.php/webdav"
    token = "YggdBLfdninEJX9"
    temp_dir = Rails.root.join("tmp", "cnpj_download")
    FileUtils.mkdir_p(temp_dir)

    begin
    # 1. Populate and Cache Categories in memory to prevent slow SQL queries
    puts "📁 Populating and preloading Categories in memory..."
    categories_by_slug = {}
    Company::CNAE_MAPPINGS.values.uniq.each do |cat_name|
      cat_slug = cat_name.parameterize
      category = Category.find_or_create_by!(name: cat_name, slug: cat_slug)
      categories_by_slug[cat_slug] = category
    end
    puts "Loaded #{categories_by_slug.size} categories."

    # 2. Detect latest directory dynamically
    puts "🔍 Detecting latest data directory from Receita Federal WebDAV..."
    uri = URI("#{base_url}/")
    req = Net::HTTP::Propfind.new(uri.path)
    req.basic_auth(token, "")
    req["Depth"] = "1"

    begin
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 30) do |http|
        http.request(req)
      end

      matches = res.body.scan(/\/public\.php\/webdav\/(\d{4}-\d{2})\/?/)
      latest_dir = matches.map(&:first).uniq.sort.last

      if latest_dir.nil?
        latest_dir = "2026-07" # default fallback
        puts "⚠️ Could not auto-detect. Falling back to: #{latest_dir}"
      else
        puts "✅ Detected latest directory: #{latest_dir}"
      end
    rescue => e
      latest_dir = "2026-07" # default fallback
      puts "⚠️ Connection failed: #{e.message}. Falling back to: #{latest_dir}"
    end

    webdav_url = "#{base_url}/#{latest_dir}"

    # 3. Download and parse MUNICIPA table to map Receita City Codes to names
    puts "\n=== Step 1: Downloading Receita Municipios Mapping ==="
    mun_zip_name = "Municipios.zip"
    mun_zip_path = File.join(temp_dir, mun_zip_name)

    unless download_and_verify_zip(mun_zip_name, "#{webdav_url}/#{mun_zip_name}", mun_zip_path, token, min_size: 1_000)
      raise "Could not download Municipios zip file."
    end

    puts "Extracting #{mun_zip_name}..."
    system("unzip -o \"#{mun_zip_path}\" -d \"#{temp_dir}\"")

    extracted_files = Dir.glob(File.join(temp_dir, "*")).reject { |f| f.end_with?(".zip") || File.directory?(f) }
    mun_csv_path = extracted_files.first

    if mun_csv_path.nil?
      raise "Could not extract Municipios file."
    end

    puts "Loading Municipios mapping into memory..."
    city_mapping = {}
    CSV.foreach(mun_csv_path, col_sep: ";", encoding: "ISO-8859-1:UTF-8", headers: false) do |row|
      code = row[0].to_s.strip
      name = row[1].to_s.strip
      city_mapping[code] = name
    end
    puts "Loaded #{city_mapping.size} city mappings."

    # Clean up Municipios CSV
    File.delete(mun_csv_path) if File.exist?(mun_csv_path)

    # 4. Cycle through the 10 Estabelecimentos files
    target_cnaes = Set.new(Company::CNAE_MAPPINGS.keys)
    active_status_code = "02"
    total_imported = 0

    start_index = ENV.fetch("START_INDEX", 0).to_i
    (start_index..9).each do |i|
      zip_name = "Estabelecimentos#{i}.zip"
      zip_url = "#{webdav_url}/#{zip_name}"
      zip_path = File.join(temp_dir, zip_name)

      puts "\n======================================================="
      puts "📥 [#{i+1}/10] Processing #{zip_name}"
      puts "======================================================="

      # Download zip file
      unless download_and_verify_zip(zip_name, zip_url, zip_path, token)
        puts "❌ Error: Failed to download #{zip_name}. Skipping to next file..."
        next
      end

      # Extract zip file
      puts "Extracting #{zip_name}..."
      unzip_success = system("unzip -o \"#{zip_path}\" -d \"#{temp_dir}\"")
      unless unzip_success
        puts "❌ Error: Failed to unzip #{zip_name}. Skipping..."
        File.delete(zip_path) if File.exist?(zip_path)
        next
      end

      # Find extracted CSV
      csv_files = Dir.glob(File.join(temp_dir, "*")).reject { |f| f.end_with?(".zip") || File.directory?(f) }
      csv_path = csv_files.first

      if csv_path.nil?
        puts "❌ Error: Extracted CSV not found."
        File.delete(zip_path) if File.exist?(zip_path)
        next
      end

      # Import matching companies
      puts "Importing matches from #{File.basename(csv_path)}..."
      count = 0
      matched = 0

      # Read CSV line by line to prevent memory overhead
      CSV.foreach(csv_path, col_sep: ";", encoding: "ISO-8859-1:UTF-8", headers: false) do |row|
        count += 1
        sleep(0.001) if count % 2_000 == 0
        if count % 100_000 == 0
          print "."
        end

        cnae_principal = row[11].to_s.gsub(/\D/, "") # CNAE Fiscal Principal (normalized)
        cnae_secundarios = row[12].to_s.strip
        status = row[5] # Situação Cadastral

        # Extract all CNAEs for this establishment (principal + secondary)
        all_company_cnaes = [ cnae_principal ]
        cnae_secundarios.split(",").each do |sec_cnae|
          cleaned = sec_cnae.to_s.gsub(/\D/, "")
          all_company_cnaes << cleaned if cleaned.present?
        end

        # Check if ANY of the company's CNAEs match our target CNAEs
        next unless all_company_cnaes.any? { |code| target_cnaes.include?(code) }

        cnpj_base = row[0]
        cnpj_ordem = row[1]
        cnpj_dv = row[2]
        cnpj = "#{cnpj_base}#{cnpj_ordem}#{cnpj_dv}"

        status_name = case status
        when "02" then "Ativa"
        when "08" then "Baixada"
        when "04" then "Inapta"
        when "03" then "Suspensa"
        when "01" then "Nula"
        else "Inativa"
        end

        if status != active_status_code
          company = Company.unscoped.find_by(cnpj: cnpj)
          if company && company.deleted_at.nil? && company.status != status_name
            company.update(status: status_name)
          end
          next
        end

        matriz_filial_code = row[3].to_s.strip
        establishment_type = case matriz_filial_code
        when "1" then "Matriz"
        when "2" then "Filial"
        else nil
        end

        status_date_raw = row[6].to_s.strip
        status_date = Date.strptime(status_date_raw, "%Y%m%d") rescue nil

        opening_date_raw = row[10].to_s.strip
        opening_date = Date.strptime(opening_date_raw, "%Y%m%d") rescue nil

        trade_name = row[4].to_s.strip
        next if Company.bankrupt_or_in_liquidation?(trade_name)
        street_type = row[13].to_s.strip
        street_name = row[14].to_s.strip
        street = [ street_type, street_name ].compact.join(" ").strip
        number = row[15].to_s.strip
        complement = row[16].to_s.strip
        neighborhood_name = row[17].to_s.strip
        zip_code = row[18].to_s.strip
        state_acronym = row[19].to_s.strip
        receita_city_code = row[20].to_s.strip
        ddd = row[21].to_s.strip
        phone = row[22].to_s.strip
        tel_1 = ddd.present? || phone.present? ? "(#{ddd}) #{phone}" : nil

        ddd_2 = row[23].to_s.strip
        phone_2 = row[24].to_s.strip
        tel_2 = ddd_2.present? || phone_2.present? ? "(#{ddd_2}) #{phone_2}" : nil

        telephone = [ tel_1, tel_2 ].compact.join(" / ")
        email = row[27].to_s.strip

        state = State.find_by(acronym: state_acronym)
        next unless state

        # Translate Receita City Code to Name, and lookup IBGE city
        receita_city_name = city_mapping[receita_city_code]
        next unless receita_city_name

        city_slug = receita_city_name.parameterize
        city = state.cities.find_by(slug: city_slug)
        if city.nil?
          fallback_slug = case city_slug
          when "parati" then "paraty"
          when "embu" then "embu-das-artes"
          when "moji-das-cruzes" then "mogi-das-cruzes"
          when "moji-guacu" then "mogi-guacu"
          when "moji-mirim" then "mogi-mirim"
          when "sant-ana-do-livramento" then "santana-do-livramento"
          when "pau-d-arco" then "pau-darco"
          else city_slug
          end
          city = state.cities.find_by(slug: fallback_slug)
        end
        next unless city

        neighborhood = nil
        if neighborhood_name.present? && Neighborhood.valid_name?(neighborhood_name)
          # Normalize and titleize first so search slug matches validation slug exactly
          n_name = neighborhood_name.to_s.strip.titleize
          n_slug = n_name.parameterize
          if n_slug.present?
            neighborhood = city.neighborhoods.find_or_initialize_by(slug: n_slug)
            if neighborhood.new_record?
              neighborhood.name = n_name
              neighborhood.save!
            end
          end
        end

        company = Company.unscoped.find_or_initialize_by(cnpj: cnpj)
        next if company.deleted_at.present?
        # NEVER overwrite custom data of companies claimed or managed by users
        next if company.is_claimed? || company.user_id.present? || company.claim_status != "unclaimed"
        company.assign_attributes(
          state: state,
          city: city,
          neighborhood: neighborhood,
          trade_name: trade_name.presence || "Hospedagem",
          legal_name: trade_name.presence || "Hospedagem Ltda",
          cnae_principal: cnae_principal,
          cnae_secundarios: cnae_secundarios,
          opening_date: opening_date,
          establishment_type: establishment_type,
          status_date: status_date,
          status: "Ativa",
          street: street,
          number: number,
          complement: complement,
          zip_code: zip_code,
          phone_1: tel_1,
          phone_1_whatsapp: Company.mobile_phone?(tel_1),
          phone_2: tel_2,
          phone_2_whatsapp: Company.mobile_phone?(tel_2),
          email: email
        )

        # Build category assignments based on main and secondary CNAEs
        company_categories = []
        all_company_cnaes.each do |cnae_code|
          cat_name = Company::CNAE_MAPPINGS[cnae_code]
          if cat_name
            cat_slug = cat_name.parameterize
            company_categories << categories_by_slug[cat_slug]
          end
        end

        company.categories = company_categories.uniq.compact

        if company.save
          matched += 1
        end
      end

      total_imported += matched
      puts "\n✅ Finished #{zip_name}. Processed: #{count} lines. Imported: #{matched} stores."

      # Clean up current CSV and ZIP to free disk space immediately
      File.delete(csv_path) if File.exist?(csv_path)
      File.delete(zip_path) if File.exist?(zip_path)
      GC.start
      puts "Reserving disk space: Cleaned up CSV and ZIP files."
    end

    puts "\n🎉 All downloads and imports finished! Total imported: #{total_imported} hospedagens."
    ensure
      FileUtils.rm_rf(temp_dir) if temp_dir && Dir.exist?(temp_dir)
    end
  end

  desc "Download, extract and import corporate names (Razão Social) from Receita Federal EMPRESAS files"
  task legal_names: :environment do
    base_url = "https://arquivos.receitafederal.gov.br/public.php/webdav"
    token = "YggdBLfdninEJX9"
    temp_dir = Rails.root.join("tmp", "cnpj_download")
    FileUtils.mkdir_p(temp_dir)

    begin
    # 1. Load all imported company IDs grouped by their 8-digit CNPJ base
    puts "📂 Loading CNPJ bases from database..."
    company_ids_by_base = Hash.new { |h, k| h[k] = [] }
    Company.pluck(:id, :cnpj).each do |id, cnpj|
      base = cnpj[0..7]
      company_ids_by_base[base] << id
    end

    if company_ids_by_base.empty?
      raise "No companies found in the database. Run import:download_and_import first!"
    end
    puts "Loaded #{company_ids_by_base.size} unique CNPJ bases representing #{Company.count} establishments."

    # 2. Detect latest directory dynamically
    puts "🔍 Detecting latest data directory from Receita Federal WebDAV..."
    uri = URI("#{base_url}/")
    req = Net::HTTP::Propfind.new(uri.path)
    req.basic_auth(token, "")
    req["Depth"] = "1"

    begin
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 30) do |http|
        http.request(req)
      end
      matches = res.body.scan(/\/public\.php\/webdav\/(\d{4}-\d{2})\/?/)
      latest_dir = matches.map(&:first).uniq.sort.last
      latest_dir ||= "2026-07"
      puts "✅ Detected latest directory: #{latest_dir}"
    rescue => e
      latest_dir = "2026-07"
      puts "⚠️ Connection failed: #{e.message}. Falling back to: #{latest_dir}"
    end

    webdav_url = "#{base_url}/#{latest_dir}"
    total_updated = 0

    # 3. Cycle through the 10 Empresas files
    start_index = ENV.fetch("START_INDEX", 0).to_i
    (start_index..9).each do |i|
      zip_name = "Empresas#{i}.zip"
      zip_url = "#{webdav_url}/#{zip_name}"
      zip_path = File.join(temp_dir, zip_name)

      puts "\n======================================================="
      puts "📥 [#{i+1}/10] Processing #{zip_name}"
      puts "======================================================="

      # Download zip file
      unless download_and_verify_zip(zip_name, zip_url, zip_path, token)
        puts "❌ Error: Failed to download #{zip_name}. Skipping to next file..."
        next
      end

      # Extract zip file
      puts "Extracting #{zip_name}..."
      unzip_success = system("unzip -o \"#{zip_path}\" -d \"#{temp_dir}\"")
      unless unzip_success
        puts "❌ Error: Failed to unzip #{zip_name}. Skipping..."
        File.delete(zip_path) if File.exist?(zip_path)
        next
      end

      # Find extracted CSV
      csv_files = Dir.glob(File.join(temp_dir, "*")).reject { |f| f.end_with?(".zip") || File.directory?(f) }
      csv_path = csv_files.first

      if csv_path.nil?
        puts "❌ Error: Extracted CSV not found."
        File.delete(zip_path) if File.exist?(zip_path)
        next
      end

      # Parse and update legal names
      puts "Updating names from #{File.basename(csv_path)}..."
      count = 0
      updated = 0

      CSV.foreach(csv_path, col_sep: ";", encoding: "ISO-8859-1:UTF-8", headers: false) do |row|
        count += 1
        if count % 100_000 == 0
          print "."
        end

        base = row[0].to_s.strip
        next unless company_ids_by_base.key?(base)

        raw_legal_name = row[1].to_s.strip
        # Clean up leading numbers/CNPJ prefixes often present in MEI legal names
        cleaned_name = raw_legal_name.gsub(/^\d[\d\.\-\/]*\s+/, "").strip.titleize

        legal_nature_code = row[2].to_s.strip
        capital_social_val = row[4].to_s.tr(",", ".").to_f

        size_code = row[5].to_s.strip
        company_size_name = case size_code
        when "01" then "Microempresa (ME)"
        when "03" then "Empresa de Pequeno Porte (EPP)"
        when "05" then "Demais"
        else nil
        end

        ids = company_ids_by_base[base]

        # Purge companies if corporate name indicates bankruptcy or liquidation
        if Company.bankrupt_or_in_liquidation?(raw_legal_name) || Company.bankrupt_or_in_liquidation?(cleaned_name)
          Company.where(id: ids).destroy_all
          next
        end

        # Run updates
        Company.where(id: ids).find_each do |company|
          next if company.is_claimed? || company.user_id.present? || company.claim_status != "unclaimed"
          company.legal_name = cleaned_name
          company.legal_nature = legal_nature_code if legal_nature_code.present?
          company.capital_social = capital_social_val if capital_social_val.positive?
          company.company_size = company_size_name if company_size_name.present?

          # If trade name is the default generic fallback, or consists only of symbols/numbers (no letters)
          has_no_letters = !company.trade_name.to_s.match?(/[a-zA-ZÁ-Úá-úçÇãõÃÕâêôÂÊÔ]/)
          if company.trade_name == "Hospedagem" || company.trade_name == "Pousada" || has_no_letters
            company.trade_name = cleaned_name
            # Recreate slug using new trade_name
            clean_cnpj = company.cnpj.to_s.gsub(/\D/, "")
            company.slug = "#{cleaned_name} #{clean_cnpj}".parameterize
          end

          if company.save
            updated += 1
          end
        end
      end

      total_updated += updated
      puts "\n✅ Finished #{zip_name}. Processed: #{count} lines. Updated: #{updated} establishments."

      # Clean up current CSV and ZIP to free disk space immediately
      File.delete(csv_path) if File.exist?(csv_path)
      File.delete(zip_path) if File.exist?(zip_path)
      puts "🧹 Cleaned up CSV and ZIP files to reclaim disk space."
    end

    puts "\n🎉 All corporate names updated successfully! Total updated: #{total_updated} records."
    ensure
      FileUtils.rm_rf(temp_dir) if temp_dir && Dir.exist?(temp_dir)
    end
  end

  desc "Download, extract and import partner details (Sócios) from Receita Federal SOCIOS files"
  task partners: :environment do
    base_url = "https://arquivos.receitafederal.gov.br/public.php/webdav"
    token = "YggdBLfdninEJX9"
    temp_dir = Rails.root.join("tmp", "cnpj_download")
    FileUtils.mkdir_p(temp_dir)

    begin
    qualifications = {
      "05" => "Administrador",
      "10" => "Diretor",
      "16" => "Presidente",
      "22" => "Sócio",
      "28" => "Sócio-Gerente",
      "37" => "Sócio Capitalista",
      "49" => "Sócio-Administrador",
      "65" => "Titular Pessoa Física EIRELI",
      "84" => "Sócio Produtor Rural"
    }

    person_types = {
      "1" => "Pessoa Jurídica",
      "2" => "Pessoa Física",
      "3" => "Estrangeiro"
    }

    age_ranges = {
      "1" => "0 a 12 anos",
      "2" => "13 a 20 anos",
      "3" => "21 a 30 anos",
      "4" => "31 a 40 anos",
      "5" => "41 a 50 anos",
      "6" => "51 a 60 anos",
      "7" => "61 a 70 anos",
      "8" => "71 a 80 anos",
      "9" => "Mais de 80 anos"
    }

    # 1. Load all imported company IDs grouped by their 8-digit CNPJ base
    puts "📂 Loading CNPJ bases from database..."
    company_ids_by_base = Hash.new { |h, k| h[k] = [] }
    Company.pluck(:id, :cnpj).each do |id, cnpj|
      base = cnpj[0..7]
      company_ids_by_base[base] << id
    end

    if company_ids_by_base.empty?
      raise "No companies found in database. Run import:download_and_import first!"
    end
    puts "Loaded #{company_ids_by_base.size} unique CNPJ bases."

    # 2. Detect latest directory
    puts "🔍 Detecting latest data directory from Receita Federal WebDAV..."
    uri = URI("#{base_url}/")
    req = Net::HTTP::Propfind.new(uri.path)
    req.basic_auth(token, "")
    req["Depth"] = "1"

    begin
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 30) do |http|
        http.request(req)
      end
      matches = res.body.scan(/\/public\.php\/webdav\/(\d{4}-\d{2})\/?/)
      latest_dir = matches.map(&:first).uniq.sort.last
      latest_dir ||= "2026-07"
      puts "✅ Detected latest directory: #{latest_dir}"
    rescue => e
      latest_dir = "2026-07"
      puts "⚠️ Connection failed: #{e.message}. Falling back to: #{latest_dir}"
    end

    webdav_url = "#{base_url}/#{latest_dir}"
    total_partners_imported = 0

    start_index = ENV.fetch("START_INDEX", 0).to_i
    (start_index..9).each do |i|
      zip_name = "Socios#{i}.zip"
      zip_url = "#{webdav_url}/#{zip_name}"
      zip_path = File.join(temp_dir, zip_name)

      puts "\n======================================================="
      puts "📥 [#{i+1}/10] Processing #{zip_name}"
      puts "======================================================="

      # Download zip file
      unless download_and_verify_zip(zip_name, zip_url, zip_path, token)
        puts "❌ Error: Failed to download #{zip_name}. Skipping to next file..."
        next
      end

      puts "Extracting #{zip_name}..."
      unzip_success = system("unzip -o \"#{zip_path}\" -d \"#{temp_dir}\"")
      unless unzip_success
        puts "❌ Error: Failed to unzip #{zip_name}. Skipping..."
        File.delete(zip_path) if File.exist?(zip_path)
        next
      end

      csv_files = Dir.glob(File.join(temp_dir, "*")).reject { |f| f.end_with?(".zip") || File.directory?(f) }
      csv_path = csv_files.first

      if csv_path.nil?
        puts "❌ Error: Extracted CSV not found."
        File.delete(zip_path) if File.exist?(zip_path)
        next
      end

      puts "Importing partners from #{File.basename(csv_path)}..."
      count = 0
      imported_in_file = 0

      CSV.foreach(csv_path, col_sep: ";", encoding: "ISO-8859-1:UTF-8", headers: false) do |row|
        count += 1
        print "." if count % 100_000 == 0

        base = row[0].to_s.strip
        next unless company_ids_by_base.key?(base)

        p_type_code = row[1].to_s.strip
        p_name = row[2].to_s.strip.titleize
        p_doc = row[3].to_s.strip
        p_qual_code = row[4].to_s.strip
        p_date_raw = row[5].to_s.strip
        p_age_code = row[10].to_s.strip

        entry_date = Date.strptime(p_date_raw, "%Y%m%d") rescue nil
        qualification = qualifications[p_qual_code] || p_qual_code
        person_type = person_types[p_type_code] || p_type_code
        age_range = age_ranges[p_age_code]

        company_ids_by_base[base].each do |comp_id|
          Partner.find_or_create_by!(
            company_id: comp_id,
            name: p_name,
            document: p_doc
          ) do |partner|
            partner.qualification = qualification
            partner.entry_date = entry_date
            partner.person_type = person_type
            partner.age_range = age_range
          end
          imported_in_file += 1
        end
      end

      total_partners_imported += imported_in_file
      puts "\n✅ Finished #{zip_name}. Processed: #{count} lines. Imported #{imported_in_file} partner records."

      File.delete(csv_path) if File.exist?(csv_path)
      File.delete(zip_path) if File.exist?(zip_path)
      puts "🧹 Cleaned up CSV and ZIP files."
    end

    puts "\n🎉 All partner records imported successfully! Total partners: #{total_partners_imported}."
    ensure
      FileUtils.rm_rf(temp_dir) if temp_dir && Dir.exist?(temp_dir)
    end
  end

  desc "Clean up invalid/dirty neighborhood records (CEPs, single letters, placeholders) from database"
  task clean_invalid_neighborhoods: :environment do
    puts "🧹 Cleaning invalid neighborhood records from database..."
    invalid_neighborhoods = Neighborhood.all.reject { |n| Neighborhood.valid_name?(n.name) }

    count = invalid_neighborhoods.size
    puts "Found #{count} invalid neighborhood records to clean."

    if count > 0
      ActiveRecord::Base.transaction do
        invalid_ids = invalid_neighborhoods.map(&:id)
        # Nullify neighborhood_id in associated companies
        companies_updated = Company.where(neighborhood_id: invalid_ids).update_all(neighborhood_id: nil)
        # Destroy invalid neighborhood records
        Neighborhood.where(id: invalid_ids).delete_all

        puts "✅ Successfully cleaned #{count} invalid neighborhoods and unlinked #{companies_updated} companies."
      end
    else
      puts "✨ No invalid neighborhoods found!"
    end
  end

  desc "Clean up bankrupt or in-liquidation companies from database"
  task clean_bankrupt_companies: :environment do
    puts "🧹 Cleaning bankrupt and in-liquidation companies from database..."
    bankrupt_companies = Company.all.select { |c| Company.bankrupt_or_in_liquidation?(c.legal_name) || Company.bankrupt_or_in_liquidation?(c.trade_name) }

    count = bankrupt_companies.size
    puts "Found #{count} bankrupt/in-liquidation companies to remove."

    if count > 0
      ActiveRecord::Base.transaction do
        bankrupt_ids = bankrupt_companies.map(&:id)
        Company.where(id: bankrupt_ids).destroy_all
        puts "✅ Successfully removed #{count} bankrupt companies from database."
      end
    else
      puts "✨ No bankrupt companies found in database!"
    end
  end

  desc "Run full monthly sync (Receita Federal CNPJ download, names, partners, cleanup, and sitemap regeneration)"
  task monthly_sync: :environment do
    app_name = "Hospedagem Direta"
    start_time = Time.current
    initial_stats = {
      total_companies: Company.count,
      active_companies: Company.where(status: "Ativa").count,
      claimed_companies: Company.where(is_claimed: true).count
    }

    puts "🚀 Starting Monthly Receita Federal Sync at #{start_time}..."

    begin
      AdminNotificationMailer.monthly_sync_started(
        app_name: app_name,
        start_time: start_time,
        initial_stats: initial_stats
      ).deliver_now
    rescue => e
      puts "⚠️ Could not send start notification email: #{e.message}"
    end

    begin
      companies_before = Company.count
      partners_before = Partner.count rescue 0

      Rake::Task["import:download_and_import"].invoke
      Rake::Task["import:legal_names"].invoke
      Rake::Task["import:partners"].invoke
      Rake::Task["import:clean_invalid_neighborhoods"].invoke
      Rake::Task["import:clean_bankrupt_companies"].invoke
      Rake::Task["sitemap:force_generate"].invoke

      end_time = Time.current
      duration_minutes = ((end_time - start_time) / 60.0).round(1)

      companies_after = Company.count
      partners_after = Partner.count rescue 0

      stats = {
        companies_before: companies_before,
        companies_after: companies_after,
        new_companies_added: [companies_after - companies_before, 0].max,
        partners_before: partners_before,
        partners_after: partners_after,
        new_partners_added: [partners_after - partners_before, 0].max,
        total_active_companies: Company.where(status: "Ativa").count,
        total_claimed_companies: Company.where(is_claimed: true).count
      }

      puts "🎉 Monthly Sync completed successfully in #{duration_minutes} minutes!"

      AdminNotificationMailer.monthly_sync_completed(
        app_name: app_name,
        start_time: start_time,
        end_time: end_time,
        duration_minutes: duration_minutes,
        stats: stats
      ).deliver_now
    rescue => e
      end_time = Time.current
      duration_minutes = ((end_time - start_time) / 60.0).round(1)
      puts "❌ Monthly Sync failed after #{duration_minutes} minutes: #{e.message}"

      begin
        AdminNotificationMailer.monthly_sync_failed(
          app_name: app_name,
          start_time: start_time,
          end_time: end_time,
          duration_minutes: duration_minutes,
          error_message: e.message,
          backtrace: e.backtrace&.first(5)&.join("\n")
        ).deliver_now
      rescue => mail_err
        puts "⚠️ Could not send failure notification email: #{mail_err.message}"
      end

      raise e
    end
  end
end

namespace :import_cnpj do
  desc "Alias for import:ibge_cities"
  task ibge_cities: "import:ibge_cities"

  desc "Alias for import:download_and_import"
  task download_and_import: "import:download_and_import"

  desc "Alias for import:legal_names"
  task legal_names: "import:legal_names"

  desc "Alias for import:partners"
  task partners: "import:partners"

  desc "Alias for import:clean_invalid_neighborhoods"
  task clean_invalid_neighborhoods: "import:clean_invalid_neighborhoods"

  desc "Alias for import:clean_bankrupt_companies"
  task clean_bankrupt_companies: "import:clean_bankrupt_companies"

  desc "Alias for import:monthly_sync"
  task monthly_sync: "import:monthly_sync"
end
