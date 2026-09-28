require 'rails_helper'

RSpec.describe "Stripe Integration Models", type: :model do
  describe StripeProduct do
    it "creates free, premium, and ultra_web products" do
      free_prod = StripeProduct.create!(name: "Plano Gratuito", slug: "free")
      premium_prod = StripeProduct.create!(name: "Plano Premium", slug: "premium")
      ultra_prod = StripeProduct.create!(name: "Plano Ultra Web", slug: "ultra_web")

      expect(StripeProduct.free).to eq(free_prod)
      expect(StripeProduct.premium).to eq(premium_prod)
      expect(StripeProduct.ultra_web).to eq(ultra_prod)

      expect(free_prod.free?).to be true
      expect(premium_prod.premium?).to be true
      expect(ultra_prod.ultra_web?).to be true
    end
  end

  describe StripePrice do
    let!(:product) { StripeProduct.create!(name: "Plano Premium", slug: "premium") }

    it "formats amount correctly with decimal" do
      price = StripePrice.create!(stripe_product: product, amount_cents: 3990.00, currency: "brl")
      expect(price.amount_cents).to eq(3990.0)
      expect(price.free?).to be false
      expect(price.formatted_price).to eq("R$ 3990,00")
    end

    it "identifies free prices" do
      free_price = StripePrice.create!(stripe_product: product, amount_cents: 0.00, currency: "brl")
      expect(free_price.free?).to be true
      expect(free_price.formatted_price).to eq("Grátis")
    end
  end

  describe Subscription do
    let!(:state) { State.find_or_create_by!(acronym: "SP") { |s| s.name = "São Paulo"; s.slug = "sp" } }
    let!(:city) { City.find_or_create_by!(slug: "sao-paulo", state: state) { |c| c.name = "São Paulo"; c.ibge_code = "3550308" } }

    let!(:company) { Company.create!(trade_name: "Hotel Teste", legal_name: "Hotel Teste LTDA", status: "ATIVA", cnae_principal: "5510801", cnpj: "12.345.678/0001-90", state: state, city: city) }

    let!(:product) { StripeProduct.create!(name: "Plano Premium", slug: "premium_test") }
    let!(:price) { StripePrice.create!(stripe_product: product, amount_cents: 3990.00, currency: "brl") }

    it "can create active subscription and cancel with proration" do
      sub = Subscription.create!(company: company, stripe_price: price, status: "active")
      expect(sub.active?).to be true

      sub.cancel!(prorate: true)
      expect(sub.status).to eq("canceled")
      expect(sub.canceled_at).not_to be_nil
    end
  end

  describe "Company Real-time Stripe Integration", vcr: true do
    let!(:state) { State.find_or_create_by!(acronym: "SP") { |s| s.name = "São Paulo"; s.slug = "sp" } }
    let!(:city) { City.find_or_create_by!(slug: "sao-paulo", state: state) { |c| c.name = "São Paulo"; c.ibge_code = "3550308" } }

    let!(:company) { Company.create!(trade_name: "Pousada Realtime VCR", legal_name: "Pousada LTDA", status: "ATIVA", cnae_principal: "5510801", cnpj: "99.888.777/0001-11", email: "pousada@teste.com", state: state, city: city) }

    it "creates customer live on Stripe API" do
      customer_id = company.create_stripe_customer!
      expect(customer_id).to start_with("cus_")
      expect(company.stripe_customer_id).to eq(customer_id)
    end

    it "subscribes to free plan correctly" do
      free_prod = StripeProduct.find_or_create_by!(slug: "free") { |p| p.name = "Free" }
      StripePrice.find_or_create_by!(stripe_product: free_prod) { |pr| pr.amount_cents = 0.0; pr.currency = "brl" }

      sub = company.subscribe_to_plan!("free")
      expect(company.reload.plan).to eq("free")
      expect(sub.stripe_price.free?).to be true
    end

    it "prevents card removal when an active paid subscription exists" do
      paid_prod = StripeProduct.find_or_create_by!(slug: "premium") { |p| p.name = "Premium" }
      paid_price = StripePrice.find_or_create_by!(stripe_product: paid_prod) { |pr| pr.amount_cents = 39.90; pr.currency = "brl" }
      company.update!(card_brand: "visa", card_last4: "4242", stripe_payment_method_id: "pm_123")
      Subscription.create!(company: company, stripe_price: paid_price, status: "active")

      expect(company.can_remove_card?).to be false
      expect { company.remove_card! }.to raise_error(RuntimeError, /Empresa possui plano ativo pago/)
    end
  end
end
