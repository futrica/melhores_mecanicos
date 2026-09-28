# Hospedagem Direta - Guia Completo de Carga Inicial e Execução

Plataforma aberta e transparente para busca e reserva direta de hospedagens (hotéis, pousadas, apart-hotéis, hostels, chalés e alojamentos) em todo o Brasil, conectando viajantes e proprietários sem cobrança de comissões ou intermediários.

---

## 📋 Pré-requisitos do Sistema

- **Ruby**: `3.4+`
- **Rails**: `8.1+`
- **Ferramentas do Sistema Operacional**: `curl` e `unzip` (necessários para os scripts de download automático dos dados públicos da Receita Federal).

---

## 🚀 Guia Completo de Carga Inicial (Import de CNPJs)

A carga inicial consolida os dados de estabelecimentos ativos de hospedagem de todo o Brasil a partir de bases oficiais públicas da **Receita Federal do Brasil (RFB)** e do **IBGE**.

Siga a ordem dos comandos abaixo para realizar a carga completa no ambiente local ou servidor:

### 1. Seed de Categorias Base e Administrador
Popula as 5 categorias oficiais de hospedagem e cria o usuário administrador do sistema:
```bash
bin/rails db:seed
```

### 2. Importação da Malha Territorial (Estados e Cidades IBGE)
Busca todos os Estados e Cidades do Brasil diretamente da API oficial do IBGE:
```bash
bin/rails import:ibge_cities
```

### 3. Download e Importação de Estabelecimentos (Receita Federal)
Baixa e processa automaticamente os 10 arquivos compactados da Receita Federal (`Estabelecimentos0.zip` a `Estabelecimentos9.zip`). Importa estabelecimentos ativos que possuam os CNAEs primários ou secundários de hospedagem:
```bash
bin/rails import:download_and_import
```
> 💡 **Dica de Resumo / Retomada**: Se a conexão for interrompida ou desejar iniciar de um arquivo específico (ex: a partir do arquivo 4), utilize a variável `START_INDEX`:
> ```bash
> START_INDEX=4 bin/rails import:download_and_import
> ```

### 4. Importação de Razão Social e Porte (Empresas RFB)
Associa Razão Social, Porte (ME/EPP), Natureza Jurídica e Capital Social aos estabelecimentos importados:
```bash
bin/rails import:legal_names
```

### 5. Importação do Quadro Societário (Sócios RFB)
Importa o Quadro de Sócios e Administradores (QSA) com qualificação e faixa etária:
```bash
bin/rails import:partners
```

### 6. Limpeza e Sanitização do Banco de Dados
Remove registros de bairros inconsistentes (CEPs, caracteres isolados) e empresas falidas ou em liquidação judicial:
```bash
bin/rails import:clean_invalid_neighborhoods
bin/rails import:clean_bankrupt_companies
```

### 7. Geocodificação Exata (Coordenadas de Latitude e Longitude)
Atribui coordenadas aos estabelecimentos para exibição em mapas (via Nominatim):
```bash
bin/rails geocode:companies
```

### 8. Geração de Sitemaps pSEO
Gera o `sitemap_index.xml` e os sitemaps fracionados por Estado para indexação no Google:
```bash
BASE_URL="https://hospedagemdireta.com.br" bin/rails sitemap:generate
```

### 9. Limpeza de Arquivos Temporários (Backups e Downloads)
Remove backups residuais (`tmp/backups/`), downloads temporários da Receita Federal (`tmp/cnpj_download/`) e caches do Rails:
```bash
bin/rails tmp:clear

# (Deploy desativado temporariamente)
# kamal app exec "bin/rails tmp:clear"
```

### 10. Geração de Report da saúde da máquina
```bash
# kamal app exec "bin/rails runner 'ServerHealthReportJob.perform_now'"
```

---

## 🏷️ CNAEs do Segmento de Hospedagem Suportados

O filtro de importação considera **CNAEs Principais e Secundários**:

| Código CNAE | Classificação / Categoria | Descrição |
| :--- | :--- | :--- |
| **5510-8/01** | Hotéis e Pousadas | Hotéis, pousadas, hotéis-fazenda e spas com alojamento |
| **5510-8/02** | Apart-hotéis | Empreendimentos no formato apart-hotel |
| **5590-6/01** | Albergues e Hostels | Hostels e albergues não assistenciais |
| **5590-6/03** | Pensões e Alojamentos | Pensões e alojamentos de gestão familiar |
| **5590-6/99** | Outras Hospedagens | Estalagens, dormitórios, hospedarias e temporada |

---

## 💻 Executando a Aplicação Localmente

1. **Instalar dependências**:
   ```bash
   bundle install
   ```

2. **Subir o servidor de desenvolvimento**:
   ```bash
   bin/dev
   # ou
   bin/rails server
   ```

3. **Executar a suíte de testes (RSpec)**:
   ```bash
   bundle exec rspec
   ```

---

## ⚠️ Regras de Operação e Deploy

- **Deploy**: O deploy (`kamal deploy`) está **DESATIVADO** e só será reativado quando o novo servidor for configurado e **exclusivamente sob solicitação expressa do usuário**.
- **Commits**: Mantidos de forma limpa e organizada no repositório.

