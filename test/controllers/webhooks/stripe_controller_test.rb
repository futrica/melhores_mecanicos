require "test_helper"

class Webhooks::StripeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @company = companies(:ze)
    prod = StripeProduct.find_or_create_by!(slug: "premium") { |p| p.name = "Premium" }
    price = StripePrice.find_or_create_by!(stripe_product: prod) { |p| p.amount_cents = 39.9 }

    @subscription = @company.subscriptions.create!(
      stripe_price: price,
      stripe_subscription_id: "sub_test_123",
      status: "active",
      created_at: 10.days.ago
    )
  end

  test "handles invoice.payment_succeeded and records StripeCharge" do
    payload = {
      id: "evt_test_1",
      type: "invoice.payment_succeeded",
      data: {
        object: {
          id: "in_invoice_test_123",
          charge: "ch_charge_test_123",
          subscription: "sub_test_123",
          customer: "cus_customer_123",
          amount_paid: 3990,
          currency: "brl"
        }
      }
    }.to_json

    assert_difference "StripeCharge.count", 1 do
      post webhooks_stripe_path, params: payload, headers: { "CONTENT_TYPE" => "application/json" }
    end

    assert_response :ok

    charge = StripeCharge.find_by(stripe_invoice_id: "in_invoice_test_123")
    assert_not_nil charge
    assert_equal 39.90, charge.amount
    assert_equal "succeeded", charge.status
    assert_equal @company, charge.company

    # Idempotency check: duplicate event does not create a second charge
    assert_no_difference "StripeCharge.count" do
      post webhooks_stripe_path, params: payload, headers: { "CONTENT_TYPE" => "application/json" }
    end
    assert_response :ok
  end

  test "handles invoice.payment_failed and records failed charge" do
    payload = {
      id: "evt_test_2",
      type: "invoice.payment_failed",
      data: {
        object: {
          id: "in_fail_123",
          charge: "ch_fail_123",
          subscription: "sub_test_123",
          customer: "cus_customer_123",
          amount_due: 3990,
          currency: "brl",
          last_payment_error: { message: "Cartão recusado pelo emissor" }
        }
      }
    }.to_json

    assert_difference "StripeCharge.count", 1 do
      post webhooks_stripe_path, params: payload, headers: { "CONTENT_TYPE" => "application/json" }
    end

    assert_response :ok
    charge = StripeCharge.find_by(stripe_invoice_id: "in_fail_123")
    assert_equal "failed", charge.status
    assert_match /Cartão recusado/, charge.failure_message
  end

  test "handles charge.refunded" do
    charge = @company.stripe_charges.create!(
      stripe_charge_id: "ch_to_refund",
      amount: 39.90,
      fee: 1.98,
      net: 37.92,
      status: "succeeded"
    )

    payload = {
      id: "evt_test_3",
      type: "charge.refunded",
      data: {
        object: {
          id: "ch_to_refund"
        }
      }
    }.to_json

    post webhooks_stripe_path, params: payload, headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :ok

    charge.reload
    assert_equal "refunded", charge.status
    assert_not_nil charge.refunded_at
  end

  test "handles customer.subscription.deleted" do
    payload = {
      id: "evt_test_4",
      type: "customer.subscription.deleted",
      data: {
        object: {
          id: "sub_test_123"
        }
      }
    }.to_json

    post webhooks_stripe_path, params: payload, headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :ok

    @subscription.reload
    assert_equal "canceled", @subscription.status
  end
end
