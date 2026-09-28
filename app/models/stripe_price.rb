class StripePrice < ApplicationRecord
  belongs_to :stripe_product, class_name: "StripeProduct"
  has_many :subscriptions, dependent: :restrict_with_error

  validates :amount_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true

  scope :active, -> { where(active: true) }

  def free?
    amount_cents.nil? || amount_cents.zero?
  end

  def formatted_price
    return "Grátis" if free?

    format("R$ %.2f", amount_cents).tr(".", ",")
  end
end
