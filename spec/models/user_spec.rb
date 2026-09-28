require 'rails_helper'

RSpec.describe User, type: :model do
  describe "validations & defaults" do
    it "defaults role to client" do
      user = User.new
      expect(user.role).to eq("client")
    end

    it "allows valid roles" do
      %w[admin client company].each do |role|
        user = User.new(role: role)
        user.valid?
        expect(user.errors[:role]).to be_empty
      end
    end

    it "validates terms_accepted on create for regular signups" do
      user = User.new(email: "test@example.com", password: "password", password_confirmation: "password")
      expect(user.valid?).to be_falsey
      expect(user.errors[:terms_accepted]).to be_present

      user.terms_accepted = "1"
      expect(user.valid?).to be_truthy
    end

    it "does not validate terms_accepted if registering via omniauth (provider present)" do
      user = User.new(email: "test@example.com", password: "password", password_confirmation: "password", provider: "google_oauth2", uid: "123")
      expect(user.valid?).to be_truthy
    end

    it "sanitizes and formats phone numbers automatically" do
      user = User.new(phone: "11999998888")
      user.valid?
      expect(user.phone).to eq("(11) 99999-8888")

      user2 = User.new(phone: "5511999998888")
      user2.valid?
      expect(user2.phone).to eq("(11) 99999-8888")
    end
  end

  describe "callbacks" do
    it "sets a default name based on the email" do
      user = User.create!(email: "john.doe@example.com", password: "password", password_confirmation: "password", terms_accepted: "1")
      expect(user.name).to eq("John Doe")
    end

    it "sets terms_accepted_at if terms are accepted" do
      user = User.create!(email: "john.doe@example.com", password: "password", password_confirmation: "password", terms_accepted: "1")
      expect(user.terms_accepted_at).to be_present
    end
  end

  describe ".from_omniauth" do
    let(:auth) do
      double(
        provider: "google_oauth2",
        uid: "123456",
        info: double(email: "oauth@example.com", name: "OAuth User")
      )
    end

    it "creates a new user if one does not exist" do
      expect {
        user = User.from_omniauth(auth)
        expect(user.email).to eq("oauth@example.com")
        expect(user.name).to eq("OAuth User")
        expect(user.provider).to eq("google_oauth2")
        expect(user.uid).to eq("123456")
        expect(user.role).to eq("client")
      }.to change(User, :count).by(1)
    end

    it "returns the existing user matched by provider and uid" do
      existing_user = User.create!(
        email: "oauth@example.com",
        password: "password",
        provider: "google_oauth2",
        uid: "123456",
        name: "OAuth User",
        terms_accepted: "1"
      )

      expect {
        user = User.from_omniauth(auth)
        expect(user).to eq(existing_user)
      }.not_to change(User, :count)
    end

    it "links the provider and uid to an existing user with the same email" do
      existing_user = User.create!(
        email: "oauth@example.com",
        password: "password",
        name: "OAuth User",
        terms_accepted: "1"
      )

      expect {
        user = User.from_omniauth(auth)
        expect(user).to eq(existing_user)
        expect(user.reload.provider).to eq("google_oauth2")
        expect(user.uid).to eq("123456")
      }.not_to change(User, :count)
    end

    it "auto-associates matching company by domain on Google OAuth sign in" do
      state = State.find_by(acronym: 'SP') || State.create!(acronym: 'SP', name: 'São Paulo')
      city = City.find_by(slug: 'guaratingueta', state: state) || City.create!(state: state, name: 'Guaratinguetá', ibge_code: '3518404')
      company = Company.create!(
        state: state, city: city, cnpj: '77665544000199',
        legal_name: 'Pousada do João LTDA', email: 'contato@pousadadojoao.com.br',
        cnae_principal: '5510801', status: 'Ativa'
      )

      google_auth = double(
        provider: "google_oauth2",
        uid: "998877",
        info: double(email: "joao@pousadadojoao.com.br", name: "João Silva")
      )

      user = User.from_omniauth(google_auth)

      expect(user.role).to eq("company")
      expect(user.company).to eq(company)
      expect(company.reload.is_claimed).to be_truthy
      expect(company.claim_status).to eq("approved")
    end
  end

  describe "#associate_company_if_exists" do
    it "associates matching company when user confirms email" do
      state = State.find_by(acronym: 'SP') || State.create!(acronym: 'SP', name: 'São Paulo')
      city = City.find_by(slug: 'guaratingueta', state: state) || City.create!(state: state, name: 'Guaratinguetá', ibge_code: '3518404')
      company = Company.create!(
        state: state, city: city, cnpj: '77665544000198',
        legal_name: 'Pousada e Hotel LTDA', email: 'atendimento@pousadaehotel.com.br',
        cnae_principal: '5510801', status: 'Ativa'
      )

      user = User.create!(
        email: "diretoria@pousadaehotel.com.br",
        password: "password",
        password_confirmation: "password",
        terms_accepted: "1"
      )

      user.confirm
      expect(user.reload.role).to eq("company")
      expect(user.company).to eq(company)
      expect(company.reload.is_claimed).to be_truthy
    end
  end

  describe "#convert_to_company!" do
    it "converts role to company and cleans up favorites and reviews" do
      state = State.find_by(acronym: 'SP') || State.create!(acronym: 'SP', name: 'São Paulo')
      city = City.find_by(slug: 'guaratingueta', state: state) || City.create!(state: state, name: 'Guaratinguetá', ibge_code: '3518404')
      company = Company.create!(
        state: state, city: city, cnpj: '11223344000155',
        legal_name: 'Hotel Teste LTDA', email: 'hotel@teste.com',
        cnae_principal: '5510801', status: 'Ativa'
      )

      user = User.create!(
        email: "hospede@teste.com",
        password: "password123",
        password_confirmation: "password123",
        terms_accepted: "1",
        role: "client"
      )

      user.favorites.create!(company: company)
      user.reviews.create!(company: company, rating: 5, comment: "Excelente!")

      expect(user.favorites.count).to eq(1)
      expect(user.reviews.count).to eq(1)

      user.convert_to_company!

      expect(user.reload.role).to eq("company")
      expect(user.favorites.count).to eq(0)
      expect(user.reviews.count).to eq(0)
    end
  end

  describe "#send_welcome_email!" do
    it "enqueues client welcome email when a client user confirms" do
      user = User.create!(
        email: "hospede_welcome@teste.com",
        password: "password123",
        password_confirmation: "password123",
        terms_accepted: "1",
        role: "client"
      )

      expect {
        user.confirm
      }.to have_enqueued_mail(UserMailer, :client_welcome).with(user)
    end

    it "enqueues company welcome email when user converts to company" do
      user = User.create!(
        email: "proprietario_welcome@teste.com",
        password: "password123",
        password_confirmation: "password123",
        terms_accepted: "1",
        role: "client"
      )
      user.confirm

      expect {
        user.convert_to_company!
      }.to have_enqueued_mail(UserMailer, :company_welcome).with(user)
    end
  end
end
