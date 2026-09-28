class CompanyEmailOptOut < ApplicationRecord
  belongs_to :company, optional: true

  validates :email, presence: true
  validates :token, presence: true, uniqueness: true

  before_validation :normalize_email
  before_validation :generate_token, on: :create
  before_validation :set_unsubscribed_at

  REASONS = {
    "not_owner" => "Não sou o proprietário / não represento esta empresa",
    "already_claimed" => "Já atualizei / reivindiquei meu perfil",
    "not_interested" => "Não tenho interesse no momento",
    "too_many_emails" => "Recebo muitos e-mails",
    "other" => "Outro motivo"
  }.freeze

  scope :unsubscribed, -> { where.not(unsubscribed_at: nil) }

  def self.opted_out?(email)
    return false if email.blank?
    unsubscribed.where("lower(email) = ?", email.to_s.strip.downcase).exists?
  end

  def self.find_or_create_by_token_or_email!(email:, token: nil, company_id: nil, reason: nil, feedback: nil, unsubscribed: false)
    clean_email = email.to_s.strip.downcase
    record = find_by(token: token) if token.present?
    record ||= find_by("lower(email) = ?", clean_email)
    record ||= new(email: clean_email)

    record.company_id = company_id if company_id.present?
    record.reason = reason if reason.present?
    record.feedback = feedback if feedback.present?
    if unsubscribed || reason.present? || feedback.present?
      record.unsubscribed_at ||= Time.current
    end
    record.save!
    record
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(24)
  end

  def set_unsubscribed_at
    if reason.present? || feedback.present?
      self.unsubscribed_at ||= Time.current
    end
  end
end
