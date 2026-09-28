class PagesController < ApplicationController
  before_action :set_cache_headers

  def about
  end

  def pricing
    @company = current_user.company if user_signed_in?
  end


  def terms
  end

  def privacy
  end

  private

  def set_cache_headers
    if Rails.env.development? || user_signed_in?
      response.headers["Cache-Control"] = "no-cache, no-store, private, must-revalidate"
    else
      expires_in 1.day, public: true if request.get?
    end
  end
end
