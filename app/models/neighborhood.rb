class Neighborhood < ApplicationRecord
  belongs_to :city
  has_many :companies, dependent: :nullify

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :city_id }

  INVALID_PLACEHOLDERS = %w[
    sn s/n n/a na sem-bairro sem_bairro sem\ bairro nao\ consta nao\ informado
    desconhecido ignorado null undefined 0 - .
  ].freeze

  def self.valid_name?(name)
    return false if name.blank?

    cleaned = name.to_s.strip.gsub(/\A[\s\.\-]+|[\s\.\-]+\z/, "")
    return false if cleaned.length < 2

    # Reject if only digits (e.g. "05410002", "12345", "0")
    return false if cleaned.match?(/\A\d+\z/)

    # Reject CEP patterns like "05410-002" or "05410002"
    return false if cleaned.match?(/\A\d{5}-?\d{3}\z/)

    # Reject placeholders
    return false if INVALID_PLACEHOLDERS.include?(cleaned.downcase)

    true
  end

  before_validation :generate_slug, on: :create

  private

  def generate_slug
    self.slug = name.parameterize if name.present?
  end
end
