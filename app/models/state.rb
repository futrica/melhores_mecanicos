class State < ApplicationRecord
  has_many :cities, dependent: :destroy
  has_many :companies, dependent: :destroy

  validates :acronym, presence: true, uniqueness: true, length: { is: 2 }
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create

  private

  def generate_slug
    self.slug = acronym.downcase if acronym.present?
  end
end
