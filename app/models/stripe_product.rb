class StripeProduct < ApplicationRecord
  has_many :stripe_prices, class_name: "StripePrice", dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }

  def self.free
    find_by(slug: "free")
  end

  def self.premium
    find_by(slug: "premium")
  end

  def self.ultra_web
    find_by(slug: "ultra_web")
  end

  def free?
    slug == "free"
  end

  def premium?
    slug == "premium"
  end

  def ultra_web?
    slug == "ultra_web"
  end
end
