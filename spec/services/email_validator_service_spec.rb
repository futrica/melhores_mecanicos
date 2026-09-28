require 'rails_helper'

RSpec.describe EmailValidatorService, type: :service do
  describe '.valid_format?' do
    it 'returns true for valid emails' do
      expect(EmailValidatorService.valid_format?('contato@empresa.com.br')).to be true
      expect(EmailValidatorService.valid_format?('user.name+tag@domain.org')).to be true
    end

    it 'returns false for invalid emails' do
      expect(EmailValidatorService.valid_format?('invalid_email')).to be false
      expect(EmailValidatorService.valid_format?('@domain.com')).to be false
      expect(EmailValidatorService.valid_format?('')).to be false
      expect(EmailValidatorService.valid_format?(nil)).to be false
    end
  end

  describe '.has_valid_mx?' do
    before { EmailValidatorService.clear_cache! }

    it 'returns true if DNS resolves MX records' do
      dns_mock = instance_double(Resolv::DNS)
      allow(Resolv::DNS).to receive(:open).and_yield(dns_mock)
      allow(dns_mock).to receive(:getresources).and_return([ double('mx') ])

      expect(EmailValidatorService.has_valid_mx?('teste@gmail.com')).to be true
    end

    it 'returns false if DNS resolves no MX records' do
      dns_mock = instance_double(Resolv::DNS)
      allow(Resolv::DNS).to receive(:open).and_yield(dns_mock)
      allow(dns_mock).to receive(:getresources).and_return([])

      expect(EmailValidatorService.has_valid_mx?('teste@domaininexistente12345.com')).to be false
    end
  end

  describe '.microsoft_domain?' do
    it 'returns true for Microsoft domains (hotmail, outlook, live, msn)' do
      expect(EmailValidatorService.microsoft_domain?('user@hotmail.com')).to be true
      expect(EmailValidatorService.microsoft_domain?('user@hotmail.com.br')).to be true
      expect(EmailValidatorService.microsoft_domain?('user@outlook.com')).to be true
      expect(EmailValidatorService.microsoft_domain?('user@outlook.com.br')).to be true
      expect(EmailValidatorService.microsoft_domain?('user@live.com')).to be true
      expect(EmailValidatorService.microsoft_domain?('user@msn.com')).to be true
    end

    it 'returns false for non-Microsoft domains' do
      expect(EmailValidatorService.microsoft_domain?('user@gmail.com')).to be false
      expect(EmailValidatorService.microsoft_domain?('user@pousada.com.br')).to be false
      expect(EmailValidatorService.microsoft_domain?('user@yahoo.com.br')).to be false
    end
  end

  describe '.uol_domain?' do
    it 'returns true for UOL ISP domains (uol, bol, zipmail, folha)' do
      expect(EmailValidatorService.uol_domain?('user@uol.com.br')).to be true
      expect(EmailValidatorService.uol_domain?('user@bol.com.br')).to be true
      expect(EmailValidatorService.uol_domain?('user@zipmail.com.br')).to be true
      expect(EmailValidatorService.uol_domain?('user@folha.com.br')).to be true
    end

    it 'returns false for non-UOL domains' do
      expect(EmailValidatorService.uol_domain?('user@gmail.com')).to be false
      expect(EmailValidatorService.uol_domain?('user@hotmail.com')).to be false
      expect(EmailValidatorService.uol_domain?('user@pousada.com.br')).to be false
    end
  end
end
