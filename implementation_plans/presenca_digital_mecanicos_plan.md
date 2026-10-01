# 🚀 Plano de Implementação: Pacote Presença Digital Automática & Mini-Sites

**Projeto:** Melhores Mecânicos (e Diretórios Verticais)  
**Data:** 2026-09-29  
**Status:** Planejado (Guia Superficial / Roadmap)  
**Objetivo:** Transformar o diretório de dados públicos em uma plataforma de presença digital e captação de clientes para pequenas oficinas, monetizando com plano de assinatura self-service (R$ 39,90 a R$ 49,90/mês) sem necessidade de vendas ativas.

---

## 💡 A Dor e a Oportunidade
- **O problema do mecânico:** Sabe consertar carros, mas não domina o Google Meu Negócio, não tem tempo/conhecimento para criar um site e depende unicamente do boca a boca ou posts esporádicos em redes sociais pessoais.
- **A solução:** Ao reivindicar o perfil já existente na base, ele ganha instantaneamente um **Mini-Site de Alta Conversão**, um **Assistente de Google Meu Negócio** e ferramentas para receber orçamentos direto no WhatsApp.
- **Vantagem de infraestrutura:** Custo marginal zero na Hetzner (mesma stack Rails renderizando páginas dinâmicas e gerenciamento de perfis).

---

## 🛠️ Pilares de Implementação

### 1. Reivindicação & Mini-Site Dinâmico de Alta Conversão
- [ ] **Fluxo de Reivindicação ("Reivindicar esta Oficina")**:
  - Mecânico encontra a própria oficina no diretório ou via link direto e clica em reivindicar.
  - Verificação simplificada (validação por WhatsApp/SMS ou confirmação de dados da empresa/CNPJ).
- [ ] **Mini-Site / Página Pública Otimizada**:
  - Slug amigável (ex: `/sp/guaratingueta/mecanica-joao-dos-santos`).
  - Foto de capa, fotos da oficina e logotipo.
  - Seleção de especialidades/serviços com tags (ex: Freios, Injeção Eletrônica, Câmbio Automático, Ar Condicionado, Troca de Óleo, Suspensão).
  - Horário de funcionamento e endereço integrado com mapa interativo.
- [ ] **Botão Flutuante de Orçamento via WhatsApp**:
  - Modal rápido ou clique direto que já abre o WhatsApp com mensagem estruturada (ex: *"Olá, vi sua oficina no Melhores Mecânicos e gostaria de um orçamento para meu carro [Modelo/Ano] - Problema: [...]"*).

---

### 2. Assistente de Google Meu Negócio (GBP) & Reputação Local
- [ ] **Guia Passo a Passo no Painel ("Setup Wizard")**:
  - Roteiro visual guiando a criação/reivindicação da ficha no Google com dados já pré-preenchidos (categoria correta, descrição com SEO local, telefone e horário).
- [ ] **Gerador de Link Direto de Avaliações**:
  - Instruções ou ferramenta para gerar o link curto oficial de review 5 estrelas do Google.
- [ ] **[Sugestão] Material de Balcão (QR Code em PDF)**:
  - O sistema gera um PDF pronto para impressão com QR Code *"Avalie nosso atendimento no Google"* para colocar no balcão da oficina.
- [ ] **[Sugestão] Disparador Rápido de Review pós-serviço**:
  - Botão no painel para o mecânico enviar por WhatsApp ao cliente: *"Obrigado pela preferência! Poderia nos avaliar no Google em 10 segundos? [link]"*.

---

### 3. Painel do Dono & Métricas de Valor Tangível
- [ ] **Dashboard com Métricas Sem Jargão Técnico**:
  - Quantidade de cliques no botão de WhatsApp / pedidos de orçamento.
  - Quantidade de visualizações de telefone e endereço/rota no mapa.
  - Total de visitas no mini-site no mês.
- [ ] **Sensação de Retorno do Investimento**:
  - O mecânico percebe claramente: *"Esse mês, 18 pessoas clicaram para falar comigo no WhatsApp através da minha página"*.

---

### 4. Modelo de Monetização & Gatilho do Paywall (Freemium ➔ Pro)
- [ ] **Plano Gratuito (Ativação e Experimentação)**:
  - Mini-site funcional básico com dados de contato e mapa.
  - Selo discreto "Hospedado por Melhores Mecânicos".
  - Exibição de oficinas recomendadas/vizinhas na região.
- [ ] **Plano Pro (R$ 39,90 ou R$ 49,90 / mês via PIX / Cartão)**:
  - **Destaque no topo** nas buscas da cidade/bairro.
  - **Selo de Oficina Verificada**.
  - **Remoção de concorrentes** da página dele.
  - **Gerador de QR Code de Balcão** e ferramentas de disparo de review.
  - Suporte futuro a subdomínio exclusivo ou domínio próprio (`oficinajoao.com.br`).

---

### 5. Arquitetura Replicável para Outros Nichos
- [ ] Manter a estrutura desacoplada para que os componentes de claim, mini-site, assistente de presença e métricas possam ser instanciados para os demais verticais já catalogados (depósitos de construção, pousadas, autoescolas, etc.) apenas trocando temas e categorias de CNAE.
