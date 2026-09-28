require "test_helper"

class ClaimsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  setup do
    @company = companies(:ze)
  end

  test "unauthenticated user can access claim page" do
    get new_claim_url
    assert_response :success
  end

  test "user with company role but no attached company can access claim page" do
    user = User.create!(
      email: "new_company_owner@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "company",
      terms_accepted: "1",
      confirmed_at: Time.current
    )
    sign_in user

    get new_claim_url
    assert_response :success
  end

  test "user with attached company is redirected away from claim page" do
    user = User.create!(
      email: "existing_owner@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "company",
      terms_accepted: "1",
      confirmed_at: Time.current
    )
    @company.update!(user: user)
    sign_in user

    get new_claim_url
    assert_redirected_to app_root_url
    follow_redirect!
    assert_select "div", text: /Você já possui uma empresa reivindicada/
  end
end
