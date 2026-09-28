require "test_helper"

class CompanyTest < ActiveSupport::TestCase
  test "find_matching_company_for matches custom domain" do
    comp = Company.create!(
      state: states(:sp), city: cities(:guara), cnpj: "99887766000101",
      legal_name: "Pousada Propria Ltda", email: "atendimento@pousadapropria.com.br",
      cnae_principal: "5510801", status: "Ativa"
    )

    match = Company.find_matching_company_for("gerente@pousadapropria.com.br")
    assert_equal comp, match
  end

  test "find_matching_company_for ignores public email domains for domain matching" do
    Company.create!(
      state: states(:sp), city: cities(:guara), cnpj: "99887766000102",
      legal_name: "Public Domain Pousada", email: "vendas@aol.com",
      cnae_principal: "5510801", status: "Ativa"
    )

    %w[joao@gmail.com pedro@hotmail.com maria@bol.com.br carlos@uol.com.br outro@aol.com].each do |public_email|
      assert_nil Company.find_matching_company_for(public_email), "Should not match domain for #{public_email}"
    end
  end
end
