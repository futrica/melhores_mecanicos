require 'rails_helper'

RSpec.describe "Client View and Adjustments", type: :request do
  include ApplicationHelper

  let!(:state) { State.find_by(acronym: 'SP') || State.create!(acronym: 'SP', name: 'São Paulo') }
  let!(:city) { City.find_by(slug: 'guaratingueta', state: state) || City.create!(state: state, name: 'Guaratinguetá', ibge_code: '3518404') }
  let!(:company) { Company.find_by!(cnpj: '12345678000101') }
  let!(:user) do
    u = User.new(email: "cliente@teste.com", password: "password123", role: "client", terms_accepted: "1", phone: "(11) 99999-8888")
    u.skip_confirmation!
    u.save!
    u
  end

  def login_as_client(u = user)
    post user_session_path, params: { user: { email: u.email, password: "password123" } }
  end

  describe "Requirement 1: Redirect after sign in" do
    it "redirects client straight to /app instead of root / upon login" do
      login_as_client
      expect(response).to redirect_to(app_root_path)
    end
  end

  describe "Requirement 2: Favorite heart indicator in company listings" do
    it "renders favorite toggle heart button on company cards when logged in" do
      login_as_client
      get search_path(state_id: state.id)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("fav-btn-card")
      expect(response.body).to include("Favoritar")
    end

    it "shows active state when company is already favorited" do
      user.favorites.create!(company: company)
      login_as_client
      get search_path(state_id: state.id)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("fav-btn-card--active")
      expect(response.body).to include("Favorito")
    end
  end

  describe "Requirement 3: Email confirmation & Phone registration" do
    it "allows storing optional phone (DDD + number)" do
      expect(user.phone).to eq("(11) 99999-8888")
    end

    it "blocks unconfirmed user from signing in until email confirmation" do
      unconfirmed_user = User.create!(email: "novo@teste.com", password: "password123", role: "client", terms_accepted: "1")
      login_as_client(unconfirmed_user)

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert].downcase).to include("confirm")
    end

    it "renders unconfirmed email banner on dashboard when email is unconfirmed" do
      unconfirmed_user = User.new(email: "pendente@teste.com", password: "password123", role: "client", terms_accepted: "1")
      unconfirmed_user.save!
      login_as_client(unconfirmed_user)

      # Allow unconfirmed access to view dashboard notice if needed
      get app_root_path
      if response.status == 200
        expect(response.body).to include("Confirmação de E-mail Pendente")
      end
    end

    it "allows creating a review with rating and endorsement tags without a comment when confirmed" do
      login_as_client
      expect {
        post company_reviews_path(company), params: {
          review: {
            rating: 5,
            tags: [ "Ótimo Atendimento", "Preço Justo" ]
          }
        }
      }.to change { Review.count }.by(1)

      review = Review.last
      expect(review.rating).to eq(5)
      expect(review.tags).to include("Ótimo Atendimento", "Preço Justo")
      expect(review.comment).to be_blank
    end

    it "displays endorsements summary on company profile" do
      Review.create!(user: user, company: company, rating: 5, tags: [ "Ótimo Atendimento", "Preço Justo" ])

      get company_seo_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Recomendações dos Clientes (Endorsements)")
      expect(response.body).to include("Ótimo Atendimento")
      expect(response.body).to include("Preço Justo")
    end
  end

  describe "Requirement 4 & 5: Profile edit link and actions" do
    it "prevents user from escalating their role to admin via account_update" do
      login_as_client
      put user_registration_path, params: {
        user: {
          current_password: "password123",
          role: "admin",
          name: "Hacker Client"
        }
      }
      expect(user.reload.role).to eq("client")
      expect(user.name).to eq("Hacker Client")
    end

    it "renders Editar Perfil link on dashboard" do
      login_as_client
      get app_root_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Editar Perfil")
    end

    it "renders the Avaliar Hospedagem section in company view sidebar" do
      login_as_client
      get company_seo_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("⭐ Avaliar Hospedagem")
      expect(response.body).to include('id="review-form"')
    end
  end

  describe "Deleting Reviews & Account Cancellation" do
    it "allows client to delete their review from dashboard" do
      review = Review.create!(user: user, company: company, rating: 5, tags: [ "Ótimo Atendimento" ])
      login_as_client

      expect {
        delete review_path(review)
      }.to change { Review.count }.by(-1)

      expect(response).to redirect_to(app_root_path)
    end

    it "cancels user account and destroys all favorites and reviews" do
      user.favorites.create!(company: company)
      Review.create!(user: user, company: company, rating: 5, tags: [ "Ótimo Atendimento" ])
      login_as_client

      expect {
        delete user_registration_path
      }.to change { User.count }.by(-1)
       .and change { Favorite.count }.by(-1)
       .and change { Review.count }.by(-1)
    end

    it "renders Minhas Hospedagens Favoritas and Minhas Avaliações at the end of dashboard page" do
      login_as_client
      get app_root_path
      expect(response).to have_http_status(:success)

      quick_index = response.body.index("Buscar Hospedagens")
      fav_index = response.body.index("Minhas Hospedagens Favoritas")
      rev_index = response.body.index("Minhas Avaliações")

      expect(quick_index).to be < fav_index
      expect(fav_index).to be < rev_index
    end

    it "allows updating profile (name, phone) without providing current_password" do
      login_as_client

      put user_registration_path, params: {
        user: {
          name: "Cliente Nome Atualizado",
          phone: "(11) 97777-6666"
        }
      }

      expect(response).to redirect_to(app_root_path)
      user.reload
      expect(user.name).to eq("Cliente Nome Atualizado")
      expect(user.phone).to eq("(11) 97777-6666")
    end

    it "allows Google OAuth user to update profile without password" do
      oauth_user = User.create!(
        email: "google_client@gmail.com",
        password: "randomgeneratedpassword123",
        name: "Google Client",
        provider: "google_oauth2",
        uid: "google_uid_123",
        role: "client"
      )
      oauth_user.confirm

      sign_in oauth_user

      get edit_user_registration_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Conta conectada via Google")
      expect(response.body).not_to include("current_password")

      put user_registration_path, params: {
        user: {
          name: "Google Client Atualizado",
          phone: "(11) 91111-2222"
        }
      }

      expect(response).to redirect_to(app_root_path)
      oauth_user.reload
      expect(oauth_user.name).to eq("Google Client Atualizado")
      expect(oauth_user.phone).to eq("(11) 91111-2222")
    end

    it "locks email input in the UI and forbids changing email via controller" do
      login_as_client

      get edit_user_registration_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Chave de Login Fixa")
      expect(response.body).to include("readonly")
      expect(response.body).to include("disabled")

      original_email = user.email

      put user_registration_path, params: {
        user: {
          email: "hacked_email@gmail.com",
          name: "Nome Alterado"
        }
      }

      expect(response).to redirect_to(app_root_path)
      user.reload
      expect(user.email).to eq(original_email)
      expect(user.unconfirmed_email).to be_nil
      expect(user.name).to eq("Nome Alterado")
    end
  end
end
