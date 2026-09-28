namespace :sitemap do
  desc "Gera o sitemap_index.xml e sub-sitemaps fracionados por Estado para o Google (Use FORCE=true para recriar tudo)"
  task generate: :environment do
    base_url = ENV.fetch("BASE_URL", "https://hospedagemdireta.com.br")
    force = ENV["FORCE"].to_s.downcase == "true"
    puts "🚀 Gerando sitemaps fracionados pSEO (Base URL: #{base_url}, Force: #{force})..."
    SitemapGenerator.generate!(base_url: base_url, skip_existing: !force)
    puts "🎉 Geração de sitemaps concluída!"
  end

  desc "Força a regeneração de todos os sitemaps (mesmo os existentes)"
  task force_generate: :environment do
    ENV["FORCE"] = "true"
    Rake::Task["sitemap:generate"].invoke
  end
end

