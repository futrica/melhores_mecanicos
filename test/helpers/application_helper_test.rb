require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  setup do
    @orig_pub_id = ENV["ADSENSE_PUBLISHER_ID"]
    @orig_slot_id = ENV["ADSENSE_DEFAULT_SLOT_ID"]
    @orig_ga_id = ENV["GOOGLE_ANALYTICS_ID"]
  end

  teardown do
    ENV["ADSENSE_PUBLISHER_ID"] = @orig_pub_id
    ENV["ADSENSE_DEFAULT_SLOT_ID"] = @orig_slot_id
    ENV["GOOGLE_ANALYTICS_ID"] = @orig_ga_id
  end

  def with_rails_env(env_name)
    old_env = Rails.env
    Rails.env = env_name
    yield
  ensure
    Rails.env = old_env
  end

  test "adsense_script_tag returns nil when publisher id is missing" do
    ENV["ADSENSE_PUBLISHER_ID"] = nil
    assert_nil adsense_script_tag
  end

  test "adsense_script_tag returns script tag when publisher id is present" do
    ENV["ADSENSE_PUBLISHER_ID"] = "ca-pub-1234567890123456"
    html = adsense_script_tag
    assert_match(/pagead2.googlesyndication.com/, html)
    assert_match(/ca-pub-1234567890123456/, html)
  end

  test "adsense_ad_tag returns placeholder in development when publisher id is missing" do
    ENV["ADSENSE_PUBLISHER_ID"] = nil
    html = adsense_ad_tag(:top)
    assert_match(/adsense-placeholder-box/, html)
    assert_match(/Banner Horizontal Superior \(Dev Mode\)/, html)
  end

  test "adsense_ad_tag returns ins tag when publisher id and slot id are present" do
    ENV["ADSENSE_PUBLISHER_ID"] = "ca-pub-1234567890123456"
    ENV["ADSENSE_DEFAULT_SLOT_ID"] = "9876543210"
    html = adsense_ad_tag(:sidebar)
    assert_match(/adsbygoogle/, html)
    assert_match(/ca-pub-1234567890123456/, html)
    assert_match(/9876543210/, html)
  end

  test "google_analytics_tag returns nil outside of production environment" do
    ENV["GOOGLE_ANALYTICS_ID"] = "G-1234567890"
    assert_nil google_analytics_tag
  end

  test "google_analytics_tag renders correct GA script tag in production environment" do
    ENV["GOOGLE_ANALYTICS_ID"] = "G-1234567890"
    with_rails_env("production") do
      html = google_analytics_tag
      assert_match(/googletagmanager.com\/gtag\/js\?id=G-1234567890/, html)
      assert_match(/gtag\('config', 'G-1234567890'\);/, html)
    end
  end

  test "google_analytics_tag returns nil in production if GOOGLE_ANALYTICS_ID is missing" do
    ENV["GOOGLE_ANALYTICS_ID"] = nil
    with_rails_env("production") do
      assert_nil google_analytics_tag
    end
  end
end
