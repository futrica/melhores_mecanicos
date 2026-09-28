module App
  module Admin
    class DashboardController < BaseController
      def index
        @total_users = User.count
        @client_users_count = User.where(role: "client").count
        @admin_users_count = User.where(role: "admin").count
        @company_users_count = User.where(role: "company").count

        @total_contacts = Contact.count

        @pending_companies_count = Company.where(claim_status: :pending).or(Company.where(removal_requested: true)).count
        @removal_requested_companies_count = Company.where(removal_requested: true).count

        @recent_users = User.order(created_at: :desc).limit(5)
        @recent_contacts = Contact.order(created_at: :desc).limit(5)
      end
    end
  end
end
