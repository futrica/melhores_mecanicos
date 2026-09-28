require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  include ApplicationHelper

  test "clears grouped_categories_v3 cache after commit on create or update" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    begin
      Rails.cache.write("grouped_categories_v3", { "Test" => [] })
      assert_equal({ "Test" => [] }, Rails.cache.read("grouped_categories_v3"))

      Category.create!(name: "Nova Categoria Teste", slug: "nova-categoria-teste")
      assert_nil Rails.cache.read("grouped_categories_v3")
    ensure
      Rails.cache = original_cache
    end
  end
end
