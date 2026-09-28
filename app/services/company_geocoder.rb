# app/services/company_geocoder.rb
require "net/http"
require "json"

class CompanyGeocoder
  BRASIL_API_URL = "https://brasilapi.com.br/api/cep/v2/".freeze
  LOCAL_NOMINATIM_URL = ENV.fetch("NOMINATIM_LOCAL_URL", "http://localhost:8088/search").freeze

  def self.geocode(company)
    geocode_exact(company)
  end

  def self.geocode_exact_fast(company)
    return [ company.latitude, company.longitude, company.geocode_precision ] if company.latitude.present? && company.longitude.present?

    clean_street = company.street.to_s.gsub(/\A\d+A\s+/i, "").strip
    clean_number = company.number.to_s.strip.presence
    return nil if clean_street.blank?

    # Nível 1: Rua + Número + Cidade + Estado
    exact_query = [ clean_street, clean_number, company.city&.name, company.state&.acronym, "Brasil" ].compact_blank.join(", ")
    res = query_local_nominatim(exact_query)
    precision = "exact"

    # Nível 2: Rua + Cidade + Estado (se o número não exisitr no mapa)
    if res.nil? && clean_number.present?
      street_query = [ clean_street, company.city&.name, company.state&.acronym, "Brasil" ].compact_blank.join(", ")
      res = query_local_nominatim(street_query)
      precision = "street"
    end

    if res.present?
      company.update_columns(latitude: res[:lat], longitude: res[:lng], geocode_precision: precision, updated_at: Time.current)
      company.latitude = res[:lat]
      company.longitude = res[:lng]
      company.geocode_precision = precision
      [ res[:lat], res[:lng], precision ]
    else
      nil
    end
  rescue StandardError => e
    Rails.logger.error("CompanyGeocoder error for company ##{company.id}: #{e.message}")
    nil
  end

  def self.geocode_exact(company)
    return [ company.latitude, company.longitude, company.geocode_precision ] if company.latitude.present? && company.longitude.present?

    coords = nil
    precision = nil

    clean_street = company.street.to_s.gsub(/\A\d+A\s+/i, "").strip
    clean_number = company.number.to_s.strip.presence

    # Nível 1: Endereço Exato com Número (Rua, Número, Cidade, Estado)
    if clean_street.present?
      exact_query = [ clean_street, clean_number, company.city&.name, company.state&.acronym, "Brasil" ].compact_blank.join(", ")
      res = query_local_nominatim(exact_query)
      if res.present?
        coords = res
        precision = "exact"
      end

      # Nível 2: Endereço sem Número (Rua, Cidade, Estado)
      if coords.nil?
        street_query = [ clean_street, company.city&.name, company.state&.acronym, "Brasil" ].compact_blank.join(", ")
        res = query_local_nominatim(street_query)
        if res.present?
          coords = res
          precision = "street"
        end
      end
    end

    # Nível 3: Fallback por CEP (Formatado)
    if coords.nil? && company.zip_code.present?
      clean_cep = company.zip_code.to_s.gsub(/\D/, "")
      if clean_cep.length == 8
        cep_fmt = "#{clean_cep[0..4]}-#{clean_cep[5..7]}"
        res = query_local_nominatim("#{cep_fmt}, Brasil")
        res ||= fetch_from_brasil_api(clean_cep)
        if res.present?
          coords = res
          precision = "cep"
        end
      end
    end

    if coords.present?
      company.update_columns(latitude: coords[:lat], longitude: coords[:lng], geocode_precision: precision, updated_at: Time.current)
      company.latitude = coords[:lat]
      company.longitude = coords[:lng]
      company.geocode_precision = precision
      [ coords[:lat], coords[:lng], precision ]
    else
      nil
    end
  rescue StandardError => e
    Rails.logger.error("CompanyGeocoder error for company ##{company.id}: #{e.message}")
    nil
  end

  def self.query_local_nominatim(query)
    uri = URI(LOCAL_NOMINATIM_URL)
    uri.query = URI.encode_www_form(q: query, format: "json", limit: 1)

    http = Thread.current[:nominatim_http]
    if http.nil? || !http.active?
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.open_timeout = 2
      http.read_timeout = 2
      http.start
      Thread.current[:nominatim_http] = http
    end

    req = Net::HTTP::Get.new(uri)
    req["User-Agent"] = "HospedagemDiretaApp/1.0"

    res = http.request(req)
    return nil unless res.is_a?(Net::HTTPSuccess)

    data = JSON.parse(res.body)
    return nil if data.empty?

    first = data.first
    lat = first["lat"]&.to_f
    lng = first["lon"]&.to_f
    return nil if lat.nil? || lng.nil? || lat.zero? || lng.zero?

    { lat: lat, lng: lng }
  rescue StandardError
    Thread.current[:nominatim_http] = nil
    nil
  end

  def self.geocode_city(city, limit: 50)
    companies = city.companies.where(latitude: nil).or(city.companies.where(longitude: nil)).limit(limit)
    companies.each do |comp|
      geocode(comp)
      sleep 0.2
    end
  end

  def self.geocode_cep_local(zip_code)
    return nil if zip_code.blank?

    clean_cep = zip_code.to_s.gsub(/\D/, "")
    return nil unless clean_cep.length == 8

    query_local_nominatim("#{clean_cep}, Brasil")
  end

  def self.geocode_cep(zip_code, max_retries: 3)
    return nil if zip_code.blank?

    clean_cep = zip_code.to_s.gsub(/\D/, "")
    return nil unless clean_cep.length == 8

    coords = geocode_cep_local(clean_cep)
    coords ||= fetch_from_brasil_api(clean_cep, max_retries: max_retries)
    coords
  end

  def self.fetch_from_nominatim_cep(clean_cep)
    formatted_cep = "#{clean_cep[0..4]}-#{clean_cep[5..7]}"
    query_local_nominatim("#{formatted_cep}, Brasil")
  end

  class RateLimitError < StandardError; end

  private

  def self.fetch_from_brasil_api(clean_cep, max_retries: 3)
    retries = 0

    begin
      uri = URI("#{BRASIL_API_URL}#{clean_cep}")
      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = "HospedagemDiretaApp/1.0"

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 3) do |http|
        http.request(req)
      end

      # Trata limite de requisições (Rate Limit 429)
      raise RateLimitError, "429 Too Many Requests" if res.code.to_i == 429

      return nil unless res.is_a?(Net::HTTPSuccess)

      data = JSON.parse(res.body)
      location = data["location"]
      return nil unless location && location["coordinates"]

      coords = location["coordinates"]
      lat = coords["latitude"]&.to_f
      lng = coords["longitude"]&.to_f

      return nil if lat.nil? || lng.nil? || lat.zero? || lng.zero?

      { lat: lat, lng: lng }
    rescue RateLimitError => e
      if retries < max_retries
        retries += 1
        sleep_time = 3 * retries
        Rails.logger.warn("BrasilAPI Rate Limit (429) para CEP #{clean_cep}. Aguardando #{sleep_time}s (Tentativa #{retries}/#{max_retries})...")
        sleep(sleep_time)
        retry
      end
      nil
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, SocketError => e
      if retries < max_retries
        retries += 1
        sleep(1 * retries)
        retry
      end
      nil
    rescue StandardError => e
      Rails.logger.error("BrasilAPI error for CEP #{clean_cep}: #{e.message}")
      nil
    end
  end

  def self.fetch_from_nominatim(company)
    queries = [
      [ company.street, company.number, company.neighborhood&.name, company.city&.name, company.state&.acronym, "Brasil" ].compact_blank.join(", "),
      [ company.neighborhood&.name, company.city&.name, company.state&.acronym, "Brasil" ].compact_blank.join(", "),
      [ company.city&.name, company.state&.acronym, "Brasil" ].compact_blank.join(", ")
    ]

    queries.each do |q|
      coords = query_nominatim(q)
      return coords if coords.present?
    end

    nil
  end

  def self.query_nominatim(query)
    uri = URI(NOMINATIM_URL)
    uri.query = URI.encode_www_form(q: query, format: "json", limit: 1)

    req = Net::HTTP::Get.new(uri)
    req["User-Agent"] = "HospedagemDiretaApp/1.0"

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 2, read_timeout: 2) do |http|
      http.request(req)
    end

    return nil unless res.is_a?(Net::HTTPSuccess)

    data = JSON.parse(res.body)
    return nil if data.empty?

    first = data.first
    lat = first["lat"]&.to_f
    lng = first["lon"]&.to_f
    return nil if lat.nil? || lng.nil? || lat.zero? || lng.zero?

    { lat: lat, lng: lng }
  rescue StandardError
    nil
  end
end
