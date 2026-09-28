require "test_helper"

class LocationsControllerTest < ActionDispatch::IntegrationTest
  test "should get city" do
    get city_page_url(state_slug: states(:sp).slug, city_slug: cities(:guara).slug)
    assert_response :success
  end

  test "should get neighborhood with rating sorting" do
    get neighborhood_page_url(state_slug: states(:sp).slug, city_slug: cities(:guara).slug, neighborhood_slug: neighborhoods(:centro_guara).slug), params: { sort: "rating" }
    assert_response :success
  end

  test "should get neighborhood page" do
    get neighborhood_page_url(state_slug: states(:sp).slug, city_slug: cities(:guara).slug, neighborhood_slug: neighborhoods(:centro_guara).slug)
    assert_response :success
  end
end
