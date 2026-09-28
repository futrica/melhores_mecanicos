require "resolv"
require "net/http"
require "json"

class EmailValidatorService
  EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  TYPO_DOMAINS = {
    "gamil.com" => "gmail.com",
    "gmaill.com" => "gmail.com",
    "gmai.com" => "gmail.com",
    "gmal.com" => "gmail.com",
    "gmeil.com" => "gmail.com",
    "gmial.com" => "gmail.com",
    "gmai.com.br" => "gmail.com",
    "gamil.com.br" => "gmail.com",
    "hotmaill.com" => "hotmail.com",
    "homail.com" => "hotmail.com",
    "hotmial.com" => "hotmail.com",
    "hotmal.com" => "hotmail.com",
    "hotmai.com" => "hotmail.com",
    "hotmail.com.br" => "hotmail.com",
    "yaho.com.br" => "yahoo.com.br",
    "yahoo.com.brr" => "yahoo.com.br",
    "yaho.com" => "yahoo.com",
    "yahou.com" => "yahoo.com",
    "outlok.com" => "outlook.com",
    "outlokk.com" => "outlook.com",
    "outloock.com" => "outlook.com",
    "outlok.com.br" => "outlook.com",
    "icoud.com" => "icloud.com",
    "icloud.co" => "icloud.com"
  }.freeze

  SUSPICIOUS_LOCAL_PARTS = %w[
    test teste testing naotem sememail nao nenhum
    naotememail 123 1234 12345 123456 0000 00000 xxx abcd abc
  ].freeze

  SUSPICIOUS_DOMAINS = %w[
    example.com teste.com test.com domain.com email.com site.com
    naotem.com empresa.com sitemail.com mailinator.com 123.com 000.com
  ].freeze

  MICROSOFT_DOMAINS = %w[
    hotmail.com hotmail.com.br
    outlook.com outlook.com.br
    live.com live.com.br
    msn.com msn.com.br
    windowslive.com
  ].freeze

  UOL_DOMAINS = %w[
    uol.com.br uol.com
    bol.com.br
    zipmail.com.br
    folha.com.br
  ].freeze

  def self.microsoft_domain?(email)
    return false if email.blank?
    sanitized = sanitize_email(email)
    domain = sanitized.split("@").last.to_s.downcase
    MICROSOFT_DOMAINS.include?(domain) || domain.end_with?(".hotmail.com", ".outlook.com", ".live.com")
  end

  def self.uol_domain?(email)
    return false if email.blank?
    sanitized = sanitize_email(email)
    domain = sanitized.split("@").last.to_s.downcase
    UOL_DOMAINS.include?(domain) || domain.end_with?(".uol.com.br", ".bol.com.br")
  end

  @mx_cache = {}

  def self.sanitize_email(email)
    return "" if email.blank?
    clean = email.to_s.strip.downcase
    parts = clean.split("@")
    return clean if parts.length != 2

    local, domain = parts
    corrected_domain = TYPO_DOMAINS[domain] || domain
    "#{local}@#{corrected_domain}"
  end

  def self.valid_format?(email)
    return false if email.blank?
    sanitized = sanitize_email(email)
    EMAIL_REGEX.match?(sanitized)
  end

  def self.synthetic_or_dummy?(email)
    return true if email.blank?
    sanitized = sanitize_email(email)
    return true unless valid_format?(sanitized)

    local, domain = sanitized.split("@")
    return true if local.blank? || domain.blank?

    return true if SUSPICIOUS_LOCAL_PARTS.include?(local)
    return true if SUSPICIOUS_DOMAINS.include?(domain)
    return true if local.match?(/\A(.)\1{4,}\z/)
    return true if local.match?(/\A\d{1,4}\z/)

    false
  end

  def self.has_valid_mx?(email)
    return false unless valid_format?(email)
    sanitized = sanitize_email(email)

    domain = sanitized.split("@").last
    return false if domain.blank?

    return @mx_cache[domain] if @mx_cache.key?(domain)

    has_mx = begin
      Resolv::DNS.open do |dns|
        dns.timeouts = 3 if dns.respond_to?(:timeouts=)
        records = dns.getresources(domain, Resolv::DNS::Resource::IN::MX)
        records.present?
      end
    rescue StandardError => e
      Rails.logger.warn("[EmailValidatorService] DNS error checking MX for #{domain}: #{e.message}")
      false
    end

    @mx_cache[domain] = has_mx
    has_mx
  end

  def self.valid_email?(email)
    return false if synthetic_or_dummy?(email)
    has_valid_mx?(email) && external_api_valid?(email)
  end

  def self.external_api_valid?(email)
    api_key = ENV["ABSTRACT_EMAIL_VALIDATION_API_KEY"].presence || ENV["ZEROBOUNCE_API_KEY"].presence
    return true if api_key.blank?

    begin
      sanitized = sanitize_email(email)
      uri = URI("https://emailvalidation.abstractapi.com/v1/?api_key=#{api_key}&email=#{URI.encode_www_form_component(sanitized)}")
      response = Net::HTTP.get_response(uri)
      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        return data["deliverability"] != "UNDELIVERABLE" && data.dig("is_smtp_valid", "value") != false
      end
    rescue StandardError => e
      Rails.logger.warn("[EmailValidatorService] External API validation error: #{e.message}")
    end

    true
  end

  def self.clear_cache!
    @mx_cache.clear
  end
end
