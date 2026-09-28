class CompanyOutreachService
  attr_reader :limit, :min_views, :cooldown_days, :dry_run, :sleep_seconds

  def initialize(limit: nil, min_views: 0, cooldown_days: 60, dry_run: false, sleep_seconds: 2)
    @min_views = min_views.to_i
    @cooldown_days = cooldown_days.to_i
    @dry_run = ActiveModel::Type::Boolean.new.cast(dry_run)
    @sleep_seconds = sleep_seconds.to_f

    total_eligible = Company.eligible_for_outreach(min_views: @min_views).count
    calculated_batch = (total_eligible * 0.0001).ceil
    default_limit = [ calculated_batch, 16 ].max

    @limit = limit.present? && limit.to_i > 0 ? limit.to_i : default_limit
  end

  def perform
    results = {
      total_eligible: 0,
      processed: 0,
      sent: 0,
      skipped_opt_out: 0,
      skipped_recently_sent: 0,
      skipped_uol_paused: 0,
      skipped_invalid_mx: 0,
      skipped_claimed: 0,
      failed: 0,
      dry_run: dry_run,
      details: []
    }

    candidates = Company.eligible_for_outreach(min_views: min_views)
                         .includes(:state, :city)
                         .order(views_count: :desc, id: :asc)

    results[:total_eligible] = candidates.count

    candidates.find_each do |company|
      break if results[:processed] >= limit

      # Double check claim status (safety check)
      unless company.unclaimed? && !company.removal_requested?
        results[:skipped_claimed] += 1
        next
      end

      raw_email = company.email.to_s.strip.downcase
      email = EmailValidatorService.sanitize_email(raw_email)

      # Check opt-out list
      if CompanyEmailOptOut.opted_out?(email) || CompanyEmailOptOut.opted_out?(raw_email)
        results[:skipped_opt_out] += 1
        next
      end

      # Check UOL ISP domains pause (UOL/BOL/Zipmail temporarily paused due to SES complaint rate threshold)
      if EmailValidatorService.uol_domain?(email) || EmailValidatorService.uol_domain?(raw_email)
        results[:skipped_uol_paused] += 1
        next
      end

      # Check cooldown
      if CompanyOutreachLog.recently_sent?(company_id: company.id, email: email, cooldown_days: cooldown_days)
        results[:skipped_recently_sent] += 1
        next
      end

      # Check synthetic/dummy pattern or format & MX record
      if EmailValidatorService.synthetic_or_dummy?(email) || !EmailValidatorService.has_valid_mx?(email)
        results[:skipped_invalid_mx] += 1
        unless dry_run
          CompanyOutreachLog.create!(
            company: company,
            email: email.presence || raw_email,
            campaign_name: "profile_presentation",
            sent_at: Time.current,
            status: "invalid_mx"
          )
          CompanyEmailOptOut.find_or_create_by_token_or_email!(
            email: email.presence || raw_email,
            company_id: company.id,
            reason: "invalid_domain_mx",
            feedback: "E-mail sintético, inválido ou domínio sem registros MX."
          )
        end
        next
      end

      # Valid candidate ready for processing
      results[:processed] += 1

      # Fomento sutil de visualizações no perfil antes de disparar
      company.increment!(:views_count, rand(10..20))

      opt_out = CompanyEmailOptOut.find_or_create_by_token_or_email!(email: email, company_id: company.id)

      if dry_run
        results[:sent] += 1
        results[:details] << {
          company_id: company.id,
          name: company.trade_name.presence || company.legal_name,
          email: email,
          views: company.views_count,
          city: "#{company.city.name} - #{company.state.acronym}",
          status: "dry_run_simulated"
        }
      else
        begin
          OutreachMailer.profile_presentation(company, opt_out.token).deliver_now

          CompanyOutreachLog.create!(
            company: company,
            email: email,
            campaign_name: "profile_presentation",
            sent_at: Time.current,
            status: "sent"
          )

          results[:sent] += 1
          results[:details] << {
            company_id: company.id,
            name: company.trade_name.presence || company.legal_name,
            email: email,
            views: company.views_count,
            status: "sent"
          }

          sleep(sleep_seconds) if sleep_seconds > 0
        rescue StandardError => e
          Rails.logger.error("[CompanyOutreachService] Error delivering email to #{email} (Company ##{company.id}): #{e.message}")

          CompanyOutreachLog.create!(
            company: company,
            email: email,
            campaign_name: "profile_presentation",
            sent_at: Time.current,
            status: "failed"
          )

          CompanyEmailOptOut.find_or_create_by_token_or_email!(
            email: email,
            company_id: company.id,
            reason: "delivery_failure",
            feedback: "Falha de entrega no servidor SMTP: #{e.message}"
          )

          results[:failed] += 1
        end
      end
    end

    Rails.cache.delete("outreach_eligible_remaining_count") unless dry_run

    results
  end

  def self.send_to_company(company, campaign_name: "profile_presentation", cooldown_days: 30, force: false)
    raw_email = company.email.to_s.strip.downcase
    email = EmailValidatorService.sanitize_email(raw_email)
    if email.blank?
      return { success: false, message: "A empresa '#{company.trade_name.presence || company.legal_name}' não possui e-mail cadastrado." }
    end

    if CompanyEmailOptOut.opted_out?(email) || CompanyEmailOptOut.opted_out?(raw_email)
      return { success: false, message: "O e-mail #{email} está na lista de descadastramento (opt-out)." }
    end

    if EmailValidatorService.uol_domain?(email) || EmailValidatorService.uol_domain?(raw_email)
      return { success: false, message: "O e-mail #{email} é um domínio do grupo UOL (UOL/BOL/Zipmail). Os disparos de prospecção para o UOL estão temporariamente pausados devido à taxa de reclamações no SES." }
    end

    unless force
      if CompanyOutreachLog.recently_sent?(company_id: company.id, email: email, campaign_name: campaign_name, cooldown_days: cooldown_days)
        last_log = company.outreach_logs.where(campaign_name: campaign_name).order(sent_at: :desc).first
        date_str = last_log ? last_log.sent_at.strftime("%d/%m/%Y às %H:%M") : "recentemente"
        return { success: false, message: "E-mail já foi enviado recentemente em #{date_str} (cooldown de #{cooldown_days} dias)." }
      end
    end

    if EmailValidatorService.synthetic_or_dummy?(email) || !EmailValidatorService.has_valid_mx?(email)
      CompanyOutreachLog.create!(
        company: company,
        email: email.presence || raw_email,
        campaign_name: campaign_name,
        sent_at: Time.current,
        status: "invalid_mx"
      )
      CompanyEmailOptOut.find_or_create_by_token_or_email!(
        email: email.presence || raw_email,
        company_id: company.id,
        reason: "invalid_domain_mx",
        feedback: "E-mail sintético, inválido ou domínio sem registros MX."
      )
      return { success: false, message: "O e-mail #{email} possui sintaxe inválida, é sintético ou sem registros MX." }
    end

    opt_out = CompanyEmailOptOut.find_or_create_by_token_or_email!(email: email, company_id: company.id)

    begin
      OutreachMailer.profile_presentation(company, opt_out.token).deliver_now

      CompanyOutreachLog.create!(
        company: company,
        email: email,
        campaign_name: campaign_name,
        sent_at: Time.current,
        status: "sent"
      )

      Rails.cache.delete("outreach_eligible_remaining_count")
      { success: true, message: "E-mail de apresentação enviado com sucesso para #{email}!" }
    rescue StandardError => e
      Rails.logger.error("[CompanyOutreachService] Error delivering email to #{email} (Company ##{company.id}): #{e.message}")

      CompanyOutreachLog.create!(
        company: company,
        email: email,
        campaign_name: campaign_name,
        sent_at: Time.current,
        status: "failed"
      )

      CompanyEmailOptOut.find_or_create_by_token_or_email!(
        email: email,
        company_id: company.id,
        reason: "delivery_failure",
        feedback: "Falha de entrega no servidor SMTP: #{e.message}"
      )

      { success: false, message: "Falha ao enviar e-mail para #{email}: #{e.message}" }
    end
  end
end
