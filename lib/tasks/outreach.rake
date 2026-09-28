namespace :outreach do
  desc "Envia e-mails de apresentação do site para empresas com mais de X visualizações de forma gradual (com travas SES)"
  task :send_profile_presentation, [ :limit, :min_views, :cooldown_days, :dry_run ] => :environment do |_t, args|
    limit = args[:limit].presence || 10
    min_views = args[:min_views].presence || 10
    cooldown_days = args[:cooldown_days].presence || 60
    dry_run = args[:dry_run].to_s == "true"

    puts "=================================================="
    puts "🚀 Iniciando disparos de prospecção (Outreach)"
    puts "Limite por lote: #{limit}"
    puts "Mínimo de views: #{min_views}"
    puts "Janela de Cooldown: #{cooldown_days} dias"
    puts "Modo Dry Run (Simulação): #{dry_run ? 'SIM (Nenhum e-mail real será enviado)' : 'NÃO (ENVIANDO E-MAILS REAIS)'}"
    puts "=================================================="

    service = CompanyOutreachService.new(
      limit: limit,
      min_views: min_views,
      cooldown_days: cooldown_days,
      dry_run: dry_run
    )

    results = service.perform

    puts "\n📊 RESUMO DO PROCESSAMENTO:"
    puts "--------------------------------------------------"
    puts "Total de empresas elegíveis no banco: #{results[:total_eligible]}"
    puts "Processados neste lote: #{results[:processed]}"
    puts "Enviados com sucesso: #{results[:sent]}"
    puts "Ignorados (Opt-Out): #{results[:skipped_opt_out]}"
    puts "Ignorados (UOL/BOL pausado): #{results[:skipped_uol_paused]}"
    puts "Ignorados (Notificados recentemente): #{results[:skipped_recently_sent]}"
    puts "Ignorados (MX/Domínio inválido): #{results[:skipped_invalid_mx]}"
    puts "Falhas de envio: #{results[:failed]}"
    puts "--------------------------------------------------"

    if results[:details].any?
      puts "\n📋 DETALHES DAS EMPRESAS:"
      results[:details].each do |item|
        puts " - [#{item[:company_id]}] #{item[:name]} | #{item[:city]} | #{item[:views]} views | #{item[:email]} | Status: #{item[:status]}"
      end
    end

    puts "\n✅ Finalizado com sucesso."
  end
end
