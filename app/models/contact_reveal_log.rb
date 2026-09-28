class ContactRevealLog < ApplicationRecord
  belongs_to :company
  belongs_to :user, optional: true

  validates :contact_type, presence: true
end
