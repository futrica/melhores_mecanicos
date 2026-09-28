require 'rails_helper'

RSpec.describe Contact, type: :model do
  describe "validations" do
    it "is valid with all required fields" do
      contact = Contact.new(
        name: "John Doe",
        email: "john@example.com",
        subject: "Dúvida",
        message: "Minha mensagem de teste."
      )
      expect(contact).to be_valid
    end

    it "is invalid without name" do
      contact = Contact.new(name: nil)
      expect(contact).not_to be_valid
      expect(contact.errors[:name]).to be_present
    end

    it "is invalid without email" do
      contact = Contact.new(email: nil)
      expect(contact).not_to be_valid
      expect(contact.errors[:email]).to be_present
    end

    it "is invalid with a malformed email" do
      contact = Contact.new(email: "not-an-email")
      expect(contact).not_to be_valid
      expect(contact.errors[:email]).to be_present
    end

    it "is invalid without subject" do
      contact = Contact.new(subject: nil)
      expect(contact).not_to be_valid
      expect(contact.errors[:subject]).to be_present
    end

    it "is invalid without message" do
      contact = Contact.new(message: nil)
      expect(contact).not_to be_valid
      expect(contact.errors[:message]).to be_present
    end
  end
end
