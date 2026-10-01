class HomeController < ApplicationController
  before_action :set_cache_headers, only: [ :index ], if: -> { request.get? && !user_signed_in? }
  before_action :set_static_cache_headers, only: [ :ads_txt ]

  def index
    @states = State.order(:name)

    hour_key = Time.current.strftime("%Y%m%d%H")
    hour_index = Time.current.to_i / 3600

    @featured_companies = Rails.cache.fetch("home_featured_companies_v15_#{hour_key}", expires_in: 1.hour) do
      fetch_hourly_featured_companies(hour_index: hour_index, limit: 6)
    end

    @popular_cities = Rails.cache.fetch("home_popular_cities_v8", expires_in: 6.hours) do
      cities = City.includes(:state).order(searches_count: :desc, id: :asc).limit(8).to_a

      if cities.present?
        counts = Company.where(city_id: cities.map(&:id)).group(:city_id).count
        cities.each do |c|
          c.companies_count = counts[c.id] || 0
        end
      end

      cities
    end

    @popular_services = [
      {
        title: "SERVIÇOS DE FREIOS",
        name: "Serviços de Freios",
        image: "/images/services/freios.jpg",
        query: "freios",
        desc: "No Melhores Mecânicos, a segurança do seu carro vem primeiro. Revisão completa de pastilhas, discos, fluido e ABS perto da sua casa."
      },
      {
        title: "ELÉTRICA",
        name: "Auto Elétrica & Injeção",
        image: "/images/services/eletrica.jpg",
        query: "eletrica",
        desc: "Serviços elétricos e eletrônicos especializados para manter a bateria, alternador, motor de arranque e injeção do seu veículo em perfeito estado."
      },
      {
        title: "MECÂNICA EM GERAL",
        name: "Mecânica em Geral",
        image: "/images/services/mecanica_geral.jpg",
        query: "mecanica geral",
        desc: "A mecânica em geral é a nossa paixão: diagnóstico de motor, correias, cabeçote, embreagem e manutenção preventiva completa."
      },
      {
        title: "BALANCEAMENTO",
        name: "Balanceamento de Rodas",
        image: "/images/services/balanceamento.jpg",
        query: "balanceamento",
        desc: "Balanceamento especializado de rodas computadorizado que elimina vibrações no volante e transforma a estabilidade das suas viagens."
      },
      {
        title: "ALINHAMENTO",
        name: "Alinhamento de Direção",
        image: "/images/services/alinhamento.jpg",
        query: "alinhamento",
        desc: "Serviço de alinhamento 3D de direção que vai além do simples ajuste das rodas, garantindo conforto e prevenindo o desgaste irregular dos pneus."
      },
      {
        title: "TROCA DE PNEU",
        name: "Troca de Pneus & Borracharia",
        image: "/images/services/troca_pneus.jpg",
        query: "pneus",
        desc: "Substituição, montagem e reparo de pneus com equipamentos adequados para você rodar com total aderência e tranquilidade."
      },
      {
        title: "REVISÃO",
        name: "Revisão Preventiva & Check-up",
        image: "/images/services/revisao.jpg",
        query: "revisao",
        desc: "Inspeção visual e computadorizada detalhada antes de pegar a estrada com a família ou para avaliar a compra de um veículo seminovo."
      },
      {
        title: "TROCA DE ÓLEO",
        name: "Troca de Óleo & Filtros",
        image: "/images/services/troca_oleo.jpg",
        query: "troca de oleo",
        desc: "Troca rápida de óleo do motor com lubrificantes certificados e troca de filtros de óleo, ar e combustível recomendados pela montadora."
      },
      {
        title: "SUSPENSÃO",
        name: "Suspensão & Amortecedores",
        image: "/images/services/suspensao.jpg",
        query: "suspensao",
        desc: "Amortecedores, molas, bandejas, buchas e pivôs revisados para absorver impactos e manter a estabilidade do veículo em qualquer piso."
      }
    ]

    @stats = Rails.cache.fetch("home_global_stats_v3", expires_in: 2.hours) do
      {
        total_companies: Company.count,
        total_cities: City.count,
        total_states: State.count
      }
    end
  end

  def ads_txt
    publisher_id = ENV["ADSENSE_PUBLISHER_ID"]
    if publisher_id.present?
      clean_pub_id = publisher_id.gsub(/^ca-/, "")
      render plain: "google.com, #{clean_pub_id}, DIRECT, f08c47fec0942fa0"
    else
      render plain: "# Google AdSense ads.txt - Melhores Mecânicos\ngoogle.com, pub-0000000000000000, DIRECT, f08c47fec0942fa0", status: :ok
    end
  end

  private

  def fetch_hourly_featured_companies(hour_index:, limit: 6)
    base_includes = [ :categories, :neighborhood, :city, :state, :reviews, :favorites ]

    # Pool 1: Claimed companies prioritized
    claimed_pool = Company.includes(*base_includes)
                          .where("is_claimed = ? OR claim_status = ?", true, "approved")
                          .order(updated_at: :desc)
                          .limit(60)
                          .to_a

    featured = []

    if claimed_pool.present?
      if claimed_pool.size >= limit
        start_idx = (hour_index * limit) % claimed_pool.size
        featured = (claimed_pool + claimed_pool)[start_idx, limit]
      else
        featured = claimed_pool
      end
    end

    needed = limit - featured.size
    if needed > 0
      # Pool 2: Unclaimed companies ordered by updated_at
      unclaimed_pool = Company.includes(*base_includes)
                              .where(is_claimed: false)
                              .where.not(claim_status: :approved)
                              .order(updated_at: :desc)
                              .limit(120)
                              .to_a

      if unclaimed_pool.present?
        start_idx = (hour_index * needed) % unclaimed_pool.size
        featured += (unclaimed_pool + unclaimed_pool)[start_idx, needed]
      end
    end

    featured.first(limit)
  end

  def set_cache_headers
    if user_signed_in?
      response.headers["Cache-Control"] = "no-cache, no-store, private, must-revalidate"
    else
      expires_in 15.minutes, public: true
    end
  end

  def set_static_cache_headers
    expires_in 1.day, public: true
  end
end
