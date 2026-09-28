# 🎯 Plano de Ação: Resolução de Violação do AdSense ("Low Value Content" / Conteúdo de Baixo Valor)

**Projeto:** `Hospedagem Direta` / Plataformas de Diretório pSEO  
**Data:** 2026-08-07  
**Status:** Planejado / Em Execução  

---

### 1. Estratégia do "Portal Editorial" (Aprovação do Domínio no AdSense)
- [x] **Criar área de Blog / Guias**: Estruturar rotas `/blog`.
- [x] **Produção de Conteúdo Rico**: Escrever de **16 artigos originais** (entre 800 e 1500+ palavras) sobre temas relevantes do nicho (exclusivamente focados em reservas diretas, direitos, dicas de acomodação, economia e segurança, sem duplicar guias de destinos):
  - *"Como reservar pousadas direto com proprietários sem taxas de comissão"*
  - *"Direitos do hóspede em cancelamentos e reservas diretas"*
  - *"Diferenças entre Flat, Apart-hotel e Aluguel de Temporada"*
  - +13 artigos conceituais e guias práticos.
- [x] **Reestruturar Navegação Inicial**: Colocar o Blog/Guias em evidência no menu principal (desktop e mobile) e no rodapé.

---

### 2. Enriquecimento Programático de Conteúdo (Combate ao *Thin Content*)
- [ ] **Textos Introdução/Resumo por Cidade e Estado**:
  - Adicionar blocos de texto dinâmicos nas páginas de listagem regional (ex: resumo da região, clima, pontos turísticos próximos e dicas de acesso).
- [ ] **Seção de FAQ Dinâmico (`FAQPage` Schema)**:
  - Adicionar bloco de Perguntas Frequentes por cidade/categoria (ex: *"Qual a melhor época para se hospedar em [Cidade]?"*, *"Como funciona a busca por pousadas diretas em [Cidade]?"*).
- [ ] **Estatísticas e Dados Agregados Locais**:
  - Exibir agregados calculados: *"Temos X estabelecimentos ativos em [Cidade], distribuídos em Y pousadas e Z hotéis"*.
- [ ] **Dados Estruturados (Rich Snippets JSON-LD)**:
  - Implementar Schemas `LodgingBusiness`, `Hotel`, `FAQPage` e `BreadcrumbList` nas views Rails.

---

### 3. Indexação Seletiva (`noindex` Temporário)
- [ ] **Identificar Páginas Escassas**: Perfis importados sem foto, sem descrição expandida ou sem avaliações.
- [ ] **Aplicar Tag Meta de Bloqueio**:
  ```html
  <meta name="robots" content="noindex, follow">
  ```
- [ ] **Liberar Conforme Preenchimento**: Remover o `noindex` assim que o proprietário reivindicar o perfil ou adicionar conteúdo rico/fotos.

---

### 4. Páginas Institucionais Obrigatórias (Trust Signal)
- [ ] **Sobre Nós** (`/sobre`): Detalhar a missão da plataforma (busca e reserva direta sem comissões).
- [ ] **Política de Privacidade** (`/privacidade`): Atualizar cláusulas relativas a cookies e AdSense/Google Analytics.
- [ ] **Termos de Uso** (`/termos`).
- [ ] **Página de Contato** (`/contato`): Formulário funcional ou e-mail de suporte visível.
