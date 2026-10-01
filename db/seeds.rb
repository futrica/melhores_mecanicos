# db/seeds.rb

puts "=== Populating Base Categories for Melhores Mecânicos ==="

automotive_categories = [
  "Mecânica Geral & Reparação",
  "Funilaria & Pintura",
  "Auto Elétrica & Eletrônica",
  "Alinhamento & Balanceamento",
  "Lavagem, Lubrificação & Polimento",
  "Borracharia & Pneus",
  "Instalação de Acessórios & Ar-Condicionado",
  "Capotaria & Tapeçaria Automotiva",
  "Oficina de Motos & Motonetas",
  "Guincho & Socorro Mecânico",
  "Vistoria & Inspeção Veicular",
  "Retífica de Motores & Peças",
  "Auto Peças Novas",
  "Auto Peças Usadas & Desmanche Legal",
  "Pneus & Câmaras de Ar",
  "Injeção Eletrônica",
  "Freios & Suspensão",
  "Câmbio Automático & Manual",
  "Ar-Condicionado Automotivo",
  "Troca de Óleo Rápida"
]

valid_category_names = (Company::CNAE_MAPPINGS.values + automotive_categories).uniq

# 1. Create or update valid automotive categories
valid_category_names.each do |cat_name|
  cat_slug = cat_name.parameterize
  category = Category.find_or_create_by!(name: cat_name) do |c|
    c.slug = cat_slug
  end
  puts "  - #{category.name} (#{category.slug})"
end

puts "✅ #{Category.count} Categories active and verified!"

puts "\n=== Populating Brazilian States (27 UFs) ==="
brazilian_states = [
  ["Acre", "AC"], ["Alagoas", "AL"], ["Amapá", "AP"], ["Amazonas", "AM"], ["Bahia", "BA"],
  ["Ceará", "CE"], ["Distrito Federal", "DF"], ["Espírito Santo", "ES"], ["Goiás", "GO"],
  ["Maranhão", "MA"], ["Mato Grosso", "MT"], ["Mato Grosso do Sul", "MS"], ["Minas Gerais", "MG"],
  ["Pará", "PA"], ["Paraíba", "PB"], ["Paraná", "PR"], ["Pernambuco", "PE"], ["Piauí", "PI"],
  ["Rio de Janeiro", "RJ"], ["Rio Grande do Norte", "RN"], ["Rio Grande do Sul", "RS"],
  ["Rondônia", "RO"], ["Roraima", "RR"], ["Santa Catarina", "SC"], ["São Paulo", "SP"],
  ["Sergipe", "SE"], ["Tocantins", "TO"]
]

brazilian_states.each do |name, acronym|
  State.find_or_create_by!(acronym: acronym) do |s|
    s.name = name
    s.slug = acronym.downcase
  end
end
puts "✅ #{State.count} States populated!"

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
  p.description = "Plano inicial com perfil da oficina verificado e dados públicos."
  p.active = true
end

free_price = StripePrice.find_or_initialize_by(stripe_product: free_product)
free_price.update!(
  name: "Gratuito",
  amount_cents: 0.00,
  currency: "brl",
  interval: "month",
  interval_count: 1,
  active: true
)

premium_product = StripeProduct.find_or_create_by!(slug: "premium") do |p|
  p.name = "Plano Pro Mecânicos"
  p.description = "Mini-site profissional, botão direto de WhatsApp, fotos dos serviços e destaque nas buscas locais."
  p.active = true
end
premium_product.update!(stripe_product_id: "prod_V5xyTxcWLpMtEl", active: true)

premium_price = StripePrice.find_or_initialize_by(stripe_product: premium_product)
premium_price.update!(
  name: "Plano Pro (R$ 39,90/mês)",
  amount_cents: 39.90,
  currency: "brl",
  interval: "month",
  interval_count: 1,
  stripe_price_id: "price_1U5m2sFed3D21j3aONXQYb1x",
  active: true
)

puts "✅ Stripe products & prices updated for Melhores Mecânicos!"
