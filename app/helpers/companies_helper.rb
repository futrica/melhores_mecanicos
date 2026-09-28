module CompaniesHelper
  INVALID_CONTACT_STRINGS = %w[null n/a 0 - -- não\ informado nao\ informado não sem\ telefone sem\ email nao\ possui n/d].freeze

  def is_valid_phone?(phone)
    return false if phone.blank?
    clean = phone.to_s.downcase.strip
    return false if INVALID_CONTACT_STRINGS.include?(clean) || clean.start_with?("não") || clean.start_with?("nao")
    digits = clean.gsub(/\D/, "")
    return false if digits.blank?
    return false if digits.chars.uniq.size <= 1
    digits.length >= 8
  end

  def is_valid_email?(email)
    return false if email.blank?
    clean = email.to_s.downcase.strip
    return false if INVALID_CONTACT_STRINGS.include?(clean) || clean.start_with?("não") || clean.start_with?("nao")
    return false unless clean.include?("@")
    (clean =~ URI::MailTo::EMAIL_REGEXP).present?
  end

  def mask_phone(phone)
    return "" if phone.blank?
    clean = phone.to_s.strip
    digits = clean.gsub(/\D/, "")
    if digits.length >= 10
      ddd = digits[0..1]
      first_part = digits[2..4]
      "(#{ddd}) #{first_part}****-****"
    else
      clean.sub(/\d{4}$/, "****")
    end
  end

  def mask_email(email)
    return "" if email.blank?
    clean = email.to_s.downcase.strip
    return clean unless clean.include?("@")

    username, domain = clean.split("@", 2)
    masked_user = username.length > 2 ? "#{username[0..1]}****" : "#{username[0]}****"

    if domain.include?(".")
      domain_parts = domain.split(".", 2)
      domain_name = domain_parts.first
      tld = domain_parts.last
      masked_domain = domain_name.length > 2 ? "#{domain_name[0..1]}****" : "#{domain_name[0]}****"
      "#{masked_user}@#{masked_domain}.#{tld}"
    else
      "#{masked_user}@****"
    end
  end

  def company_path_for(company)
    n_slug = company.neighborhood&.slug.presence || "centro"
    company_page_path(
      state_slug: company.state.slug,
      city_slug: company.city.slug,
      neighborhood_slug: n_slug,
      slug: company.slug
    )
  end

  def booking_score_info(company)
    avg = company.average_rating
    reviews_count = company.reviews.size

    if avg > 0 && reviews_count > 0
      score = avg.round(1)
      label = case score
      when 4.8..5.0 then "Excelente"
      when 4.5..4.7 then "Fabuloso"
      when 4.0..4.4 then "Muito Bom"
      when 3.5..3.9 then "Bom"
      when 3.0..3.4 then "Satisfatório"
      else "Regular"
      end
      { score: score, label: label, count: reviews_count, has_reviews: true }
    else
      { score: nil, label: "Ainda não avaliado", count: 0, has_reviews: false }
    end
  end

  def booking_estimated_price(company)
    seed = company.id
    140 + ((seed * 43) % 280)
  end

  def booking_room_type(company)
    cat = company.categories.first&.name || "Hospedagem"
    case cat
    when /pousada/i
      "Quarto Duplo Standard com Ar-Condicionado"
    when /hotel/i, /apart/i
      "Apartamento Superior com Vista Cidade"
    when /hostel/i, /albergue/i
      "Cama em Quarto Compartilhado Climatizado"
    when /chal/i
      "Chalé Privativo com Varanda e Rede"
    when /resort/i
      "Suíte Deluxe King com Vista para o Mar"
    else
      "Acomodação Standard com Café da Manhã"
    end
  end

  def booking_bed_info(company)
    case company.id % 4
    when 0 then "2 camas (1 solteiro, 1 casal)"
    when 1 then "1 cama de casal grande"
    when 2 then "1 cama king-size"
    else "2 camas de solteiro"
    end
  end
end
