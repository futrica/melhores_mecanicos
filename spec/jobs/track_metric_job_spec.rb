require "rails_helper"

RSpec.describe TrackMetricJob, type: :job do
  describe "#perform" do
    let(:company) { Company.first || Company.create!(trade_name: "Test Co", cnpj: "12345678000101", status: "Ativa", state: State.first_or_create!(name: "SP", slug: "sp", uf: "SP"), city: City.first_or_create!(name: "Test City", slug: "test-city", state: State.first_or_create!(name: "SP", slug: "sp", uf: "SP"))) }
    let(:city) { company.city }

    it "increments views_count for Company asynchronously" do
      expect {
        TrackMetricJob.new.perform("Company", company.id, :views_count)
      }.to change { company.reload.views_count }.by(1)
    end

    it "increments searches_count for City asynchronously" do
      expect {
        TrackMetricJob.new.perform("City", city.id, :searches_count)
      }.to change { city.reload.searches_count }.by(1)
    end

    it "handles missing records gracefully without throwing error" do
      expect {
        TrackMetricJob.new.perform("Company", 9999999, :views_count)
      }.not_to raise_error
    end
  end
end
