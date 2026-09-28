class Review < ApplicationRecord
  belongs_to :user
  belongs_to :company, touch: true

  before_validation :set_reviewer_name

  POSITIVE_TAGS = [
    "Bom Anfitrião",
    "Limpeza Impecável",
    "Excelente Localização",
    "Ótimo Custo-Benefício",
    "Acomodação Confortável",
    "Café da Manhã Incrível",
    "Atendimento Nota 10",
    "Ambiente Silencioso",
    "Wi-Fi Rápido",
    "Estacionamento Seguro"
  ].freeze

  LEGACY_TAGS = [
    "Ótimo Atendimento",
    "Preço Justo",
    "Entrega Rápida",
    "Produtos de Qualidade",
    "Variedade de Produtos",
    "Fácil de Encontrar",
    "Equipe Prestativa",
    "Facilidade de Pagamento",
    "Pontualidade",
    "Estoque Completo",
    "Atendimento Ruim",
    "Preço Alto",
    "Entrega Demorada",
    "Produto com Defeito",
    "Falta de Estoque",
    "Localização Difícil",
    "Falta de Organização"
  ].freeze

  ALLOWED_TAGS = (POSITIVE_TAGS + LEGACY_TAGS).freeze

  TAG_ICONS = {
    "Bom Anfitrião" => "🤝",
    "Limpeza Impecável" => "🧹",
    "Excelente Localização" => "📍",
    "Ótimo Custo-Benefício" => "💰",
    "Acomodação Confortável" => "🛌",
    "Café da Manhã Incrível" => "☕",
    "Atendimento Nota 10" => "⭐",
    "Ambiente Silencioso" => "🔇",
    "Wi-Fi Rápido" => "📶",
    "Estacionamento Seguro" => "🚗",
    # Legacy tags support
    "Ótimo Atendimento" => "🤝",
    "Preço Justo" => "💰",
    "Entrega Rápida" => "⚡",
    "Produtos de Qualidade" => "🧱",
    "Variedade de Produtos" => "🛍️",
    "Fácil de Encontrar" => "📍",
    "Equipe Prestativa" => "👷",
    "Facilidade de Pagamento" => "💳",
    "Pontualidade" => "⏰",
    "Estoque Completo" => "📦",
    "Atendimento Ruim" => "👎",
    "Preço Alto" => "💸",
    "Entrega Demorada" => "⏳",
    "Produto com Defeito" => "⚠️",
    "Falta de Estoque" => "❌",
    "Localização Difícil" => "🗺️",
    "Falta de Organização" => "🧹"
  }.freeze

  serialize :tags, coder: JSON

  validates :reviewer_name, presence: true
  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :user_id, uniqueness: { scope: :company_id, message: "já enviou uma avaliação para esta hospedagem." }
  before_validation :clean_tags
  validate :tags_must_be_allowed

  def self.tag_icon(tag)
    TAG_ICONS[tag] || "👍"
  end

  def positive_tags
    Array(tags).select { |t| POSITIVE_TAGS.include?(t) || ALLOWED_TAGS[0..9].include?(t) }
  end

  def negative_tags
    Array(tags).select { |t| LEGACY_TAGS.include?(t) && !POSITIVE_TAGS.include?(t) }
  end

  private

  def set_reviewer_name
    if user.present?
      self.reviewer_name = user.name.presence || user.email.split("@").first.titleize
    end
  end

  def clean_tags
    self.tags = Array(tags).reject(&:blank?) if tags.present?
  end

  def tags_must_be_allowed
    return if tags.blank?

    invalid_tags = Array(tags) - ALLOWED_TAGS
    if invalid_tags.any?
      errors.add(:tags, "contém opções inválidas: #{invalid_tags.join(', ')}")
    end
  end
end
