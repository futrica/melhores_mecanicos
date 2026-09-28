class CompanyOutreachLog < ApplicationRecord
  belongs_to :company

  validates :email, presence: true
  validates :campaign_name, presence: true
  validates :sent_at, presence: true

  scope :recent, -> { order(sent_at: :desc) }
  scope :successful, -> { where(status: "sent") }
  scope :failed, -> { where(status: "failed") }
  scope :clicked, -> { where.not(clicked_at: nil) }

  def record_click!
    update!(clicked_at: Time.current) if clicked_at.nil?
  end

  def self.recently_sent?(company_id:, email:, campaign_name: "profile_presentation", cooldown_days: 60)
    cutoff = cooldown_days.days.ago
    clean_email = email.to_s.strip.downcase

    where(campaign_name: campaign_name)
      .where("sent_at >= ?", cutoff)
      .where("company_id = ? OR lower(email) = ?", company_id, clean_email)
      .exists?
  end
end
