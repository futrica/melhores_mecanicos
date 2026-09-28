# db/seeds.rb

puts "=== Populating Base Categories for Hospedagem Direta ==="

valid_category_names = Company::CNAE_MAPPINGS.values.uniq

# 1. Create or update valid lodging categories
valid_category_names.each do |cat_name|
  cat_slug = cat_name.parameterize
  category = Category.find_or_create_by!(name: cat_name) do |c|
    c.slug = cat_slug
  end
  puts "  - #{category.name} (#{category.slug})"
end

# 2. Clean up obsolete categories from legacy project
obsolete = Category.where.not(name: valid_category_names)
if obsolete.any?
  puts "🧹 Cleaning #{obsolete.count} obsolete categories..."
  obsolete.destroy_all
end

puts "✅ #{Category.count} Categories active and verified!"

puts "\n=== Creating/Updating Admin User ==="
admin_user = User.find_or_initialize_by(email: "jmfutrica@gmail.com")
admin_user.password = "28355Joao!"
admin_user.password_confirmation = "28355Joao!"
admin_user.name = "João Futrica"
admin_user.role = "admin"
admin_user.terms_accepted = "1"
admin_user.skip_confirmation! if admin_user.respond_to?(:skip_confirmation!)
admin_user.confirmed_at ||= Time.current
admin_user.save!
puts "✅ Admin user ready: #{admin_user.email}"

puts "\n=== Creating Stripe Products and Prices ==="
free_product = StripeProduct.find_or_create_by!(slug: "free") do |p|
  p.name = "Plano Gratuito"
  p.description = "Plano inicial com suporte a até 3 fotos e 3 quartos ad aeternum."
  p.active = true
end

free_price = StripePrice.find_or_initialize_by(stripe_product: free_product)
free_price.update!(
  name: "Gratuito ad aeternum",
  amount_cents: 0.00,
  currency: "brl",
  interval: "month",
  interval_count: 1,
  active: true
)

premium_product = StripeProduct.find_or_create_by!(slug: "premium") do |p|
  p.name = "Plano Premium"
  p.description = "Até 20 fotos, quartos ilimitados, WhatsApp em destaque e prioridade nas buscas."
  p.active = true
end
premium_product.update!(stripe_product_id: "prod_V5xyTxcWLpMtEl", active: true)

premium_price = StripePrice.find_or_initialize_by(stripe_product: premium_product)
premium_price.update!(
  name: "Plano Premium (R$ 39,90/mês)",
  amount_cents: 39.90,
  currency: "brl",
  interval: "month",
  interval_count: 1,
  stripe_price_id: "price_1U5m2sFed3D21j3aONXQYb1x",
  active: true
)

ultra_web_product = StripeProduct.find_or_create_by!(slug: "ultra_web") do |p|
  p.name = "Plano Ultra Web"
  p.description = "Website completo exclusivo com domínio próprio + todas as vantagens do Premium."
  p.active = false
end
ultra_web_product.update!(active: false)

ultra_price = StripePrice.find_or_initialize_by(stripe_product: ultra_web_product)
ultra_price.update!(
  name: "Plano Ultra Web (R$ 299,00/mês)",
  amount_cents: 299.00,
  currency: "brl",
  interval: "month",
  interval_count: 1,
  active: false
)


puts "✅ Stripe products & prices updated for recurring monthly subscriptions!"


puts "✅ Stripe products & prices seeded!"
