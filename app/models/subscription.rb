class Subscription < ApplicationRecord
  belongs_to :company
  belongs_to :stripe_price, class_name: "StripePrice"
  has_one :stripe_product, through: :stripe_price
  has_many :stripe_charges, dependent: :nullify

  validates :status, presence: true

  scope :active, -> { where(status: "active") }
  scope :canceled, -> { where(status: "canceled") }

  def active?
    status == "active" && (ends_at.nil? || ends_at > Time.current)
  end

  def free?
    stripe_price&.free? || stripe_product&.free?
  end

  def cancel!(prorate: true)
    return if status == "canceled"

    if stripe_subscription_id.present?
      begin
        Stripe::Subscription.cancel(stripe_subscription_id, { prorate: prorate })
      rescue Stripe::StripeError => e
        Rails.logger.error("Error canceling Stripe subscription #{stripe_subscription_id}: #{e.message}")
      end
    end

    update!(
      status: "canceled",
      canceled_at: Time.current,
      ends_at: Time.current
    )
  end
end
