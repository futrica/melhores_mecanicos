class Category < ApplicationRecord
  has_and_belongs_to_many :companies

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create
  after_commit :clear_category_cache

  private

  def generate_slug
    self.slug = name.parameterize if name.present?
  end

  def clear_category_cache
    Rails.cache.delete("grouped_categories_v3")
  end
end
