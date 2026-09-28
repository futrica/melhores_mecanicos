module App
  module Admin
    class TopCompaniesController < BaseController
      def index
        @scope = Company.unscoped.where(deleted_at: nil).includes(:state, :city, :outreach_logs)

        # Search query
        if params[:q].present?
          query = "%#{params[:q].to_s.strip.downcase}%"
          @scope = @scope.joins(:city)
                         .where("LOWER(companies.trade_name) LIKE ? OR LOWER(companies.legal_name) LIKE ? OR companies.cnpj LIKE ? OR LOWER(cities.name) LIKE ?", query, query, query, query)
        end

        # City filter
        if params[:city_id].present?
          @scope = @scope.where(city_id: params[:city_id])
        end

        # Minimum views filter
        if params[:min_views].present? && params[:min_views].to_i > 0
          @scope = @scope.where("views_count >= ?", params[:min_views].to_i)
        end

        # Outreach Email status filter
        case params[:email_status]
        when "not_sent"
          sent_company_ids = CompanyOutreachLog.where(status: "sent").select(:company_id)
          @scope = @scope.where.not(id: sent_company_ids)
        when "sent"
          sent_company_ids = CompanyOutreachLog.where(status: "sent").select(:company_id)
          @scope = @scope.where(id: sent_company_ids)
        when "opt_out"
          opt_out_emails = CompanyEmailOptOut.unsubscribed.select(:email)
          @scope = @scope.where("LOWER(companies.email) IN (?)", opt_out_emails)
        end

        # Order by accesses / views count descending
        @scope = @scope.order(views_count: :desc, id: :asc)

        # Summary of top cities by total company accesses/views
        @top_cities = City.joins(:companies)
                          .where(companies: { deleted_at: nil })
                          .joins(:state)
                          .select("cities.id, cities.name, states.acronym as state_acronym, SUM(companies.views_count) as total_views, COUNT(companies.id) as companies_count")
                          .group("cities.id, cities.name, states.acronym")
                          .order("total_views DESC")
                          .limit(8)

        @pagy, @companies = pagy(:offset, @scope, limit: 25)
      end

      def show
        @company = Company.unscoped.includes(:state, :city, :neighborhood, :user, :categories, :reviews, :outreach_logs).find(params[:id])
        @outreach_logs = @company.outreach_logs.order(sent_at: :desc)

        email_clean = @company.email.to_s.strip.downcase
        @opt_out = CompanyEmailOptOut.unsubscribed.find_by("lower(email) = ?", email_clean) if email_clean.present?

        # Email diagnosis
        if email_clean.blank?
          @email_status = :no_email
          @can_send_email = false
          @send_disabled_reason = "Empresa não possui e-mail cadastrado."
        elsif @opt_out.present?
          @email_status = :opt_out
          @can_send_email = false
          reason_text = CompanyEmailOptOut::REASONS[@opt_out.reason] || @opt_out.reason || "Solicitação de descadastramento / cancelamento de e-mail"
          @send_disabled_reason = "O proprietário solicitou o cancelamento do recebimento de e-mails (Opt-Out / Spam). Motivo informado: #{reason_text}."
        elsif !EmailValidatorService.valid_format?(email_clean)
          @email_status = :invalid_format
          @can_send_email = false
          @send_disabled_reason = "Formato de e-mail inválido (sintaxe do endereço incorreta)."
        elsif !EmailValidatorService.has_valid_mx?(email_clean)
          @email_status = :invalid_mx
          @can_send_email = false
          @send_disabled_reason = "Domínio de e-mail sem registros MX válidos na consulta DNS (alto risco de rejeição/bounce)."
        else
          @email_status = :valid
          @can_send_email = true
          @send_disabled_reason = nil
        end
      end

      def send_email
        @company = Company.unscoped.find(params[:id])
        force = params[:force] == "true"

        result = CompanyOutreachService.send_to_company(@company, force: force)

        if result[:success]
          redirect_back fallback_location: app_admin_top_company_path(@company), notice: result[:message]
        else
          redirect_back fallback_location: app_admin_top_company_path(@company), alert: result[:message]
        end
      end
    end
  end
end
