module App
  module Admin
    class ContactsController < BaseController
      def index
        @contacts = Contact.order(created_at: :desc)

        if params[:q].present?
          query = "%#{params[:q].to_s.strip.downcase}%"
          @contacts = @contacts.where("LOWER(name) LIKE ? OR LOWER(email) LIKE ? OR LOWER(subject) LIKE ? OR LOWER(message) LIKE ?", query, query, query, query)
        end

        @pagy, @contacts = pagy(:offset, @contacts, limit: 15)
      end

      def show
        @contact = Contact.find(params[:id])
      end
    end
  end
end
