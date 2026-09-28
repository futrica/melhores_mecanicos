require 'rails_helper'

RSpec.describe CompaniesHelper, type: :helper do
  describe '#mask_phone' do
    it 'masks standard 10 or 11 digit phones' do
      expect(helper.mask_phone("(12) 3152-0000")).to eq("(12) 315****-****")
      expect(helper.mask_phone("(51) 9533-2938")).to eq("(51) 953****-****")
    end

    it 'returns empty string for blank input' do
      expect(helper.mask_phone(nil)).to eq("")
      expect(helper.mask_phone("")).to eq("")
    end
  end

  describe '#mask_email' do
    it 'masks email username and domain' do
      expect(helper.mask_email("karaja@empresa.com.br")).to eq("ka****@em****.com.br")
      expect(helper.mask_email("contato@loja.com")).to eq("co****@lo****.com")
    end

    it 'returns empty string for blank input' do
      expect(helper.mask_email(nil)).to eq("")
      expect(helper.mask_email("")).to eq("")
    end
  end

  describe '#is_valid_phone?' do
    it 'returns true for valid phone numbers' do
      expect(helper.is_valid_phone?("(11) 99999-8888")).to be true
      expect(helper.is_valid_phone?("1133334444")).to be true
    end

    it 'returns false for dummy or blank phone numbers' do
      expect(helper.is_valid_phone?(nil)).to be false
      expect(helper.is_valid_phone?("")).to be false
      expect(helper.is_valid_phone?("null")).to be false
      expect(helper.is_valid_phone?("N/A")).to be false
      expect(helper.is_valid_phone?("0000000000")).to be false
      expect(helper.is_valid_phone?("não informado")).to be false
    end
  end

  describe '#is_valid_email?' do
    it 'returns true for valid email addresses' do
      expect(helper.is_valid_email?("contato@pousada.com.br")).to be true
      expect(helper.is_valid_email?("empresa@gmail.com")).to be true
    end

    it 'returns false for dummy, invalid, or blank emails' do
      expect(helper.is_valid_email?(nil)).to be false
      expect(helper.is_valid_email?("")).to be false
      expect(helper.is_valid_email?("null")).to be false
      expect(helper.is_valid_email?("n/a")).to be false
      expect(helper.is_valid_email?("não informado")).to be false
      expect(helper.is_valid_email?("invalido_sem_arroba")).to be false
    end
  end
end
