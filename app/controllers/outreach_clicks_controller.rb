class OutreachClicksController < ApplicationController
  def show
    token = params[:token].to_s.strip
    opt_out = CompanyEmailOptOut.find_by(token: token)

    if opt_out.present?
      company = opt_out.company || Company.unscoped.find_by("lower(email) = ?", opt_out.email.downcase)

      if company.present?
        log = company.outreach_logs.order(sent_at: :desc).first
        log ||= CompanyOutreachLog.where("lower(email) = ?", opt_out.email.downcase).order(sent_at: :desc).first
        log&.record_click!

        neighborhood_slug = company.neighborhood&.slug || "centro"
        redirect_to company_page_url(
          state_slug: company.state.slug,
          city_slug: company.city.slug,
          neighborhood_slug: neighborhood_slug,
          slug: company.slug,
          utm_source: "email",
          utm_medium: "outreach",
          utm_campaign: "profile_presentation",
          ref: token
        ), allow_other_host: false, status: :see_other
        return
      end
    end

    redirect_to root_path
  end
end
