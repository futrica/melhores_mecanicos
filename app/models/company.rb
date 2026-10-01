class Company < ApplicationRecord
  CNAE_MAPPINGS = {
    # Manutenção e Reparação de Veículos Automotores (Grupo 45.2)
    "4520001" => "Mecânica Geral & Reparação",
    "4520002" => "Funilaria & Pintura",
    "4520003" => "Auto Elétrica & Eletrônica",
    "4520004" => "Alinhamento & Balanceamento",
    "4520005" => "Lavagem, Lubrificação & Polimento",
    "4520006" => "Borracharia & Pneus",
    "4520007" => "Instalação de Acessórios & Ar-Condicionado",
    "4520008" => "Capotaria & Tapeçaria Automotiva",

    # Manutenção e Reparação de Motocicletas (Grupo 45.4)
    "4543900" => "Oficina de Motos & Motonetas",

    # Socorro Mecânico, Guincho e Inspeção Técnica Automotiva
    "5229002" => "Guincho & Socorro Mecânico",
    "7120100" => "Vistoria & Inspeção Veicular",

    # Retífica e Reparação de Motores / Peças Automotivas
    "2941700" => "Retífica de Motores & Peças",

    # Comércio Varejista com Serviços Automotivos Conexos
    "4530703" => "Auto Peças Novas",
    "4530704" => "Auto Peças Usadas & Desmanche Legal",
    "4530705" => "Pneus & Câmaras de Ar"
  }.freeze

  COMMON_CNAE_DESCRIPTIONS = {
    # Manutenção e Reparação Automotiva (Grupo 45.2)
    "4520001" => "Serviços de Manutenção e Reparação Mecânica de Veículos Automotores",
    "4520002" => "Serviços de Lanternagem, Funilaria e Pintura de Veículos Automotores",
    "4520003" => "Serviços de Manutenção e Reparação do Sistema Elétrico e Eletrônico de Veículos Automotores",
    "4520004" => "Serviços de Alinhamento e Balanceamento de Veículos Automotores",
    "4520005" => "Serviços de Lavagem, Lubrificação e Polimento de Veículos Automotores",
    "4520006" => "Serviços de Borracharia para Veículos Automotores",
    "4520007" => "Serviços de Instalação, Manutenção e Reparação de Acessórios para Veículos Automotores",
    "4520008" => "Serviços de Capotaria e Tapeçaria para Veículos Automotores",

    # Manutenção de Motocicletas (Grupo 45.4)
    "4543900" => "Manutenção e Reparação de Motocicletas e Motonetas",

    # Socorro, Guincho, Reboque e Inspeção Veicular
    "5229002" => "Serviços de Reboque de Veículos (Guincho e Socorro Mecânico)",
    "7120100" => "Testes e Análises Técnicas (Vistoria e Inspeção Veicular)",

    # Retífica e Fabricação de Peças Automotivas
    "2941700" => "Fabricação e Retífica de Peças e Acessórios para o Sistema Motor de Veículos Automotores",
    "2942500" => "Fabricação de Peças e Acessórios para os Sistemas de Marcha e Transmissão de Veículos",
    "2943300" => "Fabricação de Peças e Acessórios para o Sistema de Freios e Suspensão de Veículos",
    "2944100" => "Fabricação de Peças e Acessórios para o Sistema de Direção de Veículos",
    "2945000" => "Fabricação de Material Elétrico e Eletrônico para Veículos Automotores",

    # Comércio Varejista e Atacadista de Peças e Pneus
    "4530701" => "Comércio por Atacado de Peças e Acessórios Novos para Veículos Automotores",
    "4530702" => "Comércio por Atacado de Pneumáticos e Câmaras-de-Ar",
    "4530703" => "Comércio a Varejo de Peças e Acessórios Novos para Veículos Automotores",
    "4530704" => "Comércio a Varejo de Peças e Acessórios Usados para Veículos Automotores",
    "4530705" => "Comércio a Varejo de Pneumáticos e Câmaras-de-Ar",

    # Comércio e Locação de Veículos
    "4511101" => "Comércio a Varejo de Automóveis, Camionetas e Utilitários Novos",
    "4511102" => "Comércio a Varejo de Automóveis, Camionetas e Utilitários Usados",
    "4541203" => "Comércio a Varejo de Motocicletas e Motonetas Usadas",
    "4541204" => "Comércio a Varejo de Peças e Acessórios para Motocicletas e Motonetas",
    "7711000" => "Locação de Automóveis sem Condutor",
    "4731800" => "Comércio Varejista de Combustíveis para Veículos Automotores (Postos de Gasolina)",

    # Atividades de Gestão e Serviços de Apoio Comuns
    "7020400" => "Consultoria em Gestão Empresarial",
    "7490104" => "Atividades de Intermediação e Agenciamento de Serviços e Negócios",
    "8211300" => "Serviços Combinados de Escritório e Apoio Administrativo",
    "6209100" => "Suporte Técnico, Manutenção e Serviços de TI"
  }.freeze

  def self.cnae_dictionary
    @cnae_dictionary ||= begin
      json_path = Rails.root.join("config", "cnae_dictionary.json")
      if File.exist?(json_path)
        JSON.parse(File.read(json_path))
      else
        COMMON_CNAE_DESCRIPTIONS
      end
    rescue StandardError => e
      Rails.logger.error("Error loading cnae_dictionary.json: #{e.message}")
      COMMON_CNAE_DESCRIPTIONS
    end
  end

  def self.cnae_description(code)
    return nil if code.blank?
    clean_code = code.to_s.gsub(/\D/, "")
    cnae_dictionary[clean_code].presence || COMMON_CNAE_DESCRIPTIONS[clean_code].presence
  end

  def cnae_principal_display
    clean_code = cnae_principal.to_s.gsub(/\D/, "")
    desc = Company.cnae_description(clean_code)
    if desc.present?
      "#{cnae_principal} - #{desc.to_s.titleize}"
    else
      cnae_principal
    end
  end

  def name
    trade_name.presence || legal_name
  end
  alias_method :display_name, :name


  BANKRUPT_TERMS = [
    "FALIDO", "FALIDA", "MASSA FALIDA",
    "EM LIQUIDACAO", "LIQUIDACAO EXTRAJUDICIAL",
    "RECUPERACAO JUDICIAL", "EM RECUPERACAO"
  ].freeze

  def self.bankrupt_or_in_liquidation?(name)
    return false if name.blank?
    transliterated = ActiveSupport::Inflector.transliterate(name.to_s).upcase
    BANKRUPT_TERMS.any? { |term| transliterated.include?(term) }
  end

  PUBLIC_DOMAINS = %w[
    gmail.com hotmail.com hotmail.com.br yahoo.com yahoo.com.br
    outlook.com outlook.com.br live.com icloud.com
    bol.com.br uol.com.br terra.com.br ig.com.br superig.com.br
    msn.com me.com mac.com aol.com aol.com.br r7.com zipmail.com.br
    proton.me protonmail.com zohomail.com web.de gmx.com gmx.net
    fastmail.com mail.com iol.pt sapo.pt
  ].freeze

  belongs_to :user, optional: true
  belongs_to :state
  belongs_to :city
  belongs_to :neighborhood, optional: true
  has_and_belongs_to_many :categories
  has_many :reviews, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :partners, dependent: :destroy
  has_many :outreach_logs, class_name: "CompanyOutreachLog", dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :stripe_charges, dependent: :destroy
  has_many :contact_reveal_logs, dependent: :destroy
  has_one :active_subscription, -> { where(status: "active") }, class_name: "Subscription"

  after_save :handle_approval_stripe_setup, if: :saved_change_to_claim_status?

  has_one_attached :logo
  has_one_attached :document_proof
  has_one_attached :selfie_proof
  has_many_attached :photos

  FREE_PLAN_PHOTO_LIMIT = 3


  def primary_photo_url
    if photos.attached? && photos.first.present?
      Rails.application.routes.url_helpers.rails_blob_path(photos.first, only_path: true)
    elsif logo.attached?
      Rails.application.routes.url_helpers.rails_blob_path(logo, only_path: true)
    elsif logo_url.present?
      logo_url
    end
  end

  def all_photo_urls
    urls = []
    if photos.attached?
      photos.each do |photo|
        urls << Rails.application.routes.url_helpers.rails_blob_path(photo, only_path: true)
      end
    end
    if urls.empty? && logo_display_url.present?
      urls << logo_display_url
    end
    urls
  end

  def logo_display_url
    primary_photo_url
  end

  def free_plan?
    !premium?
  end

  def premium?
    plan == "premium"
  end


  def document_proof_display_url
    if document_proof.attached?
      Rails.application.routes.url_helpers.rails_blob_path(document_proof, only_path: true)
    elsif document_proof_url.present?
      document_proof_url
    end
  end

  def selfie_proof_display_url
    if selfie_proof.attached?
      Rails.application.routes.url_helpers.rails_blob_path(selfie_proof, only_path: true)
    elsif selfie_proof_url.present?
      selfie_proof_url
    end
  end

  enum :claim_status, {
    unclaimed: "unclaimed",
    pending: "pending",
    approved: "approved"
  }, default: "unclaimed"

  default_scope { where(deleted_at: nil) }

  before_save :sync_is_claimed

  scope :visible, -> { where.not(claim_status: :pending) }
  scope :by_search_priority, -> {
    order(
      Arel.sql("CASE WHEN plan = 'premium' THEN 1 ELSE 2 END"),
      is_claimed: :desc,
      updated_at: :desc
    )
  }

  scope :lodging_cnae, -> {
    where("cnae_principal LIKE ? OR cnae_principal LIKE ? OR cnae_principal IN (?)", "4520%", "55%", CNAE_MAPPINGS.keys)
  }
  scope :automotive_cnae, -> { lodging_cnae }

  scope :with_direct_contact, -> {
    where("(companies.phone_1 IS NOT NULL AND companies.phone_1 != '') OR (companies.phone_2 IS NOT NULL AND companies.phone_2 != '') OR (companies.email IS NOT NULL AND companies.email != '')")
  }

  scope :non_accounting_email, -> {
    accounting_sql = "(LOWER(email) LIKE ? AND LOWER(email) NOT LIKE ?) OR LOWER(email) LIKE ? OR LOWER(email) LIKE ? OR LOWER(email) LIKE ? OR LOWER(email) LIKE ? OR LOWER(email) LIKE ? OR LOWER(email) LIKE ?"
    params = [ "%@%cont%", "%@contato.com.br", "%contab%", "%contador%", "%controladoria%", "%controller%", "%escritorio%", "%contasapagar%" ]
    where.not(accounting_sql, *params)
  }

  scope :eligible_for_outreach, ->(min_views: 0) {
    where(claim_status: :unclaimed)
      .where(removal_requested: false)
      .where("views_count >= ?", min_views)
      .where.not(email: [ nil, "" ])
      .lodging_cnae
      .non_accounting_email
  }


  def soft_delete!
    update!(
      deleted_at: Time.current,
      user_id: nil,
      claim_status: :unclaimed,
      is_claimed: false,
      removal_requested: false
    )
  end

  def is_claimed=(value)
    super(value)
    if ActiveRecord::Type::Boolean.new.cast(value)
      self.claim_status = "approved" if unclaimed?
    else
      self.claim_status = "unclaimed" if approved?
    end
  end

  def self.release_expired_claims!
    return unless where(claim_status: :pending).exists?

    where(claim_status: :pending, document_submitted_at: nil)
      .where("claim_expiration_date < ?", Time.current)
      .find_each do |comp|
        comp.update!(user: nil, claim_status: :unclaimed, claimed_at: nil, claim_expiration_date: nil)
      end
  end

  def self.extract_domain(email_str)
    return nil if email_str.blank?
    clean = email_str.to_s.strip.downcase
    return nil unless clean.include?("@")
    clean.split("@").last.strip
  end

  def self.find_matching_company_for(user_email)
    return nil if user_email.blank?
    clean_user_email = user_email.to_s.strip.downcase

    # 1. Exact email match (leveraging email index)
    company = where(user_id: nil).where(email: clean_user_email).first
    company ||= where(user_id: nil).where("lower(email) = ?", clean_user_email).first
    return company if company

    # 2. Domain match (excluding public email domains, filtering non-blank emails)
    domain = extract_domain(clean_user_email)
    if domain.present? && !PUBLIC_DOMAINS.include?(domain)
      company = where(user_id: nil).where.not(email: [ nil, "" ]).where("lower(email) LIKE ?", "%@#{domain}").first
      return company if company
    end

    nil
  end

  def average_rating
    return 0 if reviews.empty?
    if reviews.loaded?
      (reviews.map(&:rating).compact.sum.to_f / reviews.size).round(1)
    else
      (reviews.average(:rating) || 0).round(1)
    end
  end

  def top_review_tags(limit = 3)
    return [] if reviews.empty?
    all_tags = reviews.flat_map { |r| Array(r.tags) }.reject(&:blank?)
    all_tags.tally.sort_by { |_tag, count| -count }.map(&:first).first(limit)
  end

  def main_cnae_automotive?
    clean_code = cnae_principal.to_s.gsub(/\D/, "")
    clean_code.start_with?("4520") || CNAE_MAPPINGS.key?(clean_code)
  end
  alias_method :main_cnae_lodging?, :main_cnae_automotive?

  def has_custom_content?
    is_claimed? || photos.attached? || description.present? || (reviews.loaded? ? reviews.any? : reviews.exists?)
  end

  def indexable?
    return false if status.to_s.downcase != "ativa"
    clean_email = email.to_s.downcase.strip
    has_contact = (phone_1.present? && phone_1.gsub(/\D/, "").length >= 8) ||
                  (phone_2.present? && phone_2.gsub(/\D/, "").length >= 8) ||
                  (clean_email.present? && !%w[null n/a].include?(clean_email))
    has_partners = partners.loaded? ? partners.any? : partners.exists?
    has_address = street.present? && zip_code.present?

    return false unless has_contact || (has_partners && has_address)

    main_cnae_automotive? || has_custom_content?
  end

  scope :indexable, -> {
    clean_phone_1 = "LENGTH(replace(replace(replace(replace(replace(phone_1, '(', ''), ')', ''), '-', ''), ' ', ''), '+', '')) >= 8"
    clean_phone_2 = "LENGTH(replace(replace(replace(replace(replace(phone_2, '(', ''), ')', ''), '-', ''), ' ', ''), '+', '')) >= 8"
    clean_email = "(email IS NOT NULL AND email != '' AND lower(trim(email)) NOT IN ('null', 'n/a'))"
    has_contact = "((phone_1 IS NOT NULL AND #{clean_phone_1}) OR (phone_2 IS NOT NULL AND #{clean_phone_2}) OR #{clean_email})"

    has_partners_and_address = "(EXISTS (SELECT 1 FROM partners WHERE partners.company_id = companies.id) AND (street IS NOT NULL AND street != '') AND (zip_code IS NOT NULL AND zip_code != ''))"
    contact_or_partners = "(#{has_contact} OR #{has_partners_and_address})"

    has_photos = "EXISTS (SELECT 1 FROM active_storage_attachments WHERE active_storage_attachments.record_type = 'Company' AND active_storage_attachments.record_id = companies.id AND active_storage_attachments.name = 'photos')"
    has_reviews = "EXISTS (SELECT 1 FROM reviews WHERE reviews.company_id = companies.id)"
    has_custom = "(is_claimed = true OR (description IS NOT NULL AND description != '') OR #{has_photos} OR #{has_reviews})"

    target_cnae_list = Company::CNAE_MAPPINGS.keys.map { |c| "'#{c}'" }.join(", ")
    target_clean = "replace(replace(replace(cnae_principal, '-', ''), '/', ''), ' ', '')"
    indexable_cnae_or_custom = "(#{target_clean} IN (#{target_cnae_list}) OR cnae_principal LIKE '4520%' OR #{has_custom})"

    where(status: "Ativa")
      .where(contact_or_partners)
      .where(indexable_cnae_or_custom)
  }




  validates :cnpj, presence: true, uniqueness: true
  validates :legal_name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :status, presence: true
  validates :cnae_principal, presence: true

  before_validation :generate_slug, on: :create

  def self.clean_phone_digits(phone)
    return "" if phone.blank?
    digits = phone.to_s.gsub(/\D/, "").sub(/^0+/, "")
    digits = digits.sub(/^55/, "") if digits.length >= 12 && digits.start_with?("55")
    digits
  end

  def self.mobile_phone?(phone)
    digits = clean_phone_digits(phone)
    return false if digits.length < 10

    local_part = digits[2..]
    return false if local_part.blank?

    if digits.length == 11
      local_part.start_with?("9")
    elsif digits.length == 10
      local_part.start_with?("6", "7", "8", "9")
    else
      false
    end
  end

  def phone_1_is_whatsapp?
    return true if phone_1_whatsapp?
    Company.mobile_phone?(phone_1)
  end

  def phone_2_is_whatsapp?
    return true if phone_2_whatsapp?
    Company.mobile_phone?(phone_2)
  end

  def whatsapp_number
    if phone_1.present? && phone_1_is_whatsapp?
      phone_1
    elsif phone_2.present? && phone_2_is_whatsapp?
      phone_2
    end
  end

  def whatsapp_url(custom_message = nil)
    number = whatsapp_number
    return nil if number.blank?
    digits = Company.clean_phone_digits(number)
    name = trade_name.presence || legal_name
    msg = custom_message.presence || "Olá! Vi o perfil de #{name} no site Hospedagem Direta e gostaria de informações sobre disponibilidade e reservas."
    encoded = ERB::Util.url_encode(msg)
    "https://wa.me/55#{digits}?text=#{encoded}"
  end

  def has_whatsapp?
    whatsapp_number.present?
  end

  def create_stripe_customer!
    return stripe_customer_id if stripe_customer_id.present?

    customer = Stripe::Customer.create(
      email: email.presence || user&.email,
      name: trade_name.presence || legal_name,
      metadata: { company_id: id }
    )
    update_column(:stripe_customer_id, customer.id)
    customer.id
  rescue Stripe::StripeError => e
    Rails.logger.error("Failed to create Stripe customer for Company #{id}: #{e.message}")
    nil
  end

  def current_subscription
    active_subscription || subscriptions.order(created_at: :desc).first
  end

  def ensure_free_subscription!
    return active_subscription if active_subscription.present?

    free_product = StripeProduct.free
    free_price = free_product&.stripe_prices&.first
    return unless free_price

    subscriptions.create!(
      stripe_price: free_price,
      status: "active",
      current_period_start: Time.current
    )
  end

  def has_active_paid_subscription?
    sub = active_subscription
    return false if sub.nil? || sub.free?

    sub.active?
  end

  def can_remove_card?
    !has_active_paid_subscription?
  end

  def remove_card!
    raise "Empresa possui plano ativo pago e não pode remover o cartão" unless can_remove_card?

    if stripe_customer_id.present? && stripe_payment_method_id.present?
      begin
        Stripe::PaymentMethod.detach(stripe_payment_method_id)
      rescue Stripe::StripeError => e
        Rails.logger.warn("Stripe PaymentMethod detach warning for Company #{id}: #{e.message}")
      end
    end

    update!(card_brand: nil, card_last4: nil, stripe_payment_method_id: nil)
  end

  def update_card_details!(pm_id, brand, last4)
    create_stripe_customer! if stripe_customer_id.blank?

    if stripe_customer_id.present? && pm_id.present?
      begin
        Stripe::PaymentMethod.attach(pm_id, customer: stripe_customer_id)
        Stripe::Customer.update(stripe_customer_id, invoice_settings: { default_payment_method: pm_id })
      rescue Stripe::StripeError => e
        Rails.logger.warn("Stripe PaymentMethod attach warning for Company #{id}: #{e.message}")
      end
    end

    update!(
      stripe_payment_method_id: pm_id,
      card_brand: brand.to_s.downcase,
      card_last4: last4.to_s
    )
  end

  def photo_limit
    premium? ? 20 : FREE_PLAN_PHOTO_LIMIT
  end

  def remove_ads?
    premium?
  end

  def highlight_whatsapp?
    premium?
  end

  def top_search_priority?
    premium?
  end

  def subscribe_to_plan!(product_slug)
    product = StripeProduct.find_by!(slug: product_slug)
    price = product.stripe_prices.first
    raise "Preço não cadastrado para o produto #{product_slug}" unless price

    create_stripe_customer! if stripe_customer_id.blank?

    if price.free?
      cancel_active_subscription! if active_subscription.present?
      ensure_free_subscription!
      update!(plan: "free")
      return current_subscription
    end

    raise "Empresa precisa ter um cartão de crédito cadastrado para assinar um plano pago" if card_last4.blank? || stripe_payment_method_id.blank?

    if price.stripe_price_id.blank?
      stripe_prod = if product.stripe_product_id.present?
                      begin
                        Stripe::Product.retrieve(product.stripe_product_id)
                      rescue Stripe::StripeError
                        nil
                      end
      end

      if stripe_prod.nil?
        stripe_prod = Stripe::Product.create(name: product.name, description: product.description)
        product.update!(stripe_product_id: stripe_prod.id)
      end

      sp_price = Stripe::Price.create(
        unit_amount: (price.amount_cents * 100).to_i,
        currency: price.currency,
        recurring: { interval: price.interval },
        product: stripe_prod.id
      )
      price.update!(stripe_price_id: sp_price.id)
    end

    active_subscription.cancel!(prorate: true) if active_subscription.present? && !active_subscription.free?

    stripe_sub = Stripe::Subscription.create(
      customer: stripe_customer_id,
      items: [ { price: price.stripe_price_id } ],
      default_payment_method: stripe_payment_method_id,
      expand: [ "latest_invoice.payment_intent" ]
    )

    period_end = begin
      Time.at(stripe_sub.current_period_end)
    rescue
      1.month.from_now
    end

    sub = subscriptions.create!(
      stripe_price: price,
      stripe_subscription_id: stripe_sub.id,
      status: "active",
      current_period_start: Time.current,
      current_period_end: period_end,
      accepted_terms_at: Time.current
    )

    SubscriptionMailer.subscription_activated_email(sub).deliver_later rescue nil

    update!(plan: product.slug)
    sub
  end

  def cancel_active_subscription!
    return unless active_subscription.present?

    old_sub = active_subscription
    old_sub.cancel!(prorate: true)
    update!(plan: "free")
    ensure_free_subscription!

    SubscriptionMailer.subscription_canceled_email(old_sub).deliver_later rescue nil if old_sub.present? && !old_sub.free?
  end



  private

  def handle_approval_stripe_setup
    if approved?
      create_stripe_customer!
      ensure_free_subscription!
    end
  end

  def sync_is_claimed
    self.is_claimed = approved?
  end

  def generate_slug
    clean_cnpj = cnpj.to_s.gsub(/\D/, "")
    base_name = trade_name.presence || legal_name
    if base_name.present? && clean_cnpj.present?
      self.slug = "#{base_name} #{clean_cnpj}".parameterize
    end
  end
end
