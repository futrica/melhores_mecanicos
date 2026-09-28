class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  enum :role, {
    admin: "admin",
    client: "client",
    company: "company"
  }, default: "client"

  has_one :company, dependent: :nullify
  has_many :favorites, dependent: :destroy
  has_many :favorited_companies, through: :favorites, source: :company
  has_many :reviews, dependent: :destroy
  has_many :reviewed_companies, through: :reviews, source: :company

  def favorited?(company)
    return false if company.nil?
    favorites.exists?(company_id: company.id)
  end

  def reviewed?(company)
    return false if company.nil?
    reviews.exists?(company_id: company.id)
  end


  attr_accessor :terms_accepted

  validates :role, presence: true, inclusion: { in: roles.keys }
  validates :terms_accepted, acceptance: true, allow_nil: false, on: :create, unless: -> { provider.present? }
  validates :phone, format: { with: /\A(?:\(?\d{2}\)?\s?)?\d{4,5}-?\d{4}\z/, message: "deve ser um telefone válido com DDD (ex: (11) 99999-8888)" }, allow_blank: true

  before_validation :sanitize_phone
  before_validation :set_default_name, on: :create
  before_create :set_terms_accepted_at, unless: -> { provider.present? }
  before_create :auto_confirm_admin

  after_commit :send_welcome_email_if_confirmed, on: [ :create, :update ]

  def after_confirmation
    associate_company_if_exists
    send_welcome_email!
  end

  def confirmed?
    super || admin?
  end

  def send_welcome_email!
    return if admin?
    return unless confirmed?
    return if welcome_email_sent_at.present?

    if company?
      UserMailer.company_welcome(self).deliver_later
    else
      UserMailer.client_welcome(self).deliver_later
    end

    update_column(:welcome_email_sent_at, Time.current)
  end

  def send_welcome_email_if_confirmed
    send_welcome_email! if confirmed?
  end

  def self.from_omniauth(auth)
    # Busca pelo provider/uid
    user = find_by(provider: auth.provider, uid: auth.uid)

    # Se não achar por provider/uid, busca por email
    user ||= find_by(email: auth.info.email)

    if user
      user.update(provider: auth.provider, uid: auth.uid, name: auth.info.name) if user.provider.blank?
      user.confirm unless user.confirmed?
    else
      user = new(
        email: auth.info.email,
        password: Devise.friendly_token[0, 20],
        provider: auth.provider,
        uid: auth.uid,
        name: auth.info.name,
        role: "client"
      )
      user.skip_confirmation!
      user.save!
    end

    user.associate_company_if_exists
    user
  end

  def convert_to_company!
    return if company? || admin?

    transaction do
      favorites.destroy_all
      reviews.destroy_all
      update!(role: "company", welcome_email_sent_at: nil)
    end
    send_welcome_email!
  end

  def associate_company_if_exists
    return unless confirmed?
    return if company.present? # Já possui empresa associada

    matching_company = Company.find_matching_company_for(email)
    return unless matching_company

    convert_to_company!
    matching_company.update!(user: self, is_claimed: true, claim_status: :approved)
  end

  def sanitize_phone
    return if phone.blank?

    digits = phone.to_s.gsub(/\D/, "")
    digits = digits.sub(/\A55/, "") if digits.length == 12 || digits.length == 13

    if digits.length == 11
      self.phone = "(#{digits[0..1]}) #{digits[2..6]}-#{digits[7..10]}"
    elsif digits.length == 10
      self.phone = "(#{digits[0..1]}) #{digits[2..5]}-#{digits[6..9]}"
    end
  end

  def set_default_name
    self.name ||= email.split("@").first.gsub(".", " ").gsub("_", " ").titleize if email.present?
  end

  def set_terms_accepted_at
    self.terms_accepted_at = Time.current if terms_accepted == "1" || terms_accepted == true
  end

  def auto_confirm_admin
    self.confirmed_at ||= Time.current if admin?
  end
end
