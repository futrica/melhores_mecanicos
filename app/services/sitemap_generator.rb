# app/services/sitemap_generator.rb
require "fileutils"
require "builder"

class SitemapGenerator
  MAX_URLS_PER_FILE = 10_000

  # Priority order by region for SEO:
  # 1. Sudeste: SP, RJ, MG, ES
  # 2. Sul: PR, SC, RS
  # 3. Nordeste: BA, PE, CE, MA, PB, RN, PI, AL, SE
  # 4. Centro-Oeste: DF, GO, MT, MS
  # 5. Norte: PA, AM, RO, TO, AP, AC, RR
  STATE_PRIORITY = %w[
    SP RJ MG ES
    PR SC RS
    BA PE CE MA PB RN PI AL SE
    DF GO MT MS
    PA AM RO TO AP AC RR
  ].freeze

  def self.sitemap_dir
    Rails.root.join("public", "sitemaps")
  end

  def self.index_path
    sitemap_dir.join("sitemap_index.xml")
  end

  def self.generate!(base_url: "https://www.melhoresmecanicos.com.br", skip_existing: true)
    FileUtils.mkdir_p(sitemap_dir)
    sub_sitemap_files = []

    # 1. Static & State / City / Neighborhood Sitemaps
    locations_file = sitemap_dir.join("sitemap_locations.xml")
    if skip_existing && File.exist?(locations_file) && File.size(locations_file) > 0
      sub_sitemap_files << "sitemaps/sitemap_locations.xml"
    else
      sub_sitemap_files << generate_locations_sitemap(base_url)
    end

    # 2. Company Sitemaps per State (Ordered by REGION_PRIORITY)
    ordered_states = State.includes(:cities).to_a.sort_by do |state|
      STATE_PRIORITY.index(state.acronym.upcase) || 999
    end

    ordered_states.each do |state|
      indexable_companies = Company.indexable.where(state: state).order(
        Arel.sql("CASE WHEN companies.plan = 'premium' THEN 1 WHEN companies.is_claimed = true THEN 2 ELSE 3 END, companies.id ASC")
      )

      total = indexable_companies.count
      next if total.zero?

      pages = (total.to_f / MAX_URLS_PER_FILE).ceil

      pages.times do |page_idx|
        filename = "sitemap_#{state.acronym.downcase}_#{page_idx + 1}.xml"
        filepath = sitemap_dir.join(filename)
        sub_sitemap_files << "sitemaps/#{filename}"

        if skip_existing && File.exist?(filepath) && File.size(filepath) > 0
          next
        end

        puts "⏳ Gerando #{filename}..."
        batch = indexable_companies.offset(page_idx * MAX_URLS_PER_FILE).limit(MAX_URLS_PER_FILE)
        write_company_sitemap(filepath, batch, base_url, state)
      end
    end

    # Sort sub-sitemaps array by region priority for sitemap_index.xml
    sorted_sub_sitemaps = sort_sitemap_files_by_region(sub_sitemap_files)

    # 3. Create sitemap_index.xml
    write_sitemap_index(index_path, sorted_sub_sitemaps, base_url)

    puts "✅ Sitemap gerado com sucesso: #{sorted_sub_sitemaps.size} sub-sitemaps reordenados por prioridade econômica."
  end

  def self.reindex_by_priority!(base_url: "https://www.melhoresmecanicos.com.br")
    FileUtils.mkdir_p(sitemap_dir)
    all_files = Dir.glob(sitemap_dir.join("*.xml")).map { |f| "sitemaps/#{File.basename(f)}" }
    sorted_files = sort_sitemap_files_by_region(all_files)

    write_sitemap_index(index_path, sorted_files, base_url)
    puts "✅ sitemap_index.xml reordenado com sucesso! #{sorted_files.size} sub-sitemaps priorizados."
  end

  private

  def self.sort_sitemap_files_by_region(sub_files)
    sub_files.sort_by do |file|
      if file.include?("sitemap_locations.xml")
        [ -1, 0 ] # Always first
      else
        match = file.match(/sitemap_([a-z]{2})_(\d+)\.xml/)
        if match
          state_code = match[1].upcase
          page_num = match[2].to_i
          priority_index = STATE_PRIORITY.index(state_code) || 999
          [ priority_index, page_num ]
        else
          [ 999, 0 ]
        end
      end
    end
  end

  def self.generate_locations_sitemap(base_url)
    filename = "sitemap_locations.xml"
    filepath = sitemap_dir.join(filename)

    active_city_ids = Set.new(City.joins(:companies).merge(Company.indexable).pluck(:id))
    active_neighborhood_ids = Set.new(Neighborhood.joins(:companies).merge(Company.indexable).pluck(:id))

    builder = Builder::XmlMarkup.new(indent: 2)
    builder.instruct! :xml, version: "1.0", encoding: "UTF-8"

    xml = builder.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
      # Home
      builder.url do
        builder.loc base_url
        builder.changefreq "daily"
        builder.priority "1.0"
      end

      # States
      State.find_each do |state|
        builder.url do
          builder.loc "#{base_url}/#{state.slug}"
          builder.changefreq "weekly"
          builder.priority "0.9"
        end
      end

      # Cities & Neighborhoods (Only indexable ones)
      City.includes(:state, :neighborhoods).find_each do |city|
        # City Search Listing (Only if it has indexable companies)
        if active_city_ids.include?(city.id)
          builder.url do
            builder.loc "#{base_url}/#{city.state.slug}/#{city.slug}"
            builder.changefreq "weekly"
            builder.priority "0.8"
          end
        end

        city.neighborhoods.each do |n|
          next unless active_neighborhood_ids.include?(n.id)

          builder.url do
            builder.loc "#{base_url}/#{city.state.slug}/#{city.slug}/#{n.slug}"
            builder.changefreq "weekly"
            builder.priority "0.7"
          end
        end
      end
    end

    File.write(filepath, xml)
    "sitemaps/#{filename}"
  end

  def self.write_company_sitemap(filepath, companies, base_url, state)
    builder = Builder::XmlMarkup.new(indent: 2)
    builder.instruct! :xml, version: "1.0", encoding: "UTF-8"

    xml = builder.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
      companies.each do |company|
        city_slug = company.city&.slug || "cidade"
        neigh_slug = company.neighborhood&.slug || "centro"
        url = "#{base_url}/#{state.slug}/#{city_slug}/#{neigh_slug}/#{company.slug}"

        is_rich = company.is_claimed?
        priority = is_rich ? "0.8" : "0.5"
        changefreq = is_rich ? "weekly" : "monthly"

        builder.url do
          builder.loc url
          builder.lastmod company.updated_at.iso8601
          builder.changefreq changefreq
          builder.priority priority
        end
      end
    end

    File.write(filepath, xml)
  end

  def self.write_sitemap_index(index_path, sub_files, base_url)
    builder = Builder::XmlMarkup.new(indent: 2)
    builder.instruct! :xml, version: "1.0", encoding: "UTF-8"

    xml = builder.sitemapindex(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
      sub_files.each do |sub_file|
        builder.sitemap do
          builder.loc "#{base_url}/#{sub_file}"
          builder.lastmod Time.current.iso8601
        end
      end
    end

    File.write(index_path, xml)
  end
end
