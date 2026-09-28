module App
  module Admin
    class OutreachLogsController < BaseController
      def index
        @total_sent = CompanyOutreachLog.where(status: "sent").count
        @total_clicked = CompanyOutreachLog.where.not(clicked_at: nil).count
        @total_failed = CompanyOutreachLog.where(status: [ "failed", "invalid_mx" ]).count
        @total_opt_outs = CompanyEmailOptOut.unsubscribed.count

        @eligible_remaining = Rails.cache.fetch("outreach_eligible_remaining_count", expires_in: 30.minutes) do
          Company.eligible_for_outreach.count
        end

        @status_filter = params[:status].presence || "all"

        scope = case @status_filter
        when "sent"
          CompanyOutreachLog.where(status: "sent").includes(company: [ :city, :state ]).order(created_at: :desc)
        when "clicked"
          CompanyOutreachLog.where.not(clicked_at: nil).includes(company: [ :city, :state ]).order(clicked_at: :desc, created_at: :desc)
        when "failed"
          CompanyOutreachLog.where(status: [ "failed", "invalid_mx" ]).includes(company: [ :city, :state ]).order(created_at: :desc)
        when "opt_out"
          CompanyEmailOptOut.unsubscribed.includes(company: [ :city, :state ]).order(unsubscribed_at: :desc, created_at: :desc)
        else # "all"
          CompanyOutreachLog.includes(company: [ :city, :state ]).order(created_at: :desc)
        end

        @pagy, @records = pagy(:offset, scope, limit: 50)
      end
    end
  end
end
