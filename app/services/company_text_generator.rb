# app/services/company_text_generator.rb
class CompanyTextGenerator
  include ActiveSupport::NumberHelper
  include ActionView::Helpers::SanitizeHelper

  def initialize(company)
    @company = company
    clean_cnpj = company.cnpj.to_s.gsub(/\D/, "")
    @seed = clean_cnpj.present? && clean_cnpj != "0" ? clean_cnpj.to_i : (company.id || 1)
    @rng = Random.new(@seed)
  end

  def generate_about
    blocks = [
      block_foundation,
      block_location,
      block_cnae,
      block_partners,
      block_maturity,
      block_cta
    ].compact_blank

    blocks.join(" ")
  end

  def generate_faq
    opening_date_str = formatted_opening_date
    years_str = calculate_years.to_s
    months_str = calculate_months.to_s

    q1_templates = [
      "Como funciona a reserva direta em <strong>#{trade_name}</strong> (CNPJ: <strong>#{formatted_cnpj}</strong>)?",
      "Como contactar <strong>#{trade_name}</strong> (CNPJ <strong>#{formatted_cnpj}</strong>) para cotar diárias?",
      "Quais as informações de cadastro e reserva de <strong>#{trade_name}</strong> (CNPJ <strong>#{formatted_cnpj}</strong>)?"
    ]
    q2_templates = [
      "Quais as vantagens de reservar direto com a <strong>#{trade_name}</strong> em <strong>#{city_name}</strong>?",
      "Por que vale a pena negociar direto com a recepção de <strong>#{trade_name}</strong>?",
      "Como economizar em diárias se hospedando em <strong>#{trade_name}</strong>?"
    ]
    q3_templates = [
      "Qual é o segmento de hospedagem e serviços de <strong>#{trade_name}</strong>?",
      "O que oferece o estabelecimento <strong>#{trade_name}</strong> em <strong>#{city_name}</strong>?",
      "Quais serviços de acomodação a <strong>#{trade_name}</strong> disponibiliza?"
    ]
    q4_templates = [
      "Qual o endereço e como chegar em <strong>#{trade_name}</strong>?",
      "Onde fica localizada a <strong>#{trade_name}</strong> em <strong>#{city_name}</strong>?",
      "Qual a localização exata de <strong>#{trade_name}</strong> no bairro <strong>#{neighborhood_name}</strong>?"
    ]
    q5_templates = [
      "Como falar no WhatsApp com a recepção de <strong>#{trade_name}</strong>?",
      "Qual é o telefone de contato para reservas na <strong>#{trade_name}</strong>?",
      "Como obter atendimento direto com a <strong>#{trade_name}</strong> em <strong>#{city_name}</strong>?"
    ]
    q6_templates = [
      "Quem administra e responde pelo estabelecimento <strong>#{trade_name}</strong>?",
      "Qual é o corpo gestor responsável por <strong>#{trade_name}</strong>?",
      "Quem faz a gestão do estabelecimento <strong>#{trade_name}</strong>?"
    ]
    q7_templates = [
      "Há quanto tempo a <strong>#{trade_name}</strong> atende na região de <strong>#{city_name}</strong>?",
      "Qual a tradição de atendimento de <strong>#{trade_name}</strong> em <strong>#{city_name}</strong>?",
      "Desde quando a <strong>#{trade_name}</strong> opera em <strong>#{city_name}</strong>?"
    ]
    q8_templates = [
      "A <strong>#{trade_name}</strong> encontra-se com cadastro regular ativo em <strong>#{city_name}</strong>?",
      "Qual o status cadastral oficial de <strong>#{trade_name}</strong>?",
      "A hospedagem <strong>#{trade_name}</strong> está em operação regular no turismo de <strong>#{city_name}</strong>?"
    ]
    q9_templates = [
      "Quais as garantias de transparência ao negociar com <strong>#{trade_name}</strong>?",
      "Como conferir os dados oficiais de <strong>#{trade_name}</strong>?",
      "Qual a razão social e enquadramento registrado de <strong>#{trade_name}</strong>?"
    ]
    q10_templates = [
      "Como solicitar orçamento de diárias e checar disponibilidade em <strong>#{trade_name}</strong>?",
      "Como consultar tarifas e datas disponíveis para <strong>#{trade_name}</strong>?",
      "Qual o melhor caminho para reservar uma acomodação na <strong>#{trade_name}</strong>?"
    ]

    faqs = [
      {
        question: q1_templates[@rng.rand(q1_templates.size)],
        answer: "A <strong>#{trade_name}</strong> (razão social <strong>#{legal_name}</strong>) é um estabelecimento registrado no município de <strong>#{city_name}/#{state_acronym}</strong>#{@company.opening_date.present? ? ", atuando no mercado desde <strong>#{opening_date_str}</strong>" : ""}. Você pode negociar diárias diretamente com a recepção sem pagar taxas de intermediação."
      },
      {
        question: q2_templates[@rng.rand(q2_templates.size)],
        answer: "Ao falar diretamente com a <strong>#{trade_name}</strong> por telefone ou WhatsApp, você economiza até 25% por diária em relação às plataformas online de intermediação (OTAs), negociando condições exclusivas diretamente com o estabelecimento."
      },
      {
        question: q3_templates[@rng.rand(q3_templates.size)],
        answer: "O estabelecimento atua no segmento de <strong>#{cnae_main_text}</strong>, atendendo viajantes e hóspedes que buscam acomodação com atendimento personalizado em <strong>#{city_name} - #{state_acronym}</strong>."
      },
      {
        question: q4_templates[@rng.rand(q4_templates.size)],
        answer: "A <strong>#{trade_name}</strong> está localizada na <strong>#{street_text}, nº #{number_text}#{complement_text}</strong>, bairro <strong>#{neighborhood_name}</strong>, <strong>#{city_name} - #{state_acronym}</strong> (CEP <strong>#{zip_code_text}</strong>)."
      },
      {
        question: q5_templates[@rng.rand(q5_templates.size)],
        answer: "Você pode clicar no botão 'WhatsApp Direto' ou revelar os telefones de contato nesta página para falar instantaneamente com a equipe da <strong>#{trade_name}</strong> em <strong>#{city_name}</strong>."
      },
      {
        question: q6_templates[@rng.rand(q6_templates.size)],
        answer: partners_formatted_list
      },
      {
        question: q7_templates[@rng.rand(q7_templates.size)],
        answer: @company.opening_date.present? ? "A hospedagem atua na região desde <strong>#{opening_date_str}</strong>, acumulando cerca de <strong>#{years_str} ano(s)</strong>#{months_str != '0' ? " e <strong>#{months_str} mês(es)</strong>" : ""} de receptivo." : "O estabelecimento possui cadastro ativo e regular no setor de hospedagem em <strong>#{city_name}</strong>."
      },
      {
        question: q8_templates[@rng.rand(q8_templates.size)],
        answer: "A situação cadastral da empresa perante os órgãos oficiais é <strong>#{status_text}</strong>, confirmando sua operação regular no mercado de <strong>#{city_name}</strong>."
      },
      {
        question: q9_templates[@rng.rand(q9_templates.size)],
        answer: "O estabelecimento opera sob a razão social <strong>#{legal_name}</strong> (CNPJ <strong>#{formatted_cnpj}</strong>) com porte registrado de <strong>#{company_size_text}</strong> e capital social declarado de <strong>#{capital_social_text}</strong>, garantindo total transparência ao viajante."
      },
      {
        question: q10_templates[@rng.rand(q10_templates.size)],
        answer: "Basta clicar nos botões de contato nesta página para abrir conversa direta no WhatsApp ou ligar para a recepção do estabelecimento em <strong>#{city_name}</strong> sem pagar comissões adicionais."
      }
    ]

    faqs
  end

  private

  def block_foundation
    if @company.opening_date.blank?
      templates = [
        "A hospedagem %{company_name} é um estabelecimento ativo de acomodação na cidade de %{city} - %{state}.",
        "Com excelente localização em %{city}, a %{company_name} recebe viajantes e hóspedes buscando conforto e bom atendimento.",
        "Sediada no município de %{city}/%{state}, a %{company_name} oferece opções de acomodação para quem visita a região.",
        "A %{company_name} opera na cidade de %{city} mantendo o compromisso de atendimento direto aos hóspedes.",
        "Com registro regularizado perante os órgãos competentes, a %{company_name} atua no segmento de hospedagens em %{city} - %{state}."
      ]

      index = @rng.rand(templates.size)
      format(templates[index],
        company_name: "<strong>#{trade_name}</strong>",
        city: "<strong>#{city_name}</strong>",
        state: "<strong>#{state_acronym}</strong>"
      )
    else
      templates = [
        "A %{company_name} iniciou suas atividades em %{opening_date}, contando com mais de %{years} de tradição em receptivo na região.",
        "Com fundação em %{opening_date}, a %{company_name} vem acumulando %{years} de experiência no atendimento aos hóspedes.",
        "Aberta formalmente em %{opening_date}, a %{company_name} acumula %{years} e %{months} de história em %{city}.",
        "Em %{year_founded} (precisamente em %{opening_date}), a %{company_name} deu início aos seus trabalhos na área de hospedagem.",
        "Registrada e inaugurada em %{opening_date}, a %{company_name} possui uma trajetória de %{years} no setor hoteleiro.",
        "A %{company_name} foi fundada no dia %{opening_date} e soma hoje %{years} de atuação ativa.",
        "Desde o início de suas operações em %{opening_date}, a %{company_name} consolida sua presença em %{city} há %{years}.",
        "Na data de %{opening_date}, foi oficialmente aberta a %{company_name}, completando %{years} de atendimento.",
        "Estabelecida em %{year_founded} (em %{opening_date}), a %{company_name} preserva %{years} de receptivo aos visitantes.",
        "Com início das atividades datado em %{opening_date}, a %{company_name} soma %{years} de constante evolução no turismo local."
      ]

      index = @rng.rand(templates.size)
      format(templates[index],
        company_name: "<strong>#{trade_name}</strong>",
        opening_date: "<strong>#{formatted_opening_date}</strong>",
        years: "<strong>#{calculate_years} anos</strong>",
        months: "<strong>#{calculate_months} meses</strong>",
        year_founded: "<strong>#{year_founded}</strong>",
        city: "<strong>#{city_name}</strong>",
        state: "<strong>#{state_acronym}</strong>"
      )
    end
  end

  def block_location
    templates = [
      "Localizada na %{street}, nº %{number}, no bairro %{neighborhood} em %{city} - %{state} (CEP %{zip_code}), oferece fácil acesso para os viajantes.",
      "A estrutura da %{company_name} encontra-se situada na %{street}, nº %{number}, bairro %{neighborhood}, no município de %{city}/%{state}.",
      "Com endereço registrado na %{street}, nº %{number} (%{neighborhood}, %{city} - %{state}), posiciona-se estrategicamente para receber visitantes.",
      "Situada no bairro %{neighborhood}, na %{street}, nº %{number} em %{city} (%{state}), proporciona conveniente localização para sua estadia.",
      "Instalada no município de %{city} - %{state}, a %{company_name} está localizada na %{street}, nº %{number}, %{neighborhood}.",
      "A estrutura da hospedagem fica no endereço %{street}, nº %{number} - %{neighborhood}, na cidade de %{city} - %{state}, sob o CEP %{zip_code}.",
      "Operando em %{city}/%{state}, o estabelecimento fica na %{street}, nº %{number}, no bairro %{neighborhood}.",
      "Encontrada na %{street}, nº %{number} em %{city} - %{state}, a %{company_name} atende turistas e visitantes no bairro %{neighborhood} e arredores.",
      "A hospedagem está sediada em %{city} - %{state}, no bairro %{neighborhood}, na %{street}, nº %{number}.",
      "Estratégica em %{city}/%{state}, a unidade está fixa na %{street}, nº %{number} (bairro %{neighborhood}, CEP %{zip_code})."
    ]

    index = @rng.rand(templates.size)
    format(templates[index],
      company_name: "<strong>#{trade_name}</strong>",
      street: "<strong>#{street_text}</strong>",
      number: "<strong>#{number_text}</strong>",
      neighborhood: "<strong>#{neighborhood_name}</strong>",
      city: "<strong>#{city_name}</strong>",
      state: "<strong>#{state_acronym}</strong>",
      zip_code: "<strong>#{zip_code_text}</strong>"
    )
  end

  def block_cnae
    templates = [
      "Sua atividade econômica principal, conforme cadastro na Receita Federal, é %{cnae_main}%{cnae_secondaries}.",
      "O estabelecimento é cadastrado no segmento de %{cnae_main}, atuando com foco em conforto e hospitalidade%{cnae_secondaries}.",
      "Tendo como atividade registrada o setor de %{cnae_main}, a %{company_name} oferece serviços de receptivo%{cnae_secondaries}.",
      "O campo de atuação prioritário da propriedade contempla %{cnae_main}%{cnae_secondaries}.",
      "Classificada sob o CNAE principal %{cnae_main}, a organização integra a rede de serviços de hospedagem da região%{cnae_secondaries}.",
      "Com registro para execução de %{cnae_main}, a empresa atende padrões cadastrais oficiais%{cnae_secondaries}.",
      "O ramo mercantil principal da %{company_name} abrange %{cnae_main}%{cnae_secondaries}.",
      "Dedicada ao setor de %{cnae_main}, a acomodação contribui para o fluxo turístico e de viagens em %{city}%{cnae_secondaries}.",
      "Com habilitação cadastral em %{cnae_main}, destaca-se no setor de turismo e diárias%{cnae_secondaries}.",
      "O registro principal do estabelecimento está centrado em %{cnae_main}%{cnae_secondaries}."
    ]

    index = @rng.rand(templates.size)
    format(templates[index],
      company_name: "<strong>#{trade_name}</strong>",
      cnae_main: "<strong>#{cnae_main_text}</strong>",
      cnae_secondaries: cnae_secondaries_suffix,
      city: "<strong>#{city_name}</strong>"
    )
  end

  def block_partners
    if @company.partners.empty?
      return "A empresa opera no formato individual sob administração registrada perante os órgãos competentes."
    end

    templates = [
      "A gestão e condução da sociedade conta com o trabalho de %{partners_list}.",
      "O quadro de sócios e administradores responsável pela empresa é composto por %{partners_list}.",
      "Tendo em sua liderança societária %{partners_list}, a empresa mantém uma administração focada.",
      "A estrutura de governança da %{company_name} integra os sócios %{partners_list}.",
      "No comando administrativo e institucional da organização encontram-se %{partners_list}.",
      "Sob responsabilidade societária de %{partners_list}, a empresa conduz suas operações comerciais.",
      "A junta societária da empresa reúne os administradores %{partners_list}.",
      "Administrada por %{partners_list}, a firma preserva o compromisso com seus parceiros e clientes.",
      "O corpo diretivo da %{company_name} é formado por %{partners_list}.",
      "A responsabilidade legal e operacional do estabelecimento cabe a %{partners_list}."
    ]

    index = @rng.rand(templates.size)
    format(templates[index],
      company_name: "<strong>#{trade_name}</strong>",
      partners_list: partners_formatted_names
    )
  end

  def block_maturity
    templates = [
      "Atualmente com situação cadastral %{status}, a empresa está registrada sob o porte %{company_size} e possui capital social de %{capital_social}.",
      "Registrada com o porte %{company_size}, a %{company_name} encontra-se %{status} na Receita Federal, possuindo capital social subscrito de %{capital_social}.",
      "Encontrando-se ativa e regularizada (%{status}), a organização enquadra-se como %{company_size}, declarando capital de %{capital_social}.",
      "Com capital social declarado de %{capital_social}, a firma está enquadrada na categoria de %{company_size} com status cadastral %{status}.",
      "A empresa figura no cadastro com status %{status}, sendo classificada no porte %{company_size} com capital registrado de %{capital_social}.",
      "Enquadrada como %{company_size} e com situação %{status}, a organização dispõe de capital social integralizado de %{capital_social}.",
      "Formalizada na condição de %{company_size}, seu registro permanece %{status} junto aos órgãos fiscais, com capital de %{capital_social}.",
      "Operando sob o porte %{company_size}, a empresa detém capital social de %{capital_social} e status oficial %{status}.",
      "Mantendo sua situação cadastral %{status}, a %{company_name} é qualificada como %{company_size} (capital de %{capital_social}).",
      "Com patrimônio social registrado em %{capital_social}, a %{company_name} opera como %{company_size} mantendo status %{status}."
    ]

    index = @rng.rand(templates.size)
    format(templates[index],
      company_name: "<strong>#{trade_name}</strong>",
      status: "<strong>#{status_text}</strong>",
      company_size: "<strong>#{company_size_text}</strong>",
      capital_social: "<strong>#{capital_social_text}</strong>"
    )
  end

  def block_cta
    templates = [
      "Para consultar disponibilidade e negociar diárias sem comissão na cidade de %{city}, entre em contato via WhatsApp ou telefone diretamente com a recepção.",
      "Deseja reservar com o menor preço em %{city}? Fale direto com a equipe da %{company_name} através dos contatos exibidos no portal.",
      "Consulte diárias e horários de check-in na %{company_name} em %{city} sem pagar taxas para plataformas intermediárias.",
      "Para obter informações sobre acomodações e valores na cidade de %{city}, acesse os canais de contato direto da %{company_name}.",
      "A equipe da %{company_name} recebe viajantes na cidade de %{city} e região oferecendo atendimento direto e transparente.",
      "Dúvidas sobre reservas em %{city}? Fale com a recepção da %{company_name} pelo WhatsApp Direto.",
      "Garanta o melhor valor na sua estadia em %{city} conectando-se diretamente com a %{company_name}.",
      "Para reservas diretas e suporte em %{city}, acione o atendimento telefônico ou WhatsApp da %{company_name}.",
      "A %{company_name} disponibiliza atendimento direto aos hóspedes no município de %{city}.",
      "Conecte-se com a %{company_name} em %{city} e faça sua reserva direta sem taxa de intermediação."
    ]

    index = @rng.rand(templates.size)
    format(templates[index],
      company_name: "<strong>#{trade_name}</strong>",
      city: "<strong>#{city_name}</strong>"
    )
  end

  # Helpers

  def trade_name
    @company.trade_name.presence || @company.legal_name
  end

  def legal_name
    @company.legal_name
  end

  def formatted_cnpj
    @company.cnpj
  end

  def formatted_opening_date
    return "" if @company.opening_date.blank?
    @company.opening_date.strftime("%d/%m/%Y")
  end

  def year_founded
    return @company.created_at&.year || Time.current.year if @company.opening_date.blank?
    @company.opening_date.year
  end

  def calculate_years
    return 1 if @company.opening_date.blank?
    today = Date.today
    years = today.year - @company.opening_date.year
    years -= 1 if today < @company.opening_date + years.years
    [ years, 1 ].max
  end

  def calculate_months
    return 0 if @company.opening_date.blank?
    today = Date.today
    months = (today.year * 12 + today.month) - (@company.opening_date.year * 12 + @company.opening_date.month)
    [ months % 12, 0 ].max
  end

  def street_text
    @company.street.presence || "Endereço Principal"
  end

  def number_text
    @company.number.presence || "s/n"
  end

  def complement_text
    return "" if @company.complement.blank?
    ", #{@company.complement}"
  end

  def neighborhood_name
    @company.neighborhood&.name.presence || "Centro"
  end

  def city_name
    @company.city&.name.presence || "São Paulo"
  end

  def state_acronym
    @company.state&.acronym.presence || "SP"
  end

  def zip_code_text
    @company.zip_code.presence || "12500-000"
  end

  def cnae_main_text
    raw = @company.cnae_principal.to_s.strip
    return "Hotéis e Pousadas" if raw.blank?

    clean_digits = raw.gsub(/\D/, "")
    mapped = Company::CNAE_MAPPINGS[clean_digits]
    return mapped if mapped.present?

    if raw.include?(" - ")
      parts = raw.split(" - ", 2)
      parts.last.presence || raw
    else
      raw
    end
  end

  def cnae_secondaries_suffix
    if @company.cnae_secundarios.blank?
      ""
    else
      ", complementando seu portfólio com atividades secundárias registradas"
    end
  end

  def partners_formatted_names
    names = @company.partners.map { |p| "<strong>#{p.name}</strong> (#{p.qualification.presence || 'Sócio'})" }
    names.to_sentence(two_words_connector: " e ", last_word_connector: " e ")
  end

  def partners_formatted_list
    if @company.partners.empty?
      "A empresa opera no formato individual sem sócios registrados na Receita Federal."
    else
      partners_formatted_names
    end
  end

  def status_text
    @company.status.presence || "Ativa"
  end

  def company_size_text
    @company.company_size.presence || "Sem Enquadramento"
  end

  def capital_social_text
    if @company.capital_social.present? && @company.capital_social > 0
      number_to_currency(@company.capital_social, unit: "R$ ", separator: ",", delimiter: ".")
    else
      "não informado"
    end
  end

  def phone_text
    [ @company.phone_1, @company.phone_2 ].compact_blank.first || "não informado"
  end
end
