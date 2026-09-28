class City < ApplicationRecord
  belongs_to :state
  has_many :neighborhoods, dependent: :destroy
  has_many :companies, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :state_id }
  validates :ibge_code, presence: true

  attr_writer :companies_count

  def companies_count
    @companies_count || (respond_to?(:attributes) && attributes["companies_count"]) || companies.count
  end

  before_validation :generate_slug, on: :create

  private

  def generate_slug
    self.slug = name.parameterize if name.present?
  end
end
