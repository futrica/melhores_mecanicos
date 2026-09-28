# Plano de Implementação - Automação Fiscal (Focus NFe)

> **Gatilho de Execução**: Este plano deve ser executado **SOMENTE quando houver a 1ª venda realizada do Plano Premium** (R$ 39,90/mês).

---

## 📌 Contexto & Opção Selecionada

### **Focus NFe - Plano Solo**
- **CNPJ**: 1 CNPJ
- **Valor**: R$ 89,90 / mês
- **Incluso**: Pacote com 100 notas fiscais/mês
- **Nota adicional**: R$ 0,10 por nota adicional
- **Recursos**: Emissão de NFS-e (Nota Fiscal de Serviços Eletrônica) para qualquer município
- **Suporte**: E-mail (30 dias de teste grátis no cadastro)

---

## 📐 Arquitetura da Integração

```
[Stripe: Pagamento Confirmado]
            │
            ▼ Webhook (invoice.payment_succeeded)
[Rails API: /webhooks/stripe]
            │
            ▼ Background Job (IssueInvoiceJob)
[Focus NFe API: POST /v2/nfse]
            │
            ▼ Webhook Focus NFe Callback
[Rails: Salva PDF/XML em InvoiceLog & Envia E-mail à Pousada]
```

---

## 🛠️ Etapas Futuras de Desenvolvimento

### 1. **Configuração de Variáveis de Ambiente (`.env`)**
```env
FOCUS_NFE_API_KEY=sua_chave_focus_nfe
FOCUS_NFE_ENVIRONMENT=production # ou homologacao
```

### 2. **Criação do Modelo `InvoiceLog`**
Tabela para registro e acompanhamento fiscal das notas geradas:
- `company_id`: ID da pousada assinante
- `subscription_id`: ID da assinatura
- `focus_nfe_reference`: Código de referência enviado à Focus NFe
- `focus_nfe_id`: Protocolo retornado pela Focus NFe
- `status`: `processando`, `autorizada`, `erro`
- `amount_cents`: Valor da nota (R$ 39,90 = 3990)
- `pdf_url`: Link para download do PDF da NFS-e
- `xml_url`: Link para download do XML da NFS-e
- `error_message`: Mensagem de erro caso a prefeitura rejeite

### 3. **Integração com a API do Focus NFe (`FocusNfeService`)**
Serviço Ruby para envio dos dados no formato JSON da Focus NFe:
```json
{
  "data_emissao": "2026-08-13T13:25:00-03:00",
  "prestador": {
    "cnpj": "CNPJ_DA_SUA_EMPRESA",
    "inscricao_municipal": "SUA_INSCRICAO_MUNICIPAL",
    "codigo_municipio": "CODIGO_IBGE_DA_SUA_CIDADE"
  },
  "tomador": {
    "cnpj": "company.cnpj",
    "razão_social": "company.legal_name",
    "email": "company.email",
    "endereco": {
      "logradouro": "company.street",
      "numero": "company.number",
      "bairro": "company.neighborhood.name",
      "codigo_municipio": "company.city.ibge_code",
      "uf": "company.state.acronym",
      "cep": "company.zip_code"
    }
  },
  "servico": {
    "aliquota": 2.0,
    "discriminacao": "Assinatura mensal do Plano Premium Hospedagem Direta - Licenciamento de Software SaaS.",
    "iss_retido": false,
    "item_lista_servico": "1.03",
    "valor_servicos": 39.90
  }
}
```

### 4. **Escuta do Webhook do Stripe (`WebhooksController`)**
Tratar o evento `invoice.payment_succeeded`:
- Recuperar a empresa pagante através do `stripe_customer_id`.
- Disparar o job `IssueInvoiceJob.perform_later(company_id, payment_amount)`.

### 5. **Processamento Assíncrono (`IssueInvoiceJob`)**
- Chama o `FocusNfeService`.
- Atualiza o registro em `InvoiceLog`.
- Quando a NFS-e for autorizada, envia o e-mail transacional com o link para o PDF da nota.

---

## 🎯 Checklist para a Primeira Venda

- [ ] Cadastrar conta no Focus NFe (Plano Solo R$ 89,90/mês).
- [ ] Fazer upload do Certificado Digital e-CNPJ A1 na plataforma da Focus NFe.
- [ ] Configurar Inscrição Municipal da sua empresa na Focus NFe.
- [ ] Adicionar `FOCUS_NFE_API_KEY` às credenciais/ambiente.
- [ ] Rodar a migration de `invoice_logs`.
- [ ] Ativar o `IssueInvoiceJob` no webhook do Stripe.
