# =============================================================================
# R/pag_objetivos.R - funções das páginas de Objetivos (OE1 a OE6) e de Áreas-piloto
# =============================================================================
# Usar depois de R/funcoes.R, no primeiro chunk da página:
#
#   ```{r}
#   #| include: false
#   source(file.path(Sys.getenv("QUARTO_PROJECT_DIR", "."), "R", "funcoes.R"))
#   source(file.path(RAIZ, "R", "pag_objetivos.R"))
#   ```
#
# Lê só dados_site/ e objetivos/dados/ (este último gravado por
# scripts/06_preparar_oe1.py, a partir do PRODES oficial do INPE).
#
# -----------------------------------------------------------------------------
# OBJETOS
#   FASES        as 3 fases da metodologia da proposta (nome curto)
#   OES          tibble dos 6 objetivos: oe, nome, fase, pergunta, entrega,
#                situacao (concluido|andamento|confirmar|previsto), pagina
#   MARCOS       tibble dos marcos do cronograma: ano, mes, item, situacao, nota
#   PIL_PAGINA   slug do piloto -> página em pilotos/ (sem .html)
#   PIL_INFO     lista por slug: modalidade (texto), homonimos (chr), notas (chr)
#   PRODES_RES   resumo municipal do PRODES (janelas 2017–2025 e 2025)
#   PRODES_FONTE arquivos de origem do PRODES municipal (URL, versão, datas)
#   AREA_MUN     área de cada município (km²), calculada sobre a malha do IBGE
#
# FUNÇÕES - comuns
#   estilo_paginas()             -> <style> com as classes destas páginas
#   rolagem(...)                 -> div que rola na horizontal no celular
#   cartao_tot(id, fmt, sufixo = "", rotulo = NULL, comp = NULL) -> cartão de um total estadual
#                                (totais_mt.csv), com unidade, ano e fonte
#   links_indicadores(dims, prefixo = "../indicadores/") -> lista de indicadores por tema
# FUNÇÕES - objetivos
#   oe_tela(oe)                  -> OE1 na tela (SO1 em inglês); a chave continua OE1
#   tabela_oes(prefixo = "")     -> tabela OE x fase x pergunta x entrega x situação
#   linha_tempo()                -> marcos de 2026 e 2027 com selo de situação
#   bloco_situacao(oe, itens)    -> caixa "Situação" com selo e lista de itens
#                                   itens = list(c(estado, texto), ...)
#   nav_oes(oe)                  -> ← anterior · todos · próximo →
#   grafico_prodes_taxa()        -> SVG da taxa anual de MT (Amazônia Legal)
#   grafico_prodes_bioma()       -> SVG do incremento anual de MT por bioma
#   tabela_prodes_mun()          -> reactable dos 141 municípios (2017–2025 e 2025)
#   mapa_prodes_mun(campo)       -> leaflet; campo "km2" ou "pct" (2017–2025)
#   grafico_seeg_setor()         -> SVG das emissões de MT por setor (1990–2024)
#   tabela_seeg_ano(ano = 2024)  -> tabela das emissões de MT por setor no ano
#   tabela_tipos_m1()            -> tabela dos 5 tipos do M1 (rótulos provisórios)
# FUNÇÕES - áreas-piloto
#   url_piloto(slug, prefixo = "")  -> página do piloto
#   cartoes_pilotos(prefixo = "")   -> 3 cartões com link
#   tabela_pilotos()                -> identificação das 3 áreas
#   ident_piloto(slug)              -> lista de identificação da área
#   homonimos(slug = NULL)          -> aviso de homônimos (de uma área ou de todas)
#   kpi_mun(id, mun_id)             -> cartão de um indicador, rotulado como do município
#   o_que_vem()                     -> lista das próximas etapas, sem datas
# =============================================================================

# ---- Estilo ----------------------------------------------------------------------
estilo_paginas <- function() tags$style(HTML("
.rolagem { overflow-x: auto; -webkit-overflow-scrolling: touch; margin: .8rem 0 1.2rem; }
.tabela-oe { width: 100%; min-width: 640px; border-collapse: collapse; font-size: .88rem; }
.tabela-oe th { background: #f4f8f6; color: #1F4D3A; text-align: left; padding: .45rem .6rem; border-bottom: 2px solid #dde1ea; }
.tabela-oe td { padding: .5rem .6rem; border-bottom: 1px solid #eef0f4; vertical-align: top; }
.tabela-oe td:first-child { white-space: nowrap; font-weight: 600; }
.tabela-oe td:first-child .sub { white-space: normal; }
.ano-marcos { margin: 1rem 0 .3rem; font-size: 1.05rem; }
.marcos { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: .7rem; margin: .3rem 0 1.2rem; }
@media (max-width: 991px) { .marcos { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
@media (max-width: 576px) { .marcos { grid-template-columns: 1fr; } }
.marco { border: 1px solid #dde1ea; border-top: 4px solid #cbd5e1; border-radius: 8px; padding: .65rem .8rem; background: #fff; }
.marco-concluido { border-top-color: #1b7f4b; } .marco-andamento { border-top-color: #1d4f91; } .marco-previsto { border-top-color: #9ca3af; }
.marco-confirmar { border-top-color: #d4a017; }
.marco h4 { font-size: .95rem; margin: 0 0 .45rem 0; }
.marco ul { list-style: none; padding: 0; margin: 0; font-size: .84rem; }
.marco li { margin-bottom: .45rem; line-height: 1.3; }
.marco .nota-marco, .bloco-situacao .nota-marco { display: block; font-size: .76rem; color: #6b7280; margin-top: .1rem; }
.bloco-situacao { border: 1px solid #dde1ea; border-left: 4px solid #1F4D3A; border-radius: 6px; padding: .7rem 1rem; background: #fafbfc; margin: .6rem 0 1.3rem; }
.bloco-situacao .cab { font-weight: 700; color: #1F4D3A; margin-bottom: .35rem; }
.bloco-situacao ul { list-style: none; margin: 0; padding: 0; }
.bloco-situacao li { margin: .3rem 0; }
.bloco-situacao .selo-situacao { margin-right: .4rem; }
.ident { display: grid; grid-template-columns: max-content minmax(0, 1fr); gap: .4rem 1rem; margin: .5rem 0 1rem; font-size: .93rem; }
.ident dt { font-weight: 600; color: #4b5563; } .ident dd { margin: 0; }
@media (max-width: 576px) { .ident { grid-template-columns: 1fr; gap: .1rem; } .ident dd { margin-bottom: .5rem; } }
.aviso-homonimo { background: #f8fafc; border-left: 4px solid #6b7280; padding: .5rem .9rem; font-size: .9rem; margin: .5rem 0 1rem; border-radius: 4px; }
.aviso-homonimo ul { margin: .2rem 0 0; padding-left: 1.1rem; }
.selo-mun { display: inline-block; font-size: .64rem; font-weight: 700; text-transform: uppercase; letter-spacing: .03em; color: #1F4D3A;
  background: #e6f0eb; border-radius: 6px; padding: 0 5px; margin-right: .3rem; vertical-align: 1px; }
.selo-lacuna { display: inline-block; font-size: .72rem; font-weight: 700; padding: 1px 8px; border-radius: 10px; white-space: nowrap; margin-right: .35rem; }
.lacuna-confirmada { background: #e0ecf8; color: #1d4f91; } .lacuna-parcial { background: #fff1d6; color: #7a4b00; }
.lista-lacunas { list-style: none; padding: 0; } .lista-lacunas li { margin: .45rem 0; }
.nao-se-aplica { color: #9ca3af; font-size: .8em; cursor: help; }
.tag-sede { display: inline-block; font-size: .66rem; font-weight: 700; color: #b45309; border: 1px solid #f3cf8a; background: #fff8eb; border-radius: 6px; padding: 0 4px; margin-left: .3rem; }
.nav-oes { display: flex; gap: .5rem; flex-wrap: wrap; margin: 1.5rem 0 .5rem; }
.nav-oes .btn { flex: 0 1 auto; }
@media (max-width: 576px) { .nav-oes .btn { flex: 1 1 45%; } }
.lista-ind-tema h4 { font-size: .95rem; margin: .8rem 0 .3rem; }
.lista-ind-tema ul { margin: 0 0 .5rem; padding-left: 1.1rem; font-size: .9rem; }
.kpi .kpi-meta .fonte-kpi { display: block; }
"))

rolagem <- function(...) div(class = "rolagem", ...)

# ---- Totais estaduais e lista de indicadores ----------------------------------------
tot <- function(id) { r <- TOT[TOT$id == id, ]; if (nrow(r) != 1) stop("total desconhecido: ", id); r }

cartao_tot <- function(id, fmt, sufixo = "", rotulo = NULL, comp = NULL) {
  r <- tot(id)
  cartao_kpi(if (is.null(rotulo)) r$rotulo else rotulo, paste0(fmt_valor(r$valor, fmt), sufixo),
             meta = sprintf("%s · %s · %s", r$unidade, r$ano, r$fonte), comp = comp)
}

links_indicadores <- function(dims, prefixo = "../indicadores/") {
  div(class = "lista-ind-tema", lapply(dims, function(d) {
    g <- IND[IND$dim == d, ]; g <- g[order(g$ordem), ]
    tagList(tags$h4(TEMAS[[d]]),
            tags$ul(lapply(seq_len(nrow(g)), function(i)
              tags$li(a(href = url_ind(g$id[i], prefixo), g$rotulo[i]),
                      span(class = "sub", sprintf(" · %s · %s", g$unidade[i], g$ano_ref[i]))))))
  }))
}

# ---- Objetivos ------------------------------------------------------------------------
FASES <- tr(c("1" = "Fase 1 · Diagnóstico e evidências",
              "2" = "Fase 2 · Estratégias e modelagem de viabilidade",
              "3" = "Fase 3 · Pacote Tecnológico e articulação"),
            c("1" = "Phase 1 · Assessment and evidence",
              "2" = "Phase 2 · Strategies and viability modelling",
              "3" = "Phase 3 · Technology Package and engagement"))

OES <- tibble::tribble(
  ~oe,   ~nome,                          ~fase, ~pergunta,
  ~entrega, ~situacao,
  "OE1", tr("Território e uso da terra", "Territory and land use"),    "1",
  tr("De que modo se alteraram o uso e a cobertura da terra e a estrutura da paisagem nas áreas-piloto?",
     "How have land use, land cover and landscape structure changed in the pilot areas?"),
  tr("Mapas de uso e cobertura da terra e análise de métricas de paisagem",
     "Land use and land cover maps; analysis of landscape metrics"), "andamento",
  "OE2", tr("Produção e renda", "Production and income"),             "1",
  tr("Quais são os custos, a renda e o emprego gerados pelos sistemas produtivos das famílias?",
     "What are the costs of the families’ production systems, and what income and employment do they generate?"),
  tr("Banco de dados de desempenho técnico e econômico; relatórios de diagnóstico socioeconômico e produtivo",
     "Technical and economic performance database; socioeconomic and production assessment reports"), "andamento",
  "OE3", tr("Ambiente e carbono", "Environment and carbon"),           "1",
  tr("Qual é o balanço de carbono desses sistemas e qual é a situação da água e do solo?",
     "What is the carbon balance of these systems, and what is the condition of water and soil?"),
  tr("Relatórios de balanço de carbono por área-piloto e indicadores socioambientais",
     "Carbon balance reports by pilot area; socio-environmental indicators"), "andamento",
  "OE4", tr("Cenários bioeconômicos", "Bioeconomic scenarios"),       "2",
  tr("A transição para práticas de baixo carbono é financeiramente viável, com e sem pagamento por serviços ambientais e receita de carbono?",
     "Is the transition to low-carbon practices financially viable, with and without payment for environmental services and carbon revenue?"),
  tr("Relatórios de cenários e de análise bioeconômica; ferramentas de avaliação de projetos",
     "Scenario and bioeconomic analysis reports; project assessment tools"), "andamento",
  "OE5", tr("Inovação e capital social", "Innovation and social capital"),    "3",
  tr("Quais fatores levam as famílias a adotar e difundir inovações, e de que modo se pode fortalecer a rede de atores?",
     "What factors lead families to adopt and spread innovations, and how can the network of actors be strengthened?"),
  tr("Relatórios das oficinas participativas; protocolos de engajamento comunitário",
     "Participatory workshop reports; community engagement protocols"), "previsto",
  "OE6", tr("Pacote Tecnológico", "Technology Package"),           "3",
  tr("De que modo os resultados podem ser reunidos em um pacote útil para as famílias e os gestores públicos?",
     "How can the results be brought together in a package that is useful to families and public officials?"),
  tr("Pacote Tecnológico “Floresta em Pé”; banco de dados curado; sumários para gestores, artigos e materiais didáticos",
     "“Floresta em Pé” (Standing Forest) Technology Package; curated database; summaries for public officials, articles and teaching materials"), "previsto"
)
OES$pagina <- tolower(OES$oe)

# Na tela, em inglês, OE1 vira SO1; a chave de OES continua OE1 (e o arquivo, oe1.qmd).
oe_tela <- function(oe) tr(oe, sub("^OE", "SO", oe))

tabela_oes <- function(prefixo = "") {
  linhas <- lapply(seq_len(nrow(OES)), function(i) { o <- OES[i, ]
    tags$tr(tags$td(a(href = paste0(prefixo, o$pagina, ".html"), oe_tela(o$oe)), tags$div(class = "sub", o$nome)),
            tags$td(FASES[[o$fase]]), tags$td(o$pergunta), tags$td(o$entrega),
            tags$td(selo_situacao(o$situacao)))
  })
  rolagem(tags$table(class = "tabela-oe",
                     tags$thead(tags$tr(tags$th(tr("Objetivo", "Objective")), tags$th(tr("Fase", "Phase")), tags$th(tr("Pergunta de pesquisa", "Research question")),
                                        tags$th(tr("Entrega principal", "Main deliverable")), tags$th(tr("Situação em 19/10/2026", "Status as at 19 Oct 2026")))),
                     tags$tbody(linhas)))
}

MARCOS <- tibble::tribble(
  ~ano, ~mes, ~item, ~situacao, ~nota,
  2026, 1,  tr("Início e organização da pesquisa; contratações e ajuste do cronograma", "Research launch and organisation; recruitment and schedule adjustment"), "concluido",
            tr("As áreas-piloto foram redefinidas em junho de 2026.", "The pilot areas were redefined in June 2026."),
  2026, 4,  tr("Levantamento de informações preliminares", "Gathering preliminary information"), "concluido",
            tr("Dados secundários dos 141 municípios e revisão de literatura.", "Secondary data for the 141 municipalities and a literature review."),
  2026, 4,  tr("Modelagem do banco de dados", "Modelling the database"), "andamento", "",
  2026, 8,  tr("Visita às áreas-piloto e reuniões com representantes das famílias", "Visit to the pilot areas and meetings with family representatives"), "confirmar",
            tr("Situação a confirmar pela coordenação: resta verificar se o reconhecimento de campo de agosto foi realizado nas áreas-piloto.",
               "Status to be confirmed by the project coordination team: it has yet to be verified whether the August field reconnaissance took place in the pilot areas."),
  2026, 12, tr("Levantamento de dados em campo", "Field data collection"), "previsto",
            tr("Sem data confirmada, uma vez que depende da aprovação do questionário pelo Comitê de Ética em Pesquisa.",
               "No confirmed date: this depends on the Research Ethics Committee approving the questionnaire."),
  2026, 12, tr("Modelagem dos bancos de dados", "Modelling the databases"), "andamento", "",
  2027, 1,  tr("Planejamento das oficinas de cocriação; bancos de dados preliminares", "Planning the co-creation workshops; preliminary databases"), "previsto", "",
  2027, 4,  tr("Modelos de simulação; refinamento dos bancos de dados", "Simulation models; refining the databases"), "previsto", "",
  2027, 8,  tr("Versão preliminar do Pacote Tecnológico; reuniões com as partes interessadas", "Preliminary version of the Technology Package; stakeholder meetings"), "previsto", "",
  2027, 12, tr("Relatórios finais", "Final reports"), "previsto", ""
)

linha_tempo <- function() {
  meses <- tr(c("jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"), MESES_EN)
  ordem <- c(concluido = 1, andamento = 2, confirmar = 3, previsto = 4)
  tagList(lapply(sort(unique(MARCOS$ano)), function(an) {
    m <- MARCOS[MARCOS$ano == an, ]
    tagList(tags$h3(class = "ano-marcos", an),
            div(class = "marcos", lapply(sort(unique(m$mes)), function(ms) {
              g <- m[m$mes == ms, ]
              pior <- names(ordem)[max(ordem[g$situacao])]
              div(class = paste("marco", paste0("marco-", pior)),
                  tags$h4(sprintf(tr("Marco %s/%d", "%s %d milestone"), meses[ms], an)),
                  tags$ul(lapply(seq_len(nrow(g)), function(i)
                    tags$li(selo_situacao(g$situacao[i]), " ", g$item[i],
                            if (nzchar(g$nota[i])) span(class = "nota-marco", g$nota[i])))))
            })))
  }))
}

bloco_situacao <- function(oe, itens) {
  o <- OES[OES$oe == oe, ]
  div(class = "bloco-situacao",
      div(class = "cab", tr("Situação em 19/10/2026: ", "Status as at 19 October 2026: "), selo_situacao(o$situacao)),
      tags$ul(lapply(itens, function(x) tags$li(selo_situacao(x[[1]]), " ", x[[2]],
                                                 if (length(x) > 2) span(class = "nota-marco", x[[3]])))),
      p(class = "nota-fonte", style = "margin:.4rem 0 0",
        tr("Os selos foram atribuídos com base no registro interno do projeto e ainda serão validados pela coordenação.",
           "The badges are based on the project’s internal record and have yet to be validated by the project coordination team.")))
}

nav_oes <- function(oe) {
  i <- match(oe, OES$oe)
  ant <- if (i > 1) OES[i - 1, ] else NULL; prox <- if (i < nrow(OES)) OES[i + 1, ] else NULL
  div(class = "nav-oes",
      if (!is.null(ant)) a(class = "btn btn-sm btn-outline-primary", href = paste0(ant$pagina, ".html"), paste("←", oe_tela(ant$oe), "·", ant$nome)),
      a(class = "btn btn-sm btn-outline-primary", href = "index.html", tr("Os seis objetivos", "All six objectives")),
      if (!is.null(prox)) a(class = "btn btn-sm btn-outline-primary", href = paste0(prox$pagina, ".html"), paste(oe_tela(prox$oe), "·", prox$nome, "→")))
}

# ---- PRODES (OE1) ----------------------------------------------------------------------
dob <- function(...) file.path(RAIZ, "objetivos", "dados", ...)
PRODES_RES   <- ler(dob("prodes_mt_municipios_resumo.csv"))
PRODES_FONTE <- ler(dob("prodes_mt_municipios_fonte.csv"))
PRODES_TAXA  <- ler(ds("prodes_mt_taxa.csv"))
PRODES_BIO   <- ler(ds("prodes_mt_bioma.csv"))
# Área municipal: projeção cônica equivalente de Albers para a América do Sul (a malha tem arestas
# que o s2 recusa; a área plana numa projeção equivalente não depende dele).
AREA_MUN <- tibble::tibble(id_municipio = GEO$id_municipio,
                           area_km2 = as.numeric(st_area(st_transform(GEO, "ESRI:102033"))) / 1e6)

fonte_prodes_mun <- function() {
  f <- PRODES_FONTE[1, ]
  sprintf(tr("Fonte: Elaboração própria com base em INPE, PRODES Amazônia, Cerrado e Pantanal (bioma), incremento anual de desmatamento por município, painel TerraBrasilis v%s (acesso em %s; atualização do INPE em %s). Área municipal: cálculo próprio sobre a Malha Municipal 2022 do IBGE.",
             "Source: authors’ calculations based on INPE, PRODES Amazon, Cerrado and Pantanal (biome), annual deforestation increment by municipality, TerraBrasilis dashboard v%s (accessed on %s; updated by INPE on %s). Municipal area: authors’ calculations using the IBGE 2022 Municipal Mesh."),
          f$versao_painel, tr(format(as.Date(f$data_acesso), "%d/%m/%Y"), data_en(f$data_acesso)), tr(format(as.Date(f$atualizacao_inpe), "%d/%m/%Y"), data_en(f$atualizacao_inpe)))
}

# soma estadual do incremento por bioma numa janela de anos (só períodos anuais)
prodes_soma <- function(bioma, anos) sum(PRODES_BIO$desmat_km2[PRODES_BIO$bioma == bioma & PRODES_BIO$ano %in% anos &
                                                                PRODES_BIO$n_anos == 1 & PRODES_BIO$status == "consolidado"])

grafico_prodes_taxa <- function() {
  t <- PRODES_TAXA[PRODES_TAXA$status == "consolidada", ]
  svg_linhas(list(list(nome = tr("Taxa anual de MT (Amazônia Legal)", "Annual rate for MT (Legal Amazon)"), cor = "#b42318", larg = 2.6, dash = "", x = t$ano, y = t$taxa_km2)),
             fmt = "int", titulo = tr("Taxa anual de desmatamento de MT, PRODES Amazônia Legal, km²", "Annual deforestation rate for MT, PRODES Legal Amazon, km²"))
}

grafico_prodes_bioma <- function() {
  anos <- 2008:2025
  ser <- lapply(BIOMAS, function(b) {
    x <- PRODES_BIO[PRODES_BIO$bioma == b & PRODES_BIO$n_anos == 1 & PRODES_BIO$status == "consolidado", ]
    list(nome = paste("PRODES", nome_bioma(b)), cor = COR_BIOMA[[b]], larg = 2.4, dash = "", x = anos, y = x$desmat_km2[match(anos, x$ano)])
  })
  svg_linhas(ser, fmt = "int", titulo = tr("Incremento anual de desmatamento em MT por bioma do PRODES, km²", "Annual deforestation increment in MT by PRODES biome, km²"))
}

COD_BIO <- c("Amazônia" = "amz", "Cerrado" = "cer", "Pantanal" = "pan", "Total" = "tot")

# Uma linha por município: j_<bioma> = 2017–2025 (NA fora da máscara do bioma), u_tot = 2025, pct = % do território
prodes_largo <- function() {
  r <- PRODES_RES
  pega <- function(b, j) { x <- r[r$bioma_prodes == b & r$janela == j, ]; setNames(x$desmat_km2, x$id_municipio) }
  d <- MUN[, c("id_municipio", "municipio", "slug", "bioma", "sede_piloto")]
  for (b in names(COD_BIO)) d[[paste0("j_", COD_BIO[[b]])]] <- unname(pega(b, "2017–2025")[as.character(d$id_municipio)])
  d$u_tot <- unname(pega("Total", "2025")[as.character(d$id_municipio)])
  d$area_km2 <- AREA_MUN$area_km2[match(d$id_municipio, AREA_MUN$id_municipio)]
  d$pct <- 100 * d$j_tot / d$area_km2
  if (anyNA(d$j_tot) || anyNA(d$u_tot) || anyNA(d$pct)) stop("PRODES municipal incompleto")
  d
}

tabela_prodes_mun <- function(prefixo = "../municipios/") {
  d <- prodes_largo() |> arrange(desc(j_tot))
  na_txt <- tr('<span class="nao-se-aplica" title="Não se aplica: o município não integra a máscara deste bioma no PRODES">n.a.</span>',
               '<span class="nao-se-aplica" title="Not applicable: the municipality lies outside the PRODES mask for this biome">n.a.</span>')
  t <- tibble::tibble(
    Municipio = ifelse(d$sede_piloto, paste0(esc(d$municipio), tr('<span class="tag-sede" title="Município-sede de área-piloto">sede</span>', '<span class="tag-sede" title="Pilot-area host municipality">host</span>')), esc(d$municipio)),
    slug = d$slug, Bioma = nome_bioma(d$bioma),
    amz = d$j_amz, cer = d$j_cer, pan = d$j_pan, tot = d$j_tot, pct = d$pct, ult = d$u_tot)
  colnum <- function(nome, w = 82) colDef(name = nome, align = "right", html = TRUE, sortNALast = TRUE, minWidth = w,
                                          cell = function(v) if (is.na(v)) na_txt else num(v, 1))
  tagList(
    reactable(t, searchable = TRUE, compact = TRUE, striped = TRUE, defaultPageSize = 15, showPageSizeOptions = TRUE,
              pageSizeOptions = c(15, 50, 141), wrap = FALSE, class = "tabela-prodes",
              columns = list(
                slug = colDef(show = FALSE),
                Municipio = colDef(name = tr("Município", "Municipality"), html = TRUE, minWidth = 165, cell = function(v, i)
                  if (tem_perfil(t$slug[i])) sprintf('<a href="%s">%s</a>', url_mun(t$slug[i], prefixo), v) else v),
                Bioma = colDef(name = tr("Bioma", "Biome"), minWidth = 82),
                amz = colnum(nome_bioma("Amazônia")), cer = colnum("Cerrado"), pan = colnum("Pantanal"), tot = colnum("Total"),
                pct = colDef(name = tr("% território", "% of territory"), align = "right", minWidth = 86, cell = function(v) paste0(num(v, 2), "%")),
                ult = colnum("Total", 74)),
              columnGroups = list(colGroup(name = "2017–2025 (km²)", columns = c("amz", "cer", "pan", "tot", "pct")),
                                  colGroup(name = "2025 (km²)", columns = "ult"))),
    p(class = "nota-fonte", tr("Nota: a coluna Bioma indica o bioma dominante do município (IBGE, 1:250 mil, 2019), e as colunas Amazônia, Cerrado e Pantanal apresentam o incremento em cada máscara do PRODES. ",
                               "Note: the Biome column gives the municipality’s dominant biome (IBGE, 1:250,000, 2019); the Amazon, Cerrado and Pantanal columns show the increment in each PRODES mask. "),
      tr("n.a.: não se aplica (o município não integra a máscara daquele bioma). % território: razão entre o total de 2017–2025 e a área do município. ",
         "n.a.: not applicable (the municipality lies outside the mask for that biome). % of territory: ratio of the 2017–2025 total to the municipality’s area. "),
      tr("Dentro da máscara, o PRODES lista o município apenas nos anos em que mapeou incremento; o ano sem registro é contabilizado como 0 km² (nenhum incremento mapeado).",
         "Within a mask, PRODES lists a municipality only in years when it mapped an increment; a year with no record is counted as 0 km² (no increment mapped).")))
}

mapa_prodes_mun <- function(campo = c("km2", "pct"), altura = 440, prefixo = "../municipios/") {
  campo <- match.arg(campo)
  d <- prodes_largo()
  g <- left_join(GEO, d[, c("id_municipio", "j_amz", "j_cer", "j_pan", "j_tot", "u_tot", "pct")], by = "id_municipio")
  v <- if (campo == "km2") g$j_tot else g$pct
  br <- unique(quantile(v, probs = seq(0, 1, 0.2), na.rm = TRUE))
  pal <- colorBin("Reds", domain = v, bins = br, na.color = COR_ND)
  parte <- function(b, x) ifelse(is.na(x), "", sprintf("<br>%s: %s km²", b, num(x, 1)))
  rot <- sprintf(tr("<b>%s</b><br>2017–2025: %s km² (%s%% do território)%s%s%s<br>2025: %s km²<br><span style='color:#6b7280'>Bioma (IBGE): %s%s</span>",
                    "<b>%s</b><br>2017–2025: %s km² (%s%% of territory)%s%s%s<br>2025: %s km²<br><span style='color:#6b7280'>Biome (IBGE): %s%s</span>"),
                 esc(g$municipio), num(g$j_tot, 1), num(g$pct, 2),
                 parte(nome_bioma("Amazônia"), g$j_amz), parte("Cerrado", g$j_cer), parte("Pantanal", g$j_pan),
                 num(g$u_tot, 1), nome_bioma(g$bioma), ifelse(g$sede_piloto, tr(" · sede de área-piloto", " · pilot-area host municipality"), ""))
  m <- camadas_mun(mapa_vazio(altura), g, pal(v), rot, opac = 0.92)
  dd <- if (campo == "km2") 0 else 2
  bb <- st_bbox(g)
  m |>
    addLegend("bottomright", pal = pal, values = v, opacity = 0.9,
              title = if (campo == "km2") "km², 2017–2025" else tr("% do território, 2017–2025", "% of territory, 2017–2025"),
              labFormat = function(type, cuts, p) { n <- length(cuts); paste0(num(cuts[-n], dd), " – ", num(cuts[-1], dd)) }) |>
    addControl(nota_sedes_mapa(), position = "topright") |>
    fitBounds(bb[["xmin"]], bb[["ymin"]], bb[["xmax"]], bb[["ymax"]]) |>
    htmlwidgets::onRender(js_clique(prefixo))
}

# ---- SEEG (OE3) ------------------------------------------------------------------------
# Mudança de uso da terra antes de 1990: a célula traz o sinal ... (o SEEG não estima o setor); vira NA aqui
SEEG_SETOR <- ler(ds("seeg_mt_setor.csv"), colClasses = list(character = c("emissao_mtco2e", "sinal_emissao_mtco2e")))
SEEG_SETOR$emissao_mtco2e <- ifelse(SEEG_SETOR$sinal_emissao_mtco2e == "valor", suppressWarnings(as.numeric(SEEG_SETOR$emissao_mtco2e)), NA_real_)
COR_SETOR <- c("Mudança de Uso da Terra e Floresta" = "#b45309", "Agropecuária" = "#1F4D3A", "Energia" = "#2a78d6",
               "Resíduos" = "#6b7280", "Processos Industriais" = "#7c3aed")
NOME_SETOR <- c("Mudança de Uso da Terra e Floresta" = "Mudança de uso da terra e florestas", "Agropecuária" = "Agropecuária",
                "Energia" = "Energia", "Resíduos" = "Resíduos", "Processos Industriais" = "Processos industriais")
NOME_SETOR[] <- dic(NOME_SETOR)

grafico_seeg_setor <- function(desde = 1990) {
  s <- SEEG_SETOR[SEEG_SETOR$ano >= desde, ]
  ser <- lapply(names(COR_SETOR), function(k) { x <- s[s$setor == k, ]
    list(nome = NOME_SETOR[[k]], cor = COR_SETOR[[k]], larg = 2.3, dash = "", x = x$ano, y = x$emissao_mtco2e) })
  svg_linhas(ser, fmt = "dec1", titulo = tr("Emissões brutas de MT por setor, SEEG 13, MtCO2e (GWP-AR5)", "Gross emissions in MT by sector, SEEG 13, MtCO2e (GWP-AR5)"))
}

tabela_seeg_ano <- function(ano = 2024) {
  s <- SEEG_SETOR[SEEG_SETOR$ano == ano, ]
  stopifnot(!anyNA(s$emissao_mtco2e))
  s <- s[order(-s$emissao_mtco2e), ]
  total <- sum(s$emissao_mtco2e)
  linhas <- c(lapply(seq_len(nrow(s)), function(i) tags$tr(tags$td(NOME_SETOR[[s$setor[i]]]),
                                                         tags$td(style = "text-align:right", num(s$emissao_mtco2e[i], 1)),
                                                         tags$td(style = "text-align:right", paste0(num(100 * s$emissao_mtco2e[i] / total, 1), "%")))),
              list(tags$tr(style = "font-weight:700", tags$td(tr("Total (emissões brutas)", "Total (gross emissions)")), tags$td(style = "text-align:right", num(total, 1)),
                           tags$td(style = "text-align:right", tr("100,0%", "100.0%")))))
  rolagem(tags$table(class = "tabela-oe", style = "min-width:0; max-width:620px",
                     tags$thead(tags$tr(tags$th(tr("Setor", "Sector")), tags$th(style = "text-align:right", sprintf("MtCO2e, %d", ano)),
                                        tags$th(style = "text-align:right", tr("% do total", "% of total")))),
                     tags$tbody(linhas)))
}

# ---- Tipos do M1 (OE2) -----------------------------------------------------------------
tabela_tipos_m1 <- function() {
  P <- ler(ds("m1_tipos_perfis.csv")); P <- P[P$tipo %in% names(TIPOS), ]
  rolagem(tags$table(class = "tabela-oe", style = "min-width:0",
                     tags$thead(tags$tr(tags$th(tr("Tipo municipal do Manuscrito 1", "Manuscript 1 municipal type")), tags$th(style = "text-align:right", tr("Municípios", "Municipalities")))),
                     tags$tbody(lapply(seq_len(nrow(P)), function(i)
                       tags$tr(tags$td(style = "white-space:normal;font-weight:400", chip_tipo(P$tipo[i])),
                               tags$td(style = "text-align:right", P$n[i]))),
                       tags$tr(style = "font-weight:700", tags$td("Mato Grosso"), tags$td(style = "text-align:right", sum(P$n))))))
}

# ---- Áreas-piloto -----------------------------------------------------------------------
PIL_PAGINA <- c("vale-do-arinos" = "vale-do-arinos", "quata-nsa-aparecida" = "quata-nsa-aparecida", "lambari" = "lambari")
url_piloto <- function(slug, prefixo = "") paste0(prefixo, PIL_PAGINA[[slug]], ".html")

PIL_INFO <- list(
  "vale-do-arinos" = list(
    modalidade = tr("Projeto de assentamento (PA) do INCRA, código MT0641000, criado em 09/09/2003.",
                    "INCRA settlement project (PA), code MT0641000, created on 9 September 2003."),
    homonimos = tr(c("O PCA Arinos, também situado em Juara, constitui outro projeto e não corresponde à área-piloto Vale do Arinos."),
                   c("PCA Arinos, also in Juara, is a different project and not the Vale do Arinos pilot area.")),
    notas = tr(c("O bioma informado corresponde ao do município-sede; o bioma do próprio assentamento será conferido com base no perímetro validado."),
               c("The biome shown is that of the host municipality; the settlement’s own biome will be checked using the validated boundary."))),
  "quata-nsa-aparecida" = list(
    modalidade = tr("N. Sra. Aparecida: projeto do crédito fundiário (Programa Nacional de Crédito Fundiário, PNCF), modalidade em que a família paga pela terra. Quatá: modalidade a confirmar.",
                    "N. Sra. Aparecida: land credit project (National Land Credit Programme, PNCF), under which the family pays for the land. Quatá: project type to be confirmed."),
    homonimos = tr(c("Há projetos de assentamento denominados N. Sra. Aparecida em Diamantino, Várzea Grande e Alta Floresta, e nenhum deles corresponde à área-piloto Quatá e N. Sra. Aparecida.",
                     "O assentamento N. Sra. Aparecida do Movimento dos Trabalhadores Rurais Sem Terra (MST), em Campo Novo do Parecis, também constitui área distinta."),
                   c("There are settlement projects called N. Sra. Aparecida in Diamantino, Várzea Grande and Alta Floresta; none of them is the Quatá and N. Sra. Aparecida pilot area.",
                     "The N. Sra. Aparecida settlement of the Landless Rural Workers' Movement (MST), in Campo Novo do Parecis, is also a separate area.")),
    notas = tr(c("Por pertencer ao crédito fundiário, N. Sra. Aparecida não constitui projeto de assentamento do INCRA. Desse modo, nos cenários do OE4, a parcela paga pela terra integra o fluxo de caixa da família."),
               c("N. Sra. Aparecida is a land credit project, not an INCRA settlement project, so in the SO4 scenarios the instalment paid for the land is part of the family’s cash flow."))),
  "lambari" = list(
    modalidade = tr("Banco da Terra (crédito fundiário).", "Banco da Terra (land credit)."),
    homonimos = tr(c("A Fazenda Lambari, de Jaciara, constitui outra área e não corresponde à área-piloto Lambari.",
                     "O município de Lambari D'Oeste tampouco corresponde à área-piloto Lambari."),
                   c("Fazenda Lambari, in Jaciara, is a different area and not the Lambari pilot area.",
                     "The municipality of Lambari D'Oeste is not the Lambari pilot area either.")),
    notas = character(0))
)

cartoes_pilotos <- function(prefixo = "") {
  div(class = "cartoes", lapply(seq_len(nrow(PIL)), function(i) { P <- PIL[i, ]
    a(class = "cartao", href = url_piloto(P$slug, prefixo),
      div(class = "cartao-topo", chip_bioma(P$bioma), selo_conciliacao()),
      tags$h4(P$piloto),
      p(sprintf(tr("Município-sede: %s. %s", "Host municipality: %s. %s"), P$municipio_sede, PIL_INFO[[P$slug]]$modalidade)))
  }))
}

tabela_pilotos <- function(prefixo = "") {
  rolagem(tags$table(class = "tabela-oe",
    tags$thead(tags$tr(tags$th(tr("Área-piloto", "Pilot area")), tags$th(tr("Município-sede", "Host municipality")), tags$th(tr("Bioma", "Biome")), tags$th(tr("Modalidade", "Project type")),
                       tags$th(tr("Famílias e área", "Families and area")), tags$th(tr("Reconhecimento de campo", "Field reconnaissance")))),
    tags$tbody(lapply(seq_len(nrow(PIL)), function(i) { P <- PIL[i, ]
      tags$tr(tags$td(a(href = url_piloto(P$slug, prefixo), P$piloto)),
              tags$td(a(href = url_mun(MUN$slug[MUN$id_municipio == P$id_municipio]), P$municipio_sede)),
              tags$td(chip_bioma(P$bioma)), tags$td(PIL_INFO[[P$slug]]$modalidade),
              tags$td(selo_conciliacao()), tags$td(P$reconhecimento_campo))
    }))),
    p(class = "nota-fonte", tr("Nota: o bioma corresponde ao bioma dominante do município-sede (IBGE, Biomas 1:250 mil, 2019). Modalidade e código do projeto: registros do projeto e do INCRA. Os números de famílias e de área divergem entre as fontes e somente serão incluídos após a conciliação.",
                               "Note: the biome shown is the host municipality’s dominant biome (IBGE, Biomes 1:250,000, 2019). Project type and code: project and INCRA records. Figures for families and area differ between sources and will be included only after reconciliation.")))
}

ident_piloto <- function(slug) {
  P <- PIL[PIL$slug == slug, ]; M <- MUN[MUN$id_municipio == P$id_municipio, ]
  tags$dl(class = "ident",
    tags$dt(tr("Área-piloto", "Pilot area")), tags$dd(P$piloto),
    tags$dt(tr("Município-sede", "Host municipality")), tags$dd(a(href = url_mun(M$slug), M$municipio), span(class = "sub", sprintf(tr(" · código IBGE %d", " · IBGE code %d"), M$id_municipio))),
    tags$dt(tr("Bioma", "Biome")), tags$dd(chip_bioma(P$bioma), span(class = "sub", tr(" bioma dominante do município-sede (IBGE, Biomas 1:250 mil, 2019)", " dominant biome of the host municipality (IBGE, Biomes 1:250,000, 2019)"))),
    tags$dt(tr("Modalidade", "Project type")), tags$dd(PIL_INFO[[slug]]$modalidade),
    tags$dt(tr("Tipo do município no M1", "M1 municipal type")), tags$dd(chip_tipo(M$tipo_m1)),
    tags$dt(tr("Famílias e área", "Families and area")), tags$dd(selo_conciliacao(), span(class = "sub", tr(" as fontes divergem, e os números serão incluídos após a conciliação", " the sources differ, and the figures will be included once reconciled"))),
    tags$dt(tr("Reconhecimento de campo", "Field reconnaissance")), tags$dd(P$reconhecimento_campo),
    tags$dt(tr("Perímetro", "Boundary")), tags$dd(tr("Não publicado; o mapa apresenta apenas o município-sede.", "Not published; the map shows only the host municipality.")))
}

homonimos <- function(slug = NULL) {
  sl <- if (is.null(slug)) PIL$slug else slug
  itens <- unlist(lapply(sl, function(s) PIL_INFO[[s]]$homonimos))
  div(class = "aviso-homonimo", tags$b(tr("Atenção aos homônimos. ", "Beware of similar names. ")),
      if (is.null(slug)) tr("As áreas de nome semelhante listadas a seguir não correspondem às áreas-piloto do projeto:", "The areas listed below are not the project’s pilot areas:") else NULL,
      tags$ul(lapply(itens, tags$li)))
}

kpi_mun <- function(id, mun_id, prefixo = "../indicadores/") {
  r <- info_ind(id); s <- resumo_ind(id, mun_id); nome <- MUN$municipio[MUN$id_municipio == mun_id]
  comp <- comp_kpi(r, s)
  div(class = "kpi",
      div(class = "kpi-rotulo", span(class = "selo-mun", tr("município", "municipality")), sprintf("%s · ", nome), a(href = url_ind(id, prefixo), r$rotulo)),
      div(class = "kpi-valor", HTML(html_celula(s$valor, s$sinal, r$fmt))),
      div(class = "kpi-meta", sprintf("%s · %s", unid(r), s$ano), span(class = "fonte-kpi", r$fonte)),
      div(class = "kpi-comp", comp))
}

o_que_vem <- function() {
  itens <- list(
    c("previsto", tr("Quadro “fonte × número” com as famílias e a área de cada área-piloto, após a conciliação entre as fontes.",
                     "“Source × figure” table giving the number of families and the area for each pilot area, once the sources have been reconciled.")),
    c("previsto", tr("Perímetro de cada área, validado pela equipe de sistemas de informação geográfica (SIG) do projeto.",
                     "Boundary of each area, validated by the project’s geographic information systems (GIS) team.")),
    c("previsto", tr("Uso e cobertura da terra e métricas de paisagem nas áreas-piloto (OE1), etapa que depende do perímetro validado.",
                     "Land use, land cover and landscape metrics in the pilot areas (SO1). This stage depends on the validated boundary.")),
    c("previsto", tr("Diagnóstico socioeconômico e produtivo com dados de campo (OE2), etapa que depende da aprovação do questionário pelo Comitê de Ética em Pesquisa.",
                     "Socioeconomic and production assessment using field data (SO2). This stage depends on the Research Ethics Committee approving the questionnaire.")),
    c("previsto", tr("Balanço de carbono (OE3) e cenários de viabilidade (OE4) por área-piloto.",
                     "Carbon balance (SO3) and viability scenarios (SO4) by pilot area.")))
  tagList(tags$ul(class = "lista-lacunas", lapply(itens, function(x) tags$li(selo_situacao(x[[1]]), " ", x[[2]]))),
          p(class = "nota-fonte", tr("Nenhuma dessas etapas dispõe de data confirmada, e o reconhecimento de campo nas áreas-piloto encontra-se a confirmar.",
                                     "None of these stages has a confirmed date, and the field reconnaissance in the pilot areas has yet to be confirmed.")))
}
