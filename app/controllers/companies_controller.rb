class CompaniesController < ApplicationController
  before_action :set_cache_headers, only: [ :show ], if: -> { request.get? && !user_signed_in? }

  def show
    slug_param = params[:slug].to_s.strip
    @company = Company.includes(:state, :city, :neighborhood, :categories, :partners, :photos_attachments, reviews: :user).find_by(slug: slug_param)

    extracted_cnpj = slug_param.scan(/\d{14}/).last

    if @company.nil? && extracted_cnpj.present?
      @company = Company.unscoped.includes(:state, :city, :neighborhood, :categories, :partners, :photos_attachments, reviews: :user).find_by(cnpj: extracted_cnpj)
      @company ||= Company.unscoped.includes(:state, :city, :neighborhood, :categories, :partners, :photos_attachments, reviews: :user).where("slug LIKE ?", "%#{extracted_cnpj}").first
    end

    if @company.nil?
      if extracted_cnpj.present?
        render file: Rails.root.join("public", "410.html"), status: :gone, layout: false
        return
      else
        raise ActiveRecord::RecordNotFound
      end
    end

    if @company.deleted_at.present? || @company.status.to_s.downcase.in?(%w[baixada inapta suspensa cancelada])
      render file: Rails.root.join("public", "410.html"), status: :gone, layout: false
      return
    end

    canonical_path = helpers.company_path_for(@company)
    if request.path != canonical_path
      redirect_to canonical_path, status: :moved_permanently
      return
    end

    @state = @company.state
    @city = @company.city
    @neighborhood = @company.neighborhood
    @reviews = @company.reviews.includes(:user).order(created_at: :desc)
    @new_review = Review.new
    TrackMetricJob.perform_later("Company", @company.id, :views_count) unless bot_request?

    cnae = @company.cnae_principal

    if @neighborhood.present?
      @related_neighborhood_companies = Company.includes(:state, :city, :neighborhood)
                                                .where(city: @city, neighborhood: @neighborhood)
                                                .where.not(id: @company.id)
                                                .where(cnae_principal: cnae)
                                                .limit(6)
    else
      @related_neighborhood_companies = Company.none
    end

    @related_city_companies = Company.includes(:state, :city, :neighborhood)
                                     .where(city: @city)
                                     .where.not(id: @company.id)
                                     .where(cnae_principal: cnae)
                                     .limit(6)

    if @related_city_companies.size < 4
      existing_ids = [ @company.id ] + @related_city_companies.pluck(:id)
      @related_general_companies = Company.includes(:state, :city, :neighborhood)
                                          .where(city: @city)
                                          .where.not(id: existing_ids)
                                          .limit(6)
    else
      @related_general_companies = Company.none
    end

    if @company.latitude.present? && @company.longitude.present?
      lat = @company.latitude
      lng = @company.longitude
      @map_nearby_companies = Company.includes(:state, :city, :neighborhood)
                                     .where(city: @city)
                                     .where.not(id: @company.id)
                                     .where.not(latitude: nil, longitude: nil)
                                     .where("latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?", lat - 0.15, lat + 0.15, lng - 0.15, lng + 0.15)
                                     .limit(12)
    else
      @map_nearby_companies = Company.none
    end
  end

  private

  def set_cache_headers
    if user_signed_in?
      response.headers["Cache-Control"] = "no-cache, no-store, private, must-revalidate"
    else
      expires_in 1.hour, public: true
    end
  end
end
