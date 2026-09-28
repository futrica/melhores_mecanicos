require 'rails_helper'

RSpec.describe SitemapGenerator do
  let!(:state) { State.find_or_create_by!(acronym: "SP") { |s| s.name = "São Paulo" } }
  let!(:city) { City.find_or_create_by!(ibge_code: "3550308", state: state) { |c| c.name = "São Paulo" } }

  describe '.generate!' do
    it 'creates sitemap_index.xml and sub-sitemaps in specified folder' do
      Dir.mktmpdir do |dir|
        test_dir = Pathname.new(dir)
        allow(described_class).to receive(:sitemap_dir).and_return(test_dir.join("sitemaps"))
        allow(described_class).to receive(:index_path).and_return(test_dir.join("sitemap_index.xml"))

        described_class.generate!(base_url: "http://test.host", skip_existing: false)

        index_path = test_dir.join("sitemap_index.xml")
        expect(File.exist?(index_path)).to be true
        expect(File.read(index_path)).to include("sitemapindex")
        expect(File.read(index_path)).to include("sitemaps/sitemap_locations.xml")
      end
    end
  end
end
