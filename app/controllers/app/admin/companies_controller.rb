module App
  module Admin
    class CompaniesController < BaseController
      def index
        @status_filter = params[:status].presence || "pending"

        scope = Company.unscoped.includes(:state, :city, :user, :categories)

        @companies = case @status_filter
        when "pending"
                       scope.where(deleted_at: nil).and(scope.where(claim_status: :pending).or(scope.where(removal_requested: true))).order(document_submitted_at: :desc, updated_at: :desc)
        when "approved"
                       scope.where(claim_status: :approved, deleted_at: nil).order(claimed_at: :desc, updated_at: :desc)
        when "unclaimed"
                       scope.where(claim_status: :unclaimed, deleted_at: nil).order(updated_at: :desc)
        when "deleted"
                       scope.where.not(deleted_at: nil).order(deleted_at: :desc)
        when "removal_requested"
                       scope.where(removal_requested: true, deleted_at: nil).order(updated_at: :desc)
        else # "all"
                       scope.order(updated_at: :desc)
        end

        @pagy, @companies = pagy(:offset, @companies, limit: 25)
      end

      def show
        @company = Company.unscoped.includes(:state, :city, :neighborhood, :user, :categories, :reviews, :favorites, :outreach_logs).find(params[:id])
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
          redirect_back fallback_location: app_admin_company_path(@company), notice: result[:message]
        else
          redirect_back fallback_location: app_admin_company_path(@company), alert: result[:message]
        end
      end
    end
  end
end
