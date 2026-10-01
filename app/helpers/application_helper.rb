module ApplicationHelper
  def category_style_for(category_name)
    case category_name.to_s
    when /Mecânica|Reparação|Motor|Injeção/i
      { icon: "🔧", gradient: "linear-gradient(135deg, #093892 0%, #00A1FC 100%)" }
    when /Elétrica|Baterias|Eletrônica/i
      { icon: "⚡", gradient: "linear-gradient(135deg, #0284c7 0%, #00A1FC 100%)" }
    when /Freio|Suspensão|Amortecedor/i
      { icon: "🛑", gradient: "linear-gradient(135deg, #0f172a 0%, #093892 100%)" }
    when /Câmbio|Embreagem|Transmissão/i
      { icon: "⚙️", gradient: "linear-gradient(135deg, #0f172a 0%, #334155 100%)" }
    when /Ar-Condicionado|Climatização/i
      { icon: "❄️", gradient: "linear-gradient(135deg, #00A1FC 0%, #38bdf8 100%)" }
    when /Óleo|Lubrific/i
      { icon: "🛢️", gradient: "linear-gradient(135deg, #093892 0%, #0284c7 100%)" }
    when /Funilaria|Pintura|Martelinho/i
      { icon: "🔨", gradient: "linear-gradient(135deg, #475569 0%, #093892 100%)" }
    when /Alinhamento|Balanceamento|Pneus|Borracharia/i
      { icon: "🚗", gradient: "linear-gradient(135deg, #093892 0%, #00A1FC 100%)" }
    else
      { icon: "🔧", gradient: "linear-gradient(135deg, #093892 0%, #00A1FC 100%)" }
    end
  end

  def grouped_categories
    Rails.cache.fetch("grouped_categories_v5") do
      categories = Category.order(:name).to_a
      {
        "Especialidade Automotiva" => categories
      }.select { |_, cats| cats.any? }
    end
  end

  def map_search_category(category)
    case category.to_s.downcase
    when "mecanica", "mecanica-geral", "reparacao"
      [ "Mecânica Geral & Reparação" ]
    when "eletrica", "auto-eletrica", "eletronica"
      [ "Auto Elétrica & Eletrônica" ]
    when "funilaria", "pintura", "funilaria-e-pintura"
      [ "Funilaria & Pintura" ]
    when "alinhamento", "balanceamento"
      [ "Alinhamento & Balanceamento" ]
    when "lavagem", "lubrificacao", "troca-de-oleo"
      [ "Lavagem & Lubrificação" ]
    when "borracharia", "pneus"
      [ "Borracharia & Pneus" ]
    when "acessorios"
      [ "Acessórios & Equipamentos" ]
    else
      []
    end
  end

  def footer_states_and_cities
    Rails.cache.fetch("footer_states_and_cities_v1", expires_in: 12.hours) do
      data = City.joins(:companies, :state)
                 .group("states.id, cities.id")
                 .select("states.name AS state_name, states.acronym AS state_acronym, states.slug AS state_slug, cities.name AS city_name, cities.slug AS city_slug, COUNT(companies.id) AS companies_count")
                 .order("state_name ASC, city_name ASC")
                 .to_a

      data.group_by { |r| [ r.state_name, r.state_acronym, r.state_slug ] }
    end
  end

  def company_seo_path(company)
    company_page_path(
      state_slug: company.state.slug,
      city_slug: company.city.slug,
      neighborhood_slug: company.neighborhood&.slug.presence || "geral",
      slug: company.slug
    )
  end

  def google_analytics_tag
    return unless Rails.env.production?

    ga_id = ENV["GOOGLE_ANALYTICS_ID"].presence
    return nil if ga_id.blank?

    safe_join([
      tag.script(async: true, src: "https://www.googletagmanager.com/gtag/js?id=#{ga_id}"),
      content_tag(:script, "
        window.dataLayer = window.dataLayer || [];
        function gtag(){dataLayer.push(arguments);}
        gtag('js', new Date());
        gtag('config', '#{ga_id}');

        document.addEventListener('turbo:load', function() {
          if (typeof gtag === 'function') {
            gtag('config', '#{ga_id}', {
              'page_location': window.location.href,
              'page_path': window.location.pathname
            });
          }
        });
      ".html_safe)
    ])
  end

  def adsense_script_tag
    publisher_id = ENV["ADSENSE_PUBLISHER_ID"]
    return nil if publisher_id.blank?

    tag.script(
      async: true,
      src: "https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=#{publisher_id}",
      crossorigin: "anonymous"
    )
  end

  def adsense_ad_tag(slot_type)
    publisher_id = ENV["ADSENSE_PUBLISHER_ID"]
    return adsense_placeholder(slot_type) if publisher_id.blank?

    slot_id = case slot_type
    when :top then ENV["ADSENSE_TOP_SLOT_ID"]
    when :sidebar then ENV["ADSENSE_SIDEBAR_SLOT_ID"]
    when :inline then ENV["ADSENSE_INLINE_SLOT_ID"]
    end

    slot_id ||= ENV["ADSENSE_DEFAULT_SLOT_ID"]

    return adsense_placeholder(slot_type) if slot_id.blank?

    style = case slot_type
    when :sidebar then "display:block; min-height:250px;"
    else "display:block;"
    end

    format = case slot_type
    when :sidebar then "vertical"
    else "horizontal"
    end

    content_tag(:div, class: "adsense-wrapper my-4", data: { controller: "adsense" }) do
      concat(
        content_tag(:ins, "",
          class: "adsbygoogle",
          style: style,
          data: {
            ad_client: publisher_id,
            ad_slot: slot_id,
            ad_format: format,
            full_width_responsive: "true"
          }
        )
      )
      concat(
        content_tag(:script, "(adsbygoogle = window.adsbygoogle || []).push({});".html_safe)
      )
    end
  end

  def can_claim_company?
    return true unless user_signed_in?
    return false if current_user.company.present? || current_user.admin?

    true
  end

  def safe_external_url(url)
    return nil if url.blank?
    clean = url.to_s.strip
    return nil if clean.downcase.start_with?("javascript:", "data:", "vbscript:")

    clean.start_with?("http://", "https://") ? clean : "https://#{clean}"
  end

  def render_markdown(text)
    return "" if text.blank?
    formatted_text = text.to_s.gsub(/(?<!\n)\n(#+\s+)/, "\n\n\\1")
                              .gsub(/(?<!\n)\n([\*\-]\s+)/, "\n\n\\1")
    html = Kramdown::Document.new(formatted_text).to_html
    html.html_safe
  end

  def custom_pagy_nav(pagy)
    return "" if pagy.blank? || pagy.pages <= 1

    html = []
    html << %Q(<nav class="flex flex-wrap items-center justify-center gap-1.5 font-sans my-8" aria-label="Paginação">)

    if pagy.previous
      prev_params = params.to_unsafe_h.merge(page: pagy.previous)
      prev_url = url_for(prev_params)
      html << %Q(<a href="#{prev_url}" class="inline-flex items-center justify-center h-10 px-3.5 rounded-xl border border-slate-200 bg-white text-slate-700 font-bold text-xs sm:text-sm shadow-sm hover:bg-emerald-50 hover:text-emerald-700 hover:border-emerald-500 transition-all">&larr; Anterior</a>)
    else
      html << %Q(<span class="inline-flex items-center justify-center h-10 px-3.5 rounded-xl border border-slate-100 bg-slate-50 text-slate-300 font-bold text-xs sm:text-sm cursor-not-allowed">&larr; Anterior</span>)
    end

    pagy.send(:series).each do |item|
      if item.is_a?(String)
        html << %Q(<span class="inline-flex items-center justify-center min-w-[2.5rem] h-10 px-3 rounded-xl bg-emerald-600 border border-emerald-600 text-white font-black text-xs sm:text-sm shadow-md cursor-default">#{item}</span>)
      elsif item.is_a?(Integer)
        page_params = params.to_unsafe_h.merge(page: item)
        page_url = url_for(page_params)
        html << %Q(<a href="#{page_url}" class="inline-flex items-center justify-center min-w-[2.5rem] h-10 px-3 rounded-xl border border-slate-200 bg-white text-slate-700 font-bold text-xs sm:text-sm shadow-sm hover:bg-emerald-50 hover:text-emerald-700 hover:border-emerald-500 transition-all">#{item}</a>)
      elsif item == :gap
        html << %Q(<span class="inline-flex items-center justify-center min-w-[2rem] h-10 text-slate-400 font-bold text-xs sm:text-sm select-none">&hellip;</span>)
      end
    end

    if pagy.next
      next_params = params.to_unsafe_h.merge(page: pagy.next)
      next_url = url_for(next_params)
      html << %Q(<a href="#{next_url}" class="inline-flex items-center justify-center h-10 px-3.5 rounded-xl border border-slate-200 bg-white text-slate-700 font-bold text-xs sm:text-sm shadow-sm hover:bg-emerald-50 hover:text-emerald-700 hover:border-emerald-500 transition-all">Próximo &rarr;</a>)
    else
      html << %Q(<span class="inline-flex items-center justify-center h-10 px-3.5 rounded-xl border border-slate-100 bg-slate-50 text-slate-300 font-bold text-xs sm:text-sm cursor-not-allowed">Próximo &rarr;</span>)
    end

    html << %Q(</nav>)
    html.join("\n").html_safe
  end

  private

  def adsense_placeholder(slot_type)
    return nil if Rails.env.production?

    label = case slot_type
    when :top then "Banner Horizontal Superior (Dev Mode)"
    when :sidebar then "Banner Lateral / Vertical (Dev Mode)"
    when :inline then "Banner Horizontal de Conteúdo (Dev Mode)"
    else "Espaço Publicitário (Dev Mode)"
    end

    content_tag(:div, class: "adsense-placeholder-wrapper my-4") do
      concat(content_tag(:span, "Publicidade", class: "adsense-placeholder-tag"))
      concat(content_tag(:div, label, class: "adsense-placeholder-box #{slot_type}"))
    end
  end
end
