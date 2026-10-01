class LocationsController < ApplicationController
  include ApplicationHelper

  before_action :load_states
  before_action :set_cache_headers, if: -> { request.get? && !user_signed_in? }

  def state
    @state = State.find_by!(slug: params[:state_slug].downcase)
    params[:state_id] ||= @state.id.to_s

    scope = Company.indexable.where(state_id: @state.id)
    apply_filters_and_paginate(scope)
  end

  def city
    @state = State.find_by!(slug: params[:state_slug].downcase)
    @city = @state.cities.find_by!(slug: params[:city_slug].downcase)
    params[:state_id] ||= @state.id.to_s

    unless params[:city_ids].present?
      params[:city_ids] = [ @city.id.to_s ]
    end

    scope = Company.indexable.where(state_id: @state.id)
    apply_filters_and_paginate(scope)
    @neighborhoods = @city.neighborhoods.joins(:companies).merge(Company.indexable).distinct.to_a.sort_by { |n| [ n.name.to_s.strip.match?(/\A\d/) ? 1 : 0, n.name.to_s.downcase ] }
  end

  def neighborhood
    @state = State.find_by!(slug: params[:state_slug].downcase)
    @city = @state.cities.find_by!(slug: params[:city_slug].downcase)
    @neighborhood = @city.neighborhoods.find_by!(slug: params[:neighborhood_slug].downcase)
    params[:state_id] ||= @state.id.to_s
    params[:city_ids] ||= [ @city.id.to_s ]
    params[:neighborhood_ids] ||= [ @neighborhood.id.to_s ]

    scope = @neighborhood.companies.indexable
    apply_filters_and_paginate(scope)
  end

  private

  def apply_filters_and_paginate(base_scope)
    @companies = base_scope

    # Cities filter
    if params[:city_ids].present? || params[:city_id].present?
      city_ids = Array(params[:city_ids].presence || params[:city_id]).reject(&:blank?)
      if city_ids.any?
        @selected_cities = City.where(id: city_ids)
        @companies = @companies.where(city_id: city_ids)
        TrackMetricJob.perform_later("City", @selected_cities.map(&:id), :searches_count) unless bot_request?
      end
    end

    # Neighborhoods filter
    if params[:neighborhood_ids].present?
      neighborhood_ids = Array(params[:neighborhood_ids]).reject(&:blank?)
      if neighborhood_ids.any?
        @selected_neighborhoods = Neighborhood.where(id: neighborhood_ids)
        @companies = @companies.where(neighborhood_id: neighborhood_ids)
        TrackMetricJob.perform_later("Neighborhood", @selected_neighborhoods.map(&:id), :searches_count) unless bot_request?
      end
    end

    # Categories filter
    if params[:categories].present?
      category_slugs = Array(params[:categories]).reject { |c| c.blank? || c == "all" }
      if category_slugs.any?
        macro_names = []
        category_slugs.each { |s| macro_names.concat(map_search_category(s)) }
        db_category_ids = Category.where(slug: category_slugs).pluck(:id)
        db_category_ids.concat(Category.where(name: macro_names).pluck(:id)) if macro_names.any?
        if db_category_ids.any?
          @companies = @companies.where(
            "companies.id IN (SELECT company_id FROM categories_companies WHERE category_id IN (?))",
            db_category_ids.uniq
          )
        end
      end
    elsif params[:category].present? && params[:category] != "all"
      db_categories = map_search_category(params[:category])
      db_category_ids = db_categories.any? ? Category.where(name: db_categories).pluck(:id) : Category.where(slug: params[:category]).pluck(:id)
      if db_category_ids.any?
        @companies = @companies.where(
          "companies.id IN (SELECT company_id FROM categories_companies WHERE category_id IN (?))",
          db_category_ids.uniq
        )
      end
    end

    # Rating ranges filter (supports multiple checkboxes)
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

    # Search query
    if params[:q].present?
      query = "%#{params[:q]}%"
      @companies = @companies.where(
        "companies.trade_name LIKE ? OR companies.legal_name LIKE ? OR companies.cnpj LIKE ?",
        query, query, query
      )
    end

    # Direct contact filters
    if params[:only_phone] == "1"
      @companies = @companies.where("companies.phone_1 IS NOT NULL AND companies.phone_1 != '' OR companies.phone_2 IS NOT NULL AND companies.phone_2 != ''")
    end

    if params[:only_email] == "1"
      @companies = @companies.where("companies.email IS NOT NULL AND companies.email != ''")
    end

    # Sorting
    ordered_companies = case params[:sort]
    when "rating"
                          @companies.left_joins(:reviews).group("companies.id").order(Arel.sql("COALESCE(AVG(reviews.rating), 0) DESC, companies.is_claimed DESC"))
    when "name"
                          @companies.order(trade_name: :asc)
    when "newest"
                          @companies.order(created_at: :desc)
    else
                          @companies.by_search_priority
    end

    @pagy, @companies = pagy(:offset, ordered_companies, limit: 15)
    @companies = @companies.preload(:categories, :neighborhood, :city, :state, :reviews, :favorites, logo_attachment: :blob)
  end

  def load_states
    @states = State.order(:name)
  end

  def set_cache_headers
    if Rails.env.development? || user_signed_in? || has_filter_params?
      response.headers["Cache-Control"] = "no-cache, no-store, private, must-revalidate"
    else
      expires_in 1.hour, public: true
    end
  end

  def has_filter_params?
    params[:categories].present? || params[:rating_ranges].present? || params[:min_rating].present? || params[:only_phone].present? || params[:q].present? || params[:sort].present?
  end
end
