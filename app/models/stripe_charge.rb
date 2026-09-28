class StripeCharge < ApplicationRecord
  belongs_to :company
  belongs_to :subscription, optional: true

  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :fee, numericality: { greater_than_or_equal_to: 0 }
  validates :net, numericality: { greater_than_or_equal_to: 0 }
  validates :stripe_charge_id, uniqueness: true, allow_nil: true

  scope :succeeded, -> { where(status: "succeeded") }
  scope :failed, -> { where(status: "failed") }
  scope :refunded, -> { where(status: "refunded") }
  scope :recent_first, -> { order(paid_at: :desc, created_at: :desc) }

  def succeeded?
    status == "succeeded"
  end

  def failed?
    status == "failed"
  end

  def refunded?
    status == "refunded"
  end

  def seller_commission_amount
    if respond_to?(:sales_commission) && sales_commission.present?
      sales_commission.monthly_amount
    else
      0.0
    end
  end

  def net_after_commission
    [ net - seller_commission_amount, 0.0 ].max
  end

  # Process and record payment from Stripe invoice
  def self.record_from_invoice!(invoice_data, fee_amount = nil)
    invoice_id = invoice_data["id"] || invoice_data[:id]
    charge_id = invoice_data["charge"] || invoice_data[:charge]
    sub_id = invoice_data["subscription"] || invoice_data[:subscription]
    customer_id = invoice_data["customer"] || invoice_data[:customer]
    amount_paid_cents = (invoice_data["amount_paid"] || invoice_data[:amount_paid] || 0).to_i

    # Idempotency check: return existing if already recorded
    existing = find_by(stripe_invoice_id: invoice_id) || (charge_id.present? ? find_by(stripe_charge_id: charge_id) : nil)
    return existing if existing.present?

    # Find subscription & company
    subscription = Subscription.find_by(stripe_subscription_id: sub_id) if sub_id.present?
    company = subscription&.company || Company.find_by(stripe_customer_id: customer_id)
    return nil if company.blank?

    amount_val = (amount_paid_cents / 100.0).round(2)
    # Estimate standard fee if not provided (~3.99% + 0.39)
    fee_val = fee_amount.presence || ((amount_val * 0.0399) + 0.39).round(2)
    net_val = [ (amount_val - fee_val).round(2), 0.0 ].max

    active_commission = nil
    if defined?(SalesCommission) && company.respond_to?(:sales_commissions)
      active_commission = company.sales_commissions.find_by(status: "active")
    end

    charge_attributes = {
      company: company,
      subscription: subscription,
      stripe_charge_id: charge_id,
      stripe_invoice_id: invoice_id,
      stripe_customer_id: customer_id,
      amount: amount_val,
      fee: fee_val,
      net: net_val,
      currency: (invoice_data["currency"] || invoice_data[:currency] || "brl").to_s.downcase,
      status: "succeeded",
      paid_at: Time.current
    }
    charge_attributes[:sales_commission_id] = active_commission.id if active_commission.present?

    charge = create!(charge_attributes)

    # If associated with an active sales commission, increment paid installments
    if active_commission.present? && active_commission.respond_to?(:paid_installments)
      total_paid = where(sales_commission_id: active_commission.id, status: "succeeded").count
      if total_paid > active_commission.paid_installments
        active_commission.update!(paid_installments: [ total_paid, active_commission.total_installments ].min)
      end

      if active_commission.paid_installments >= active_commission.total_installments
        active_commission.update!(status: "completed")
      end
    end

    charge
  end
end
