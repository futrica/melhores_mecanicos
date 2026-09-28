class FavoritesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_client!
  before_action :ensure_confirmed!

  def toggle
    @company = Company.find(params[:company_id])
    favorite = current_user.favorites.find_by(company: @company)

    if favorite
      favorite.destroy
      flash[:notice] = "#{@company.trade_name} removido dos seus favoritos."
    else
      favorite = current_user.favorites.new(company: @company)
      if favorite.save
        flash[:notice] = "#{@company.trade_name} adicionado aos seus favoritos! ❤️"
      else
        flash[:alert] = favorite.errors.full_messages.to_sentence
      end
    end

    redirect_back(fallback_location: root_path)
  end

  private

  def ensure_client!
    unless current_user.client?
      flash[:alert] = "Apenas clientes podem favoritar hospedagens."
      redirect_back(fallback_location: root_path)
    end
  end
end
