namespace :geocode do
  desc "Popula latitude, longitude e geocode_precision usando Nominatim Local (Docker) em Multi-Thread Paralelo"
  task exact_local: :environment do
    $stdout.sync = true

    only_complete = ENV["ONLY_COMPLETE"] != "false"
    thread_count = (ENV["THREADS"] || 16).to_i
    batch_size = (ENV["BATCH_SIZE"] || 500).to_i

    region_map = {
      "sudeste" => %w[SP MG RJ ES],
      "sul" => %w[PR SC RS],
      "nordeste" => %w[BA PE CE MA PB RN AL SE PI],
      "centro_oeste" => %w[DF GO MT MS],
      "centro-oeste" => %w[DF GO MT MS],
      "centro" => %w[DF GO MT MS],
      "norte" => %w[AM PA AC RO RR AP TO]
    }

    target_states = nil
    if ENV["REGION"].present?
      reg_key = ENV["REGION"].to_s.downcase.strip
      target_states = region_map[reg_key]
      puts "📍 Filtro por Região: #{reg_key.upcase} (#{target_states&.join(', ')})" if target_states
    elsif ENV["STATES"].present? || ENV["STATE"].present?
      target_states = (ENV["STATES"] || ENV["STATE"]).to_s.upcase.split(",").map(&:strip)
      puts "📍 Filtro por Estados: #{target_states.join(', ')}"
    end

    query = Company.where(latitude: nil)

    if target_states.present?
      state_ids = State.where(acronym: target_states).pluck(:id)
      query = query.where(state_id: state_ids)
    end

    if only_complete
      puts "🎯 Modo: Priorizando empresas completas (Com Telefone E E-mail)..."
      query = query.where.not(email: [ nil, "", "null", "n/a", "0", "-" ])
                   .where("(phone_1 IS NOT NULL AND phone_1 NOT IN ('', 'null', 'n/a', '0', '-')) OR (phone_2 IS NOT NULL AND phone_2 NOT IN ('', 'null', 'n/a', '0', '-'))")
    else
      puts "🌐 Modo: Processando todas as empresas sem coordenadas..."
    end

    total_pending = query.count
    puts "🚀 Iniciando Geocodificação Exata Local (Paralelismo: #{thread_count} threads)"
    puts "📊 Total a processar: #{total_pending} empresas"
    puts "--------------------------------------------------------------------------------"

    # Redimensiona o pool de conexões do banco para suportar todas as threads + margem (Compatível com Rails 8 / SQLite)
    target_pool = thread_count + 15
    db_config = ActiveRecord::Base.connection_db_config.configuration_hash.merge(
      max_connections: target_pool,
      pool: target_pool,
      timeout: 30000
    )
    ActiveRecord::Base.establish_connection(db_config)
    ActiveRecord::Base.connection.execute("PRAGMA journal_mode=WAL;") rescue nil
    ActiveRecord::Base.connection.execute("PRAGMA busy_timeout=30000;") rescue nil

    step_param = (ENV["STEP"] || "ALL").to_s.upcase.strip
    run_pass_1 = %w[ALL 1].include?(step_param)
    run_pass_2 = %w[ALL 2].include?(step_param)

    puts "⚙️ Passos Selecionados: STEP=#{step_param} (Passo 1: #{run_pass_1 ? 'SIM' : 'NÃO'}, Passo 2: #{run_pass_2 ? 'SIM' : 'NÃO'})"

    exact_count = 0
    street_count = 0
    failed_count = 0
    processed_count = 0

    mutex = Mutex.new
    start_time = Time.now

    if run_pass_1
      puts "🔹 PASSO 1: Geocodificação Exata/Rua por Endereço (Alta Velocidade)..."

      query.find_in_batches(batch_size: batch_size) do |batch|
        batch.each_slice(thread_count) do |sub_slice|
          threads = sub_slice.map do |company|
            Thread.new do
              ActiveRecord::Base.connection_pool.with_connection do
                result = CompanyGeocoder.geocode_exact_fast(company)
                mutex.synchronize do
                  processed_count += 1
                  if result
                    _lat, _lng, precision = result
                    if precision == "exact"
                      exact_count += 1
                    else
                      street_count += 1
                    end
                  else
                    failed_count += 1
                  end
                end
              end
            end
          end
          threads.each(&:join)

          elapsed = Time.now - start_time
          rate = processed_count / [ elapsed, 0.1 ].max
          remaining = total_pending - processed_count
          eta_sec = remaining / [ rate, 0.001 ].max

          h = (eta_sec / 3600).to_i
          m = ((eta_sec % 3600) / 60).to_i
          s = (eta_sec % 60).to_i
          eta_str = sprintf("%02dh %02dm %02ds", h, m, s)
          pct = (processed_count.to_f / total_pending * 100).round(1)

          puts "[PASSO 1: #{processed_count}/#{total_pending}] (#{pct}%) | Vel: #{rate.round(1)} emp/s | " \
               "Exatos (Porta): #{exact_count} | Nível Rua: #{street_count} | Falhas: #{failed_count} | ETA: #{eta_str}"
          $stdout.flush
        end
      end
    end

    cep_updated_companies = 0
    if run_pass_2
      puts "--------------------------------------------------------------------------------"
      puts "🔹 PASSO 2: Geocodificação de Fallback em Lote por CEP..."

      # Busca empresas do filtro que ainda ficaram sem latitude
      pending_cep_companies = Company.where(latitude: nil)
      if target_states.present?
        state_ids = State.where(acronym: target_states).pluck(:id)
        pending_cep_companies = pending_cep_companies.where(state_id: state_ids)
      end

      if only_complete
        pending_cep_companies = pending_cep_companies.where.not(email: [ nil, "", "null", "n/a", "0", "-" ])
                                                      .where("(phone_1 IS NOT NULL AND phone_1 NOT IN ('', 'null', 'n/a', '0', '-')) OR (phone_2 IS NOT NULL AND phone_2 NOT IN ('', 'null', 'n/a', '0', '-'))")
      end

      distinct_ceps = pending_cep_companies.where.not(zip_code: [ nil, "" ]).distinct.pluck(:zip_code)
      total_ceps = distinct_ceps.count

      puts "📊 CEPs únicos pendentes de fallback: #{total_ceps}"

      processed_ceps = 0
      cep_mutex = Mutex.new
      cep_start = Time.now

      distinct_ceps.each_slice(thread_count) do |sub_slice|
        resolved_ceps = {}

        threads = sub_slice.map do |raw_cep|
          Thread.new do
            clean_cep = raw_cep.to_s.gsub(/\D/, "")
            if clean_cep.length == 8
              coords = CompanyGeocoder.geocode_cep_local(clean_cep)
              if coords
                cep_mutex.synchronize { resolved_ceps[raw_cep] = coords }
              end
            end
            cep_mutex.synchronize { processed_ceps += 1 }
          end
        end
        threads.each(&:join)

        # Atualizações no banco executadas sequencialmente no thread principal para zerar concorrência e evitar SQLite3::BusyException
        if resolved_ceps.any?
          ActiveRecord::Base.connection_pool.with_connection do
            ActiveRecord::Base.transaction do
              resolved_ceps.each do |raw_cep, coords|
                updated = Company.where(zip_code: raw_cep, latitude: nil)
                               .update_all(latitude: coords[:lat], longitude: coords[:lng], geocode_precision: "cep", updated_at: Time.current)
                cep_updated_companies += updated
              end
            end
          end
        end

        elapsed_cep = Time.now - cep_start
        rate_cep = processed_ceps / [ elapsed_cep, 0.1 ].max
        remaining_cep = total_ceps - processed_ceps
        eta_sec_cep = remaining_cep / [ rate_cep, 0.001 ].max

        h = (eta_sec_cep / 3600).to_i
        m = ((eta_sec_cep % 3600) / 60).to_i
        s = (eta_sec_cep % 60).to_i
        eta_str = sprintf("%02dh %02dm %02ds", h, m, s)
        pct = (processed_ceps.to_f / [ total_ceps, 1 ].max * 100).round(1)

        puts "[PASSO 2: #{processed_ceps}/#{total_ceps}] (#{pct}%) | Vel: #{rate_cep.round(1)} CEP/s | " \
             "Empresas Atualizadas em Lote: #{cep_updated_companies} | ETA: #{eta_str}"
        $stdout.flush
      end
    end

    total_time = Time.now - start_time
    puts "--------------------------------------------------------------------------------"
    puts "🎉 Geocodificação Exata + Fallback CEP Concluída com Sucesso!"
    puts "   • Empresas com Localização Exata (Porta): #{exact_count}"
    puts "   • Empresas Atualizadas via CEP: #{cep_updated_companies}"
    puts "   • Tempo Total Decorrido: #{(total_time / 3600).round(2)}h"
  end

  desc "Alias para geocode:exact_local"
  task companies: :exact_local
end
