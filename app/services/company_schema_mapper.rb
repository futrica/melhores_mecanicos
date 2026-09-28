class CompanySchemaMapper
  # Map CNAE codes & prefixes (7, 4, 3, or 2 digits) to Schema.org types for rich snippets
  CNAE_PREFIX_MAP = {
    # 1. Comércio Varejista (Divisões 47 e 45)
    "4744001" => "HardwareStore",
    "4744002" => "BuildingSupplyStore",
    "4744003" => "HomeGoodsStore",
    "4744004" => "BuildingSupplyStore",
    "4744005" => "BuildingSupplyStore",
    "4744006" => "BuildingSupplyStore",
    "4744099" => "BuildingSupplyStore",
    "4744"    => "BuildingSupplyStore",
    "4743"    => "HomeGoodsStore",
    "4741"    => "HomeGoodsStore",
    "4742"    => "HomeGoodsStore",
    "4751"    => "ElectronicsStore",
    "4752"    => "ElectronicsStore",
    "4753"    => "ElectronicsStore",
    "4754"    => "FurnitureStore",
    "4755"    => "HomeGoodsStore",
    "4759"    => "HomeGoodsStore",
    "4761"    => "BookStore",
    "4763"    => "SportingGoodsStore",
    "4771"    => "Pharmacy",
    "4772"    => "BeautySupplyStore",
    "4773"    => "Optician",
    "4781"    => "ClothingStore",
    "4782"    => "ShoeStore",
    "4783"    => "JewelryStore",
    "4785"    => "PawnShop",
    "4789"    => "PetStore",
    "4711"    => "Supermarket",
    "4712"    => "GroceryStore",
    "4713"    => "DepartmentStore",
    "4721"    => "Bakery",
    "4722"    => "ButcherShop",
    "4723"    => "GroceryStore",
    "4724"    => "GroceryStore",
    "4729"    => "GroceryStore",
    "4731"    => "GasStation",
    "4732"    => "AutoPartsStore",
    "4511"    => "AutoDealer",
    "4512"    => "AutoDealer",
    "4520"    => "AutoRepair",
    "4530"    => "AutoPartsStore",
    "4541"    => "MotorcycleDealer",
    "4542"    => "MotorcycleRepair",

    # 2. Alimentação & Hospedagem (Divisões 55 e 56)
    "5510801" => "Hotel",
    "5510802" => "Hotel",
    "5590601" => "Hostel",
    "5590603" => "LodgingBusiness",
    "5590699" => "LodgingBusiness",
    "5510"    => "Hotel",
    "5590"    => "LodgingBusiness",
    "5611"    => "Restaurant",
    "5612"    => "FoodEstablishment",
    "5620"    => "FoodEstablishment",

    # 3. Serviços Profissionais, Imobiliária & Saúde (Divisões 68, 69, 70, 71, 75, 86)
    "6910"    => "LegalService",
    "6920"    => "AccountingService",
    "6821"    => "RealEstateAgent",
    "6822"    => "RealEstateAgent",
    "7111"    => "ArchitecturalService",
    "7112"    => "EngineeringService",
    "7500"    => "VeterinaryCare",
    "8630"    => "MedicalClinic",
    "8640"    => "MedicalLaboratory",
    "8650"    => "MedicalBusiness",
    "8690"    => "MedicalBusiness",

    # 4. Serviços de Manutenção & Construção (Divisões 41, 42, 43, 95, 96)
    "4120"    => "GeneralContractor",
    "4321"    => "Electrician",
    "4322"    => "Plumber",
    "4330"    => "HousePainter",
    "4399"    => "GeneralContractor",
    "4313"    => "GeneralContractor",
    "3811"    => "RecyclingCenter",
    "9511"    => "ComputerRepair",
    "9512"    => "ElectronicsRepair",
    "9521"    => "ElectronicsRepair",
    "9529"    => "Locksmith",
    "9602"    => "BeautySalon",
    "9603"    => "FuneralHome",
    "9609"    => "PetGrooming"
  }.freeze

  def initialize(company, base_url: nil, reviews: nil)
    @company = company
    @base_url = base_url.to_s.chomp("/")
    @reviews = reviews
  end

  def schema_type
    clean_cnae = @company.cnae_principal.to_s.gsub(/\D/, "")

    if clean_cnae.present?
      [ clean_cnae, clean_cnae[0..3], clean_cnae[0..2], clean_cnae[0..1] ].each do |prefix|
        next if prefix.blank?
        return CNAE_PREFIX_MAP[prefix] if CNAE_PREFIX_MAP.key?(prefix)
      end
    end

    category_name = @company.categories.first&.name.to_s.downcase
    if category_name.include?("pousada")
      "BedAndBreakfast"
    elsif category_name.include?("hotel")
      "Hotel"
    elsif category_name.include?("restaurante")
      "Restaurant"
    elsif category_name.include?("farmácia") || category_name.include?("drogaria")
      "Pharmacy"
    elsif category_name.include?("construção") || category_name.include?("depósito")
      "BuildingSupplyStore"
    else
      "LocalBusiness"
    end
  end

  def to_schema_hash
    trade_name = @company.trade_name.presence || @company.legal_name

    hash = {
      "@context" => "https://schema.org",
      "@type" => schema_type,
      "name" => trade_name,
      "legalName" => @company.legal_name,
      "taxID" => @company.cnpj,
      "address" => {
        "@type" => "PostalAddress",
        "streetAddress" => "#{@company.street}, #{@company.number}",
        "addressLocality" => @company.city&.name,
        "addressRegion" => @company.state&.acronym,
        "postalCode" => @company.zip_code,
        "addressCountry" => "BR"
      },
      "telephone" => (@company.phone_1.presence || @company.phone_2.presence || ""),
      "email" => (@company.email.present? && !%w[null n/a].include?(@company.email.downcase.strip) ? @company.email.downcase : nil)
    }.compact

    if @company.logo_display_url.present?
      hash["image"] = @base_url + @company.logo_display_url
    end

    if @company.latitude.present? && @company.longitude.present?
      hash["geo"] = {
        "@type" => "GeoCoordinates",
        "latitude" => @company.latitude,
        "longitude" => @company.longitude
      }
    end

    avg_rating = @company.average_rating.to_f
    rev_list = @reviews.present? ? @reviews : @company.reviews
    rev_cnt = rev_list.respond_to?(:count) ? rev_list.count : Array(rev_list).size

    if avg_rating > 0 && rev_cnt > 0
      hash["aggregateRating"] = {
        "@type" => "AggregateRating",
        "ratingValue" => avg_rating,
        "reviewCount" => rev_cnt,
        "bestRating" => "5",
        "worstRating" => "1"
      }
    end

    hash
  end
end
