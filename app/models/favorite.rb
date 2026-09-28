class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :company

  validates :user_id, uniqueness: { scope: :company_id }
  validate :user_must_be_client

  private

  def user_must_be_client
    if user && !user.client?
      errors.add(:user, "deve ser um cliente para favoritar hospedagens")
    end
  end
end
