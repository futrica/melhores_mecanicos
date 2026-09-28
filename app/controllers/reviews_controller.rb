class ReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_client!
  before_action :ensure_confirmed!, only: [ :create ]

  def create
    @company = Company.find(params[:company_id])
    @review = @company.reviews.build(review_params)
    @review.user = current_user

    if @review.save
      redirect_to helpers.company_seo_path(@company), notice: "Sua avaliação foi enviada com sucesso! Obrigado por ajudar a comunidade. 🧱"
    else
      @state = @company.state
      @city = @company.city
      @neighborhood = @company.neighborhood
      @reviews = @company.reviews.order(created_at: :desc)
      @new_review = @review
      render "companies/show", status: :unprocessable_entity
    end
  end

  def destroy
    @review = current_user.reviews.find(params[:id])
    company = @review.company
    company_name = company.trade_name.presence || company.legal_name
    @review.destroy
    redirect_back fallback_location: app_root_path, notice: "Sua avaliação de '#{company_name}' foi removida."
  end

  private

  def ensure_client!
    unless current_user.client?
      redirect_to root_path, alert: "Apenas clientes podem avaliar hospedagens."
    end
  end

  def review_params
    params.require(:review).permit(:rating, tags: [])
  end
end
