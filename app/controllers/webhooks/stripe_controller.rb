module Webhooks
  class StripeController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate_user!, raise: false

    def create
      payload = request.body.read
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
      webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"]

      event = nil

      if webhook_secret.present? && sig_header.present?
        begin
          event = Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)
        rescue JSON::ParserError => e
          render json: { error: "Invalid payload: #{e.message}" }, status: :bad_request and return
        rescue Stripe::SignatureVerificationError => e
          render json: { error: "Invalid signature: #{e.message}" }, status: :bad_request and return
        end
      else
        begin
          event = JSON.parse(payload)
        rescue JSON::ParserError => e
          render json: { error: "Invalid JSON payload" }, status: :bad_request and return
        end
      end

      event_type = event["type"] || event[:type]
      event_data = (event["data"] || event[:data])&.[]("object") || (event["data"] || event[:data])&.[](:object) || {}

      case event_type
      when "invoice.payment_succeeded", "invoice.paid"
        handle_invoice_paid(event_data)
      when "invoice.payment_failed"
        handle_invoice_failed(event_data)
      when "customer.subscription.deleted"
        handle_subscription_deleted(event_data)
      when "charge.refunded"
        handle_charge_refunded(event_data)
      end

      head :ok
    end

    private

    def handle_invoice_paid(invoice_data)
      StripeCharge.record_from_invoice!(invoice_data)
    end

    def handle_invoice_failed(invoice_data)
      invoice_id = invoice_data["id"] || invoice_data[:id]
      charge_id = invoice_data["charge"] || invoice_data[:charge]
      sub_id = invoice_data["subscription"] || invoice_data[:subscription]
      customer_id = invoice_data["customer"] || invoice_data[:customer]
      amount_cents = (invoice_data["amount_due"] || invoice_data[:amount_due] || 0).to_i

      subscription = Subscription.find_by(stripe_subscription_id: sub_id) if sub_id.present?
      company = subscription&.company || Company.find_by(stripe_customer_id: customer_id)
      return if company.blank?

      StripeCharge.create!(
        company: company,
        subscription: subscription,
        stripe_charge_id: charge_id,
        stripe_invoice_id: invoice_id,
        stripe_customer_id: customer_id,
        amount: (amount_cents / 100.0).round(2),
        fee: 0.0,
        net: 0.0,
        currency: (invoice_data["currency"] || invoice_data[:currency] || "brl").to_s.downcase,
        status: "failed",
        failure_message: invoice_data.dig("last_payment_error", "message") || "Falha na cobrança da fatura"
      ) rescue nil
    end

    def handle_subscription_deleted(sub_data)
      sub_id = sub_data["id"] || sub_data[:id]
      subscription = Subscription.find_by(stripe_subscription_id: sub_id)
      return if subscription.blank?

      subscription.cancel!(prorate: false)
    end

    def handle_charge_refunded(charge_data)
      charge_id = charge_data["id"] || charge_data[:id]
      charge = StripeCharge.find_by(stripe_charge_id: charge_id)
      return if charge.blank?

      charge.update!(
        status: "refunded",
        refunded_at: Time.current
      )
    end
  end
end
