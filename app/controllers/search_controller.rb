class SearchController < ApplicationController
  include ApplicationHelper
  def index
    @states = State.order(:name)

    if params[:state_id].blank?
      @companies = Company.none
      @pagy, @companies = pagy(:offset, @companies, limit: 15)
      return
    end

    # 1. Start with active companies (no eager loading upfront)
    @companies = Company.where(status: "Ativa")

    # 2. Filter by State (Required)
    if params[:state_id].present?
      @state = State.find_by(id: params[:state_id])
      @companies = @companies.where(state_id: params[:state_id]) if @state
    end

    # 3. Filter by Cities (can be single city_id or multiple city_ids[])
    if params[:city_ids].present? || params[:city_id].present?
      city_ids = Array(params[:city_ids].presence || params[:city_id]).reject(&:blank?)
      if city_ids.any?
        @cities = City.where(id: city_ids)
        @companies = @companies.where(city_id: city_ids)
        TrackMetricJob.perform_later("City", @cities.map(&:id), :searches_count) unless bot_request?
      end
    end

    # 4. Filter by Neighborhood (can be one or multiple)
    if params[:neighborhood_ids].present?
      neighborhood_ids = Array(params[:neighborhood_ids]).reject(&:blank?)
      if neighborhood_ids.any?
        @neighborhoods = Neighborhood.where(id: neighborhood_ids)
        @companies = @companies.where(neighborhood_id: neighborhood_ids)
        TrackMetricJob.perform_later("Neighborhood", @neighborhoods.map(&:id), :searches_count) unless bot_request?
      end
    elsif params[:neighborhood_id].present?
      @neighborhood = Neighborhood.find_by(id: params[:neighborhood_id])
      if @neighborhood
        @companies = @companies.where(neighborhood_id: params[:neighborhood_id])
        TrackMetricJob.perform_later("Neighborhood", @neighborhood.id, :searches_count) unless bot_request?
      end
    end

    # 5. Filter by Category (macro-category, single slug or array of slugs)
    if params[:categories].present?
      category_slugs = Array(params[:categories]).reject { |c| c.blank? || c == "all" }
      if category_slugs.any?
        macro_names = []
        category_slugs.each { |s| macro_names.concat(map_search_category(s)) }

        db_category_ids = Category.where(slug: category_slugs).pluck(:id)
        if macro_names.any?
          db_category_ids.concat(Category.where(name: macro_names).pluck(:id))
        end

        if db_category_ids.any?
          @companies = @companies.where(
            "companies.id IN (SELECT company_id FROM categories_companies WHERE category_id IN (?))",
            db_category_ids.uniq
          )
        end
      end
    elsif params[:category].present? && params[:category] != "all"
      db_categories = map_search_category(params[:category])
      db_category_ids = []
      if db_categories.any?
        db_category_ids = Category.where(name: db_categories).pluck(:id)
      else
        @category_filter = Category.find_by(slug: params[:category])
        db_category_ids = [ @category_filter.id ] if @category_filter
      end

      if db_category_ids.any?
        @companies = @companies.where(
          "companies.id IN (SELECT company_id FROM categories_companies WHERE category_id IN (?))",
          db_category_ids.uniq
        )
      end
    end

    # 6. Filter by search query (e.g. name, CNPJ)
    if params[:q].present?
      query = "%#{params[:q]}%"
      @companies = @companies.where(
        "companies.trade_name LIKE ? OR companies.legal_name LIKE ? OR companies.cnpj LIKE ?",
        query, query, query
      )
    end

    # 6b. Filter by phone availability
    if params[:only_phone] == "1"
      @companies = @companies.where("companies.phone_1 IS NOT NULL AND companies.phone_1 != '' OR companies.phone_2 IS NOT NULL AND companies.phone_2 != ''")
    end

    # 6c. Filter by email availability
    if params[:only_email] == "1"
      @companies = @companies.where("companies.email IS NOT NULL AND companies.email != ''")
    end

    # 6d. Filter by rating ranges (supports multiple checkboxes)
    rating_ranges = Array(params[:rating_ranges]).reject(&:blank?)
    rating_ranges << params[:min_rating] if rating_ranges.empty? && params[:min_rating].present?

    if rating_ranges.any?
      conditions = []
      bind_vars = []

      rating_ranges.each do |range_str|
        if range_str.include?("-")
          min_s, max_s = range_str.split("-")
          conditions << "(AVG(reviews.rating) >= ? AND AVG(reviews.rating) <= ?)"
          bind_vars << min_s.to_f << max_s.to_f
        else
          min_r = range_str.to_f
          if min_r > 0
            conditions << "(AVG(reviews.rating) >= ?)"
            bind_vars << min_r
          end
        end
      end

      if conditions.any?
        sql_where = conditions.join(" OR ")
        @companies = @companies.where(
          "companies.id IN (SELECT company_id FROM reviews GROUP BY company_id HAVING #{sql_where})",
          *bind_vars
        )
      end
    end

    # 7. Paginate results (ordered by search priority: approved companies first, then updated_at desc)
    cache_key = nil
    if params[:q].blank? && params[:only_phone].blank? && params[:only_email].blank? && params[:state_id].present?
      cats_part = params[:categories].present? ? Array(params[:categories]).reject(&:blank?).sort.join(",") : (params[:category].presence || "all")
      cities_part = (params[:city_ids].presence || params[:city_id]).present? ? Array(params[:city_ids].presence || params[:city_id]).reject(&:blank?).sort.join(",") : "all"
      neigh_part = params[:neighborhood_ids].present? ? Array(params[:neighborhood_ids]).reject(&:blank?).sort.join(",") : (params[:neighborhood_id].presence || "all")
      cache_key = "search_count_s#{params[:state_id]}_c#{cities_part}_n#{neigh_part}_cat#{cats_part}_v2"
    end

    if cache_key
      cached_count = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        @companies.count
      end
      @pagy, @companies = pagy(:offset, @companies.by_search_priority, limit: 15, count: cached_count)
    else
      @pagy, @companies = pagy(:offset, @companies.by_search_priority, limit: 15)
    end

    # 8. Preload associations for the 15 paginated results
    @companies = @companies.preload(:categories, :neighborhood, :city, :state, :reviews, :favorites, logo_attachment: :blob)
  end

  # API endpoint for cities of a state (only cities with active companies)
  def cities
    if params[:state_id].present?
      cities = Rails.cache.fetch("state_#{params[:state_id]}_cities_api_v3", expires_in: 1.hour) do
        state = State.find_by(id: params[:state_id])
        if state
          state.cities.joins(:companies).distinct.order(:name).select(:id, :name).to_a
        else
          []
        end
      end
      render json: cities
    else
      render json: []
    end
  end

  # API endpoint for neighborhoods of multiple cities (grouped by city name, numbers last)
  def neighborhoods
    city_ids = Array(params[:city_ids]).reject(&:blank?)
    if city_ids.any?
      cache_key = "cities_#{city_ids.sort.join('_')}_neighborhoods_api_v2"
      sorted_neighborhoods = Rails.cache.fetch(cache_key, expires_in: 24.hours) do
        neighborhoods = Neighborhood.where(city_id: city_ids)
                                    .joins(:city, :companies)
                                    .distinct
                                    .select("neighborhoods.id, neighborhoods.name, cities.name as city_name, cities.id as city_id")
        neighborhoods.to_a.sort_by do |n|
          is_digit = n.name.to_s.strip.match?(/\A\d/) ? 1 : 0
          [ n.city_name.to_s.downcase, is_digit, n.name.to_s.downcase ]
        end.map { |n| { id: n.id, name: n.name, city_name: n.city_name, city_id: n.city_id } }
      end
      render json: sorted_neighborhoods
    else
      render json: []
    end
  end
end
