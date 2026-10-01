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
      "Como solicitar orçamento mecânico direto em <strong>#{trade_name}</strong> (CNPJ: <strong>#{formatted_cnpj}</strong>)?",
      "Como entrar em contato com <strong>#{trade_name}</strong> (CNPJ <strong>#{formatted_cnpj}</strong>) para agendar manutenção?",
      "Quais as informações cadastrais e canais de contato de <strong>#{trade_name}</strong> (CNPJ <strong>#{formatted_cnpj}</strong>)?"
    ]
    q2_templates = [
      "Quais as vantagens de falar direto com a oficina <strong>#{trade_name}</strong> em <strong>#{city_name}</strong>?",
      "Por que vale a pena negociar o conserto do carro diretamente com a equipe de <strong>#{trade_name}</strong>?",
      "Como obter o melhor preço em serviços mecânicos na <strong>#{trade_name}</strong>?"
    ]
    q3_templates = [
      "Quais são os serviços automotivos e especialidades de <strong>#{trade_name}</strong>?",
      "Quais serviços de mecânica e manutenção a empresa <strong>#{trade_name}</strong> oferece em <strong>#{city_name}</strong>?",
      "Quais especialidades automotivas a <strong>#{trade_name}</strong> disponibiliza para o seu veículo?"
    ]
    q4_templates = [
      "Qual o endereço e como chegar na oficina <strong>#{trade_name}</strong>?",
      "Onde fica localizada a oficina mecânica <strong>#{trade_name}</strong> em <strong>#{city_name}</strong>?",
      "Qual a localização exata de <strong>#{trade_name}</strong> no bairro <strong>#{neighborhood_name}</strong>?"
    ]
    q5_templates = [
      "Como falar no WhatsApp com a equipe da oficina <strong>#{trade_name}</strong>?",
      "Qual é o telefone de contato para tirar dúvidas sobre o carro na <strong>#{trade_name}</strong>?",
      "Como obter atendimento mecânico rápido com a <strong>#{trade_name}</strong> em <strong>#{city_name}</strong>?"
    ]
    q6_templates = [
      "Quem administra e responde tecnicamente pela empresa <strong>#{trade_name}</strong>?",
      "Qual é o quadro gestor e sócios responsáveis por <strong>#{trade_name}</strong>?",
      "Quem faz a gestão do estabelecimento <strong>#{trade_name}</strong>?"
    ]
    q7_templates = [
      "Há quanto tempo a <strong>#{trade_name}</strong> presta serviços automotivos em <strong>#{city_name}</strong>?",
      "Qual a tradição de atendimento e experiência de <strong>#{trade_name}</strong> em <strong>#{city_name}</strong>?",
      "Desde quando a oficina <strong>#{trade_name}</strong> opera em <strong>#{city_name}</strong>?"
    ]
    q8_templates = [
      "A oficina <strong>#{trade_name}</strong> encontra-se com cadastro regular ativo em <strong>#{city_name}</strong>?",
      "Qual a situação cadastral oficial de <strong>#{trade_name}</strong> na Receita Federal?",
      "A empresa automotiva <strong>#{trade_name}</strong> está em operação regular no mercado de <strong>#{city_name}</strong>?"
    ]
    q9_templates = [
      "Quais as garantias de transparência ao contratar os serviços de <strong>#{trade_name}</strong>?",
      "Como conferir os dados oficiais e o CNPJ de <strong>#{trade_name}</strong>?",
      "Qual a razão social e enquadramento registrado de <strong>#{trade_name}</strong>?"
    ]
    q10_templates = [
      "Como solicitar um orçamento mecânico ou agendar revisão em <strong>#{trade_name}</strong>?",
      "Como consultar preços de peças e mão de obra na oficina <strong>#{trade_name}</strong>?",
      "Qual o melhor caminho para agendar uma avaliação técnica na <strong>#{trade_name}</strong>?"
    ]

    faqs = [
      {
        question: q1_templates[@rng.rand(q1_templates.size)],
        answer: "A empresa <strong>#{trade_name}</strong> (razão social <strong>#{legal_name}</strong>) é uma oficina automotiva registrada no município de <strong>#{city_name}/#{state_acronym}</strong>#{@company.opening_date.present? ? ", atuando no setor desde <strong>#{opening_date_str}</strong>" : ""}. Você pode solicitar orçamentos e agendamentos diretamente pelo WhatsApp sem pagar taxas de intermediação."
      },
      {
        question: q2_templates[@rng.rand(q2_templates.size)],
        answer: "Ao falar diretamente com a equipe da <strong>#{trade_name}</strong> por telefone ou WhatsApp, você negocia com transparência de preços, peças e prazos de entrega, sem taxas de intermediação de aplicativos terceiros."
      },
      {
        question: q3_templates[@rng.rand(q3_templates.size)],
        answer: "O estabelecimento atua no segmento de <strong>#{cnae_main_text}</strong>, atendendo proprietários de veículos e motoristas que buscam manutenção preventiva e corretiva com diagnóstico de qualidade em <strong>#{city_name} - #{state_acronym}</strong>."
      },
      {
        question: q4_templates[@rng.rand(q4_templates.size)],
        answer: "A oficina <strong>#{trade_name}</strong> está localizada na <strong>#{street_text}, nº #{number_text}#{complement_text}</strong>, bairro <strong>#{neighborhood_name}</strong>, <strong>#{city_name} - #{state_acronym}</strong> (CEP <strong>#{zip_code_text}</strong>)."
      },
      {
        question: q5_templates[@rng.rand(q5_templates.size)],
        answer: "Você pode clicar no botão 'WhatsApp Direto' ou revelar os telefones de contato nesta página para falar instantaneamente com a equipe técnica da <strong>#{trade_name}</strong> em <strong>#{city_name}</strong>."
      },
      {
        question: q6_templates[@rng.rand(q6_templates.size)],
        answer: partners_formatted_list
      },
      {
        question: q7_templates[@rng.rand(q7_templates.size)],
        answer: @company.opening_date.present? ? "A empresa atua no setor automotivo regional desde <strong>#{opening_date_str}</strong>, acumulando cerca de <strong>#{years_str} ano(s)</strong>#{months_str != '0' ? " e <strong>#{months_str} mês(es)</strong>" : ""} de experiência em manutenção veicular." : "O estabelecimento possui cadastro ativo e regular no setor de serviços mecânicos em <strong>#{city_name}</strong>."
      },
      {
        question: q8_templates[@rng.rand(q8_templates.size)],
        answer: "A situação cadastral da empresa perante a Receita Federal é <strong>#{status_text}</strong>, confirmando sua operação regular e idônea no mercado de <strong>#{city_name}</strong>."
      },
      {
        question: q9_templates[@rng.rand(q9_templates.size)],
        answer: "O estabelecimento opera sob a razão social <strong>#{legal_name}</strong> (CNPJ <strong>#{formatted_cnpj}</strong>) com porte registrado de <strong>#{company_size_text}</strong> e capital social declarado de <strong>#{capital_social_text}</strong>, garantindo total conformidade legal aos clientes."
      },
      {
        question: q10_templates[@rng.rand(q10_templates.size)],
        answer: "Basta clicar nos botões de contato nesta página para abrir conversa direta no WhatsApp ou ligar para a oficina em <strong>#{city_name}</strong> sem taxas de intermediação."
      }
    ]

    faqs
  end

  private

  def block_foundation
    if @company.opening_date.blank?
      templates = [
        "A oficina automotiva %{company_name} é um estabelecimento ativo de serviços mecânicos na cidade de %{city} - %{state}.",
        "Com excelente localização em %{city}, a %{company_name} atende motoristas e proprietários de veículos buscando diagnósticos precisos e bom atendimento.",
        "Sediada no município de %{city}/%{state}, a %{company_name} oferece serviços especializados de manutenção veicular.",
        "A %{company_name} opera na cidade de %{city} mantendo o compromisso de atendimento técnico transparente e ágil.",
        "Com registro regularizado perante os órgãos competentes, a %{company_name} atua no segmento de reparação automotiva em %{city} - %{state}."
      ]

      index = @rng.rand(templates.size)
      format(templates[index],
        company_name: "<strong>#{trade_name}</strong>",
        city: "<strong>#{city_name}</strong>",
        state: "<strong>#{state_acronym}</strong>"
      )
    else
      templates = [
        "A %{company_name} iniciou suas atividades em %{opening_date}, contando com mais de %{years} de tradição em serviços mecânicos na região.",
        "Com fundação em %{opening_date}, a %{company_name} vem acumulando %{years} de experiência técnica no setor automotivo.",
        "Aberta formalmente em %{opening_date}, a %{company_name} acumula %{years} e %{months} de história e dedicação em %{city}.",
        "Em %{year_founded} (precisamente em %{opening_date}), a %{company_name} deu início aos seus trabalhos na área de reparação automotiva.",
        "Registrada e inaugurada em %{opening_date}, a %{company_name} possui uma trajetória consolidada de %{years} em manutenção de veículos.",
        "A %{company_name} foi fundada no dia %{opening_date} e soma hoje %{years} de atuação ativa no mercado mecânico.",
        "Desde o início de suas operações em %{opening_date}, a %{company_name} consolida sua presença automotiva em %{city} há %{years}.",
        "Na data de %{opening_date}, foi oficialmente aberta a %{company_name}, completando %{years} de atendimento qualificado a motoristas.",
        "Estabelecida em %{year_founded} (em %{opening_date}), a %{company_name} preserva %{years} de serviços técnicos dedicados aos clientes.",
        "Com início das atividades datado em %{opening_date}, a %{company_name} soma %{years} de constante evolução no segmento automotivo regional."
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
      "Localizada na %{street}, nº %{number}, no bairro %{neighborhood} em %{city} - %{state} (CEP %{zip_code}), oferece fácil acesso para os motoristas da região.",
      "A estrutura da %{company_name} encontra-se situada na %{street}, nº %{number}, bairro %{neighborhood}, no município de %{city}/%{state}.",
      "Com endereço registrado na %{street}, nº %{number} (%{neighborhood}, %{city} - %{state}), posiciona-se estrategicamente para receber veículos com agilidade.",
      "Situada no bairro %{neighborhood}, na %{street}, nº %{number} em %{city} (%{state}), proporciona conveniente localização para revisões e reparos.",
      "Instalada no município de %{city} - %{state}, a %{company_name} está localizada na %{street}, nº %{number}, %{neighborhood}.",
      "A oficina fica no endereço %{street}, nº %{number} - %{neighborhood}, na cidade de %{city} - %{state}, sob o CEP %{zip_code}.",
      "Operando em %{city}/%{state}, o centro automotivo fica na %{street}, nº %{number}, no bairro %{neighborhood}.",
      "Encontrada na %{street}, nº %{number} em %{city} - %{state}, a %{company_name} atende clientes no bairro %{neighborhood} e regiões vizinhas.",
      "A oficina está sediada em %{city} - %{state}, no bairro %{neighborhood}, na %{street}, nº %{number}.",
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
      "Sua atividade econômica principal, conforme cadastro oficial na Receita Federal, é %{cnae_main}%{cnae_secondaries}.",
      "O estabelecimento é cadastrado no segmento de %{cnae_main}, atuando com foco em precisão técnica e segurança veicular%{cnae_secondaries}.",
      "Tendo como atividade registrada o setor de %{cnae_main}, a %{company_name} oferece serviços de manutenção automotiva%{cnae_secondaries}.",
      "O campo de atuação prioritário da empresa contempla %{cnae_main}%{cnae_secondaries}.",
      "Classificada sob o CNAE principal %{cnae_main}, a organização integra a rede de serviços automotivos da região%{cnae_secondaries}.",
      "Com registro para execução de %{cnae_main}, a empresa atende rigorosamente aos padrões cadastrais oficiais%{cnae_secondaries}.",
      "O ramo mercantil principal da %{company_name} abrange %{cnae_main}%{cnae_secondaries}.",
      "Dedicada ao setor de %{cnae_main}, a oficina contribui para a mobilidade e segurança dos veículos em %{city}%{cnae_secondaries}.",
      "Com habilitação cadastral em %{cnae_main}, destaca-se no setor de reparação e cuidados mecânicos%{cnae_secondaries}.",
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
      "Para solicitar um orçamento prévio ou tirar dúvidas sobre o seu veículo na cidade de %{city}, entre em contato via WhatsApp ou telefone diretamente com a oficina.",
      "Precisa de manutenção com preço justo e transparência em %{city}? Fale direto com a equipe da %{company_name} através dos contatos exibidos no portal.",
      "Consulte prazos e valores de serviços mecânicos na %{company_name} em %{city} sem pagar taxas para intermediários.",
      "Para obter informações sobre diagnósticos automotivos e serviços em %{city}, acesse os canais de contato direto da %{company_name}.",
      "A equipe da %{company_name} atende clientes na cidade de %{city} e região oferecendo atendimento técnico direto e confiável.",
      "Dúvidas sobre o conserto do seu carro em %{city}? Fale com a equipe da %{company_name} pelo WhatsApp Direto.",
      "Garanta um serviço de confiança e orçamento transparente para seu carro em %{city} conectando-se diretamente com a %{company_name}.",
      "Para agendamentos e suporte automotivo em %{city}, acione o atendimento telefônico ou WhatsApp da %{company_name}.",
      "A %{company_name} disponibiliza atendimento direto aos motoristas no município de %{city}.",
      "Conecte-se com a %{company_name} em %{city} e solicite seu orçamento mecânico direto sem comissões."
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
