require "test_helper"

class CompaniesControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    company = companies(:ze)
    get company_page_url(state_slug: company.state.slug, city_slug: company.city.slug, neighborhood_slug: company.neighborhood.slug, slug: company.slug)
    assert_response :success
  end

  test "should block heavy scrapers with 403 forbidden and allow AI search bots" do
    company = companies(:ze)
    url = company_page_url(state_slug: company.state.slug, city_slug: company.city.slug, neighborhood_slug: company.neighborhood.slug, slug: company.slug)

    get url, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (compatible; Bytespider/1.0)" }
    assert_response :forbidden

    get url, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (compatible; CCBot/2.0)" }
    assert_response :forbidden

    get url, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (compatible; GPTBot/1.0)" }
    assert_response :success

    get url, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (compatible; YandexBot/3.0)" }
    assert_response :success
  end

  test "should 301 redirect when old slug with valid CNPJ is requested" do
    company = companies(:ze)
    old_url = company_page_url(state_slug: company.state.slug, city_slug: company.city.slug, neighborhood_slug: company.neighborhood.slug, slug: "old-name-#{company.cnpj}")
    get old_url
    assert_response :moved_permanently
    assert_redirected_to company_page_url(state_slug: company.state.slug, city_slug: company.city.slug, neighborhood_slug: company.neighborhood.slug, slug: company.slug)
  end

  test "should return 410 gone when requested CNPJ does not exist in DB" do
    get "/sp/sao-paulo/centro/empresa-removida-99999999000199"
    assert_response :gone
  end
end
