# =============================================================================
# R/pag_inicio.R - elementos da página inicial (index.qmd) e de páginas avulsas
# =============================================================================
# Usar depois de R/funcoes.R:
#   source(file.path(Sys.getenv("QUARTO_PROJECT_DIR", "."), "R", "funcoes.R"))
#   source(file.path(Sys.getenv("QUARTO_PROJECT_DIR", "."), "R", "pag_inicio.R"))
#
# Lê só dados_site/ (TOT, MUN, PIL, IND de funcoes.R e dados_site/prodes_mt_taxa.csv).
# Os links só apontam para páginas que existem; senão, para o índice da seção.
#
#   existe_qmd(rel)                  -> TRUE se <raiz>/<rel>.qmd existe (rel sem extensão)
#   data_br(x)                       -> "2026-10-19" vira "19/10/2026"
#   prodes_resumo()                  -> list(ult, ant, pico, queda_pct, estimada, fonte, acesso, atualizacao)
#                                       ult/ant/pico = list(ano, taxa, inicio, fim); estimada = linha ou NULL
#   atalhos_inicio()                 -> três listas: município, indicador, área-piloto
#   kpis_inicio()                    -> os 8 cartões de Mato Grosso, cada um com fonte, unidade e ano
#   mapas_inicio(altura = 380)       -> dois mapas lado a lado (tipo do M1 e bioma)
#   cartoes_pilotos(prefixo = "")    -> três cartões das áreas-piloto, com o selo de conciliação
#   cartoes_secoes()                 -> cartões das seções do site
# =============================================================================

existe_qmd <- function(rel) file.exists(file.path(RAIZ, paste0(rel, ".qmd")))
data_br <- function(x) { x <- as.character(x); ifelse(grepl("^\\d{4}-\\d{2}-\\d{2}$", x),
  paste(substr(x, 9, 10), substr(x, 6, 7), substr(x, 1, 4), sep = "/"), x) }
MESES <- c("jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez")
mes_ano <- function(x) { d <- as.Date(x); paste0(MESES[as.integer(format(d, "%m"))], "/", format(d, "%Y")) }

# ---- PRODES: taxa oficial de MT (Amazônia Legal, formações florestais) --------
prodes_resumo <- function() {
  p <- ler(ds("prodes_mt_taxa.csv"))
  cons <- p[p$status == "consolidada", ]
  cons <- cons[order(cons$ano), ]
  lin <- function(r) list(ano = r$ano, taxa = r$taxa_km2, inicio = r$periodo_inicio, fim = r$periodo_fim)
  ult <- cons[nrow(cons), ]; ant <- cons[nrow(cons) - 1, ]; pico <- cons[which.max(cons$taxa_km2), ]
  est <- p[p$status != "consolidada" & p$ano > ult$ano, ]
  list(ult = lin(ult), ant = lin(ant), pico = lin(pico),
       queda_pct = 100 * (1 - ult$taxa_km2 / pico$taxa_km2),
       estimada = if (nrow(est)) lin(est[1, ]) else NULL,
       fonte = "INPE/PRODES Amazônia Legal, TerraBrasilis", acesso = data_br(ult$data_acesso),
       atualizacao = data_br(ult$atualizacao_inpe), versao = ult$versao_painel)
}

# ---- Atalhos ---------------------------------------------------------------------
lista_ir <- function(id, rotulo, inicial, opcoes) {
  div(tags$label(`for` = id, rotulo),
      tags$select(id = id, class = "form-select", onchange = "if (this.value) window.location = this.value",
                  tags$option(value = "", inicial), opcoes))
}

atalhos_inicio <- function() {
  # municípios: os 141 perfis, em ordem alfabética do português
  P <- if (nrow(PERFIS)) PERFIS else SEDES
  mun <- lapply(seq_len(nrow(P)), function(j) tags$option(
    value = if (tem_perfil(P$slug[j])) paste0("municipios/", P$slug[j], ".html") else "municipios/index.html",
    if (isTRUE(P$sede_piloto[j])) paste0(P$municipio[j], " (sede de área-piloto)") else P$municipio[j]))
  # indicadores, agrupados por tema
  O <- IND[order(IND$ordem), ]
  ind <- lapply(names(TEMAS), function(t) { g <- O[O$dim == t, ]
    tags$optgroup(label = TEMAS[[t]], lapply(seq_len(nrow(g)), function(j) tags$option(
      value = if (existe_qmd(file.path("indicadores", g$id[j]))) paste0("indicadores/", g$id[j], ".html") else "indicadores/index.html",
      g$rotulo[j]))) })
  # áreas-piloto
  pil <- lapply(seq_len(nrow(PIL)), function(j) tags$option(
    value = if (existe_qmd(file.path("pilotos", PIL$slug[j]))) paste0("pilotos/", PIL$slug[j], ".html") else "pilotos/index.html",
    sprintf("%s (%s, %s)", PIL$piloto[j], PIL$municipio_sede[j], PIL$bioma[j])))
  div(class = "atalhos", style = "grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));",
      lista_ir("ir-mun", "Ir para um município",
               "Escolha um município…", mun),
      lista_ir("ir-ind", "Ir para um indicador", sprintf("Escolha um dos %d indicadores…", nrow(IND)), ind),
      lista_ir("ir-pil", "Ir para uma área-piloto", "Escolha uma das 3 áreas-piloto…", pil))
}

# ---- Os 8 números de Mato Grosso ---------------------------------------------------
tt <- function(id) { v <- TOT$valor[TOT$id == id]; if (length(v) != 1) stop("total estadual ausente: ", id); v }

kpis_inicio <- function() {
  nb <- table(factor(MUN$bioma, BIOMAS))
  pr <- prodes_resumo()
  f_censo <- "Fonte: IBGE, Censo Agropecuário 2017 (resultados definitivos); agricultura familiar pela Lei 11.326/2006."
  div(class = "kpi-grade",
    cartao_kpi("Municípios de Mato Grosso", fmt_valor(nrow(MUN), "int"),
               sprintf("%d Amazônia · %d Cerrado · %d Pantanal, pelo bioma dominante (2019)",
                       nb[["Amazônia"]], nb[["Cerrado"]], nb[["Pantanal"]]),
               "Fonte: IBGE, Biomas do Brasil 1:250 mil (2019), sobre os 141 municípios do Censo Agropecuário 2017."),
    cartao_kpi("Estabelecimentos da agricultura familiar (AF)", fmt_valor(tt("tot_af_estab"), "int"),
               sprintf("%s dos %s estabelecimentos de MT (Brasil: %s) · 2017", fmt_valor(tt("pct_af_estab_mt"), "pct1"),
                       fmt_valor(tt("tot_todos_estab"), "int"), fmt_valor(tt("pct_af_estab_br"), "pct1")), f_censo),
    cartao_kpi("Área dos estabelecimentos da AF", fmt_valor(tt("pct_af_area_mt"), "pct1"),
               sprintf("%s de %s hectares de MT · 2017", fmt_valor(tt("tot_af_area"), "int"), fmt_valor(tt("tot_todos_area"), "int")),
               f_censo),
    cartao_kpi("Pessoal ocupado na AF", fmt_valor(100 * tt("tot_af_pessoal") / tt("pessoal_total_mt"), "pct1"),
               sprintf("%s de %s pessoas ocupadas nos estabelecimentos de MT · 2017", fmt_valor(tt("tot_af_pessoal"), "int"),
                       fmt_valor(tt("pessoal_total_mt"), "int")), f_censo),
    cartao_kpi("Valor da produção da AF", fmt_valor(100 * tt("vbp_af_mt") / tt("vbp_total_mt"), "pct1"),
               sprintf("%s de %s (reais de 2017) · %s do valor da lavoura permanente e %s da horticultura de MT · 2017",
                       fmt_valor(tt("vbp_af_mt"), "brl_mil"), fmt_valor(tt("vbp_total_mt"), "brl_mil"),
                       fmt_valor(tt("pct_af_vbp_lavperm_mt"), "pct1"), fmt_valor(tt("pct_af_vbp_hort_mt"), "pct1")), f_censo),
    cartao_kpi("Projetos de assentamento do INCRA em MT", fmt_valor(tt("n_pa_mt"), "int"),
               sprintf("%s famílias assentadas · posição de 03/06/2025", fmt_valor(tt("fam_pa_mt"), "int")),
               "Fonte: INCRA/SIPRA, Relatório 0227 (total estadual)."),
    cartao_kpi("Emissões brutas de gases de efeito estufa", paste(fmt_valor(tt("seeg_bruta_mt_2024"), "dec1"), "MtCO₂e"),
               sprintf("2024 · %s de mudança de uso da terra e floresta e %s da agropecuária",
                       fmt_valor(100 * tt("seeg_mut_mt_2024") / tt("seeg_bruta_mt_2024"), "pct1"),
                       fmt_valor(100 * tt("seeg_agro_mt_2024") / tt("seeg_bruta_mt_2024"), "pct1")),
               "Fonte: SEEG 13, Observatório do Clima (GWP-AR5), emissões do estado."),
    cartao_kpi("Desmatamento na Amazônia Legal em MT", paste(fmt_valor(pr$ult$taxa, "int"), "km²"),
               sprintf("taxa consolidada de %d (ago/%d–jul/%d) · %s km² em %d · pico de %s km² em %d; queda de %s desde então",
                       pr$ult$ano, pr$ult$ano - 1L, pr$ult$ano, fmt_valor(pr$ant$taxa, "int"), pr$ant$ano,
                       fmt_valor(pr$pico$taxa, "int"), pr$pico$ano, fmt_valor(pr$queda_pct, "pct1")),
               sprintf("Fonte: %s, formações florestais (acesso em %s; atualização do INPE em %s).%s", pr$fonte, pr$acesso,
                       pr$atualizacao, if (!is.null(pr$estimada)) sprintf(" A taxa de %d é estimada e fica fora.", pr$estimada$ano) else "")))
}

# ---- Mapas: tipo do M1 e bioma, lado a lado -----------------------------------------
# A legenda vai abaixo do mapa (em chips), para não cobrir o estado em telas estreitas.
sem_legenda <- function(m) { m$x$calls <- Filter(function(cl) !identical(cl$method, "addLegend"), m$x$calls); m }

legenda_mapa <- function(cor_por = c("tipo", "bioma")) {
  cor_por <- match.arg(cor_por)
  if (cor_por == "tipo") {
    n <- table(factor(MUN$tipo_m1, names(TIPOS)))
    div(class = "nota-fonte", style = "display: flex; flex-wrap: wrap; gap: .35rem .6rem; margin: .4rem .2rem 0;",
        lapply(names(TIPOS), function(t) span(chip_tipo(t, rotulo = TRUE, provisorio = FALSE), sprintf("%d", n[[t]]))),
        span("Rótulos provisórios, pendentes dos autores."))
  } else {
    n <- table(factor(MUN$bioma, BIOMAS))
    div(class = "nota-fonte", style = "display: flex; flex-wrap: wrap; gap: .35rem .6rem; margin: .4rem .2rem 0;",
        lapply(BIOMAS, function(b) span(chip_bioma(b), sprintf("%d municípios", n[[b]]))))
  }
}

mapas_inicio <- function(altura = 380) {
  bloco <- function(titulo, mapa, leg) div(style = "border: 1px solid #eef0f4; border-radius: 6px; padding: .4rem; min-width: 0;",
                                           tags$h4(style = "font-size: 1rem; margin: .2rem .3rem .4rem;", titulo), mapa, leg)
  div(style = "display: grid; grid-template-columns: repeat(auto-fit, minmax(290px, 1fr)); gap: 1rem; margin: .5rem 0 1rem;",
      bloco(tagList("Tipo municipal da AF (Manuscrito 1, k = 5)", selo_provisorio()),
            sem_legenda(mapa_municipio(NULL, altura = altura, prefixo = "municipios/", cor_por = "tipo")), legenda_mapa("tipo")),
      bloco("Bioma dominante (IBGE 1:250 mil, 2019)",
            sem_legenda(mapa_municipio(NULL, altura = altura, prefixo = "municipios/", cor_por = "bioma")), legenda_mapa("bioma")))
}

# ---- Cartões das áreas-piloto ----------------------------------------------------------
cartoes_pilotos <- function(prefixo = "") {
  div(class = "cartoes", lapply(seq_len(nrow(PIL)), function(j) {
    r <- PIL[j, ]
    href <- if (existe_qmd(file.path("pilotos", r$slug))) paste0(prefixo, "pilotos/", r$slug, ".html") else paste0(prefixo, "pilotos/index.html")
    a(class = "cartao", href = href,
      div(class = "cartao-topo", tags$h4(style = "margin: 0;", r$piloto), chip_bioma(r$bioma)),
      p(tags$b("Município-sede: "), r$municipio_sede),
      p(paste0(sub("\\.$", "", r$modalidade), ".")),
      p(style = "margin-top: .4rem;", selo_conciliacao(),
        span(class = "nota-fonte", style = "margin-left: .4rem;", paste("Reconhecimento de campo:", r$reconhecimento_campo))))
  }))
}

# ---- Cartões das seções -------------------------------------------------------------------
cartoes_secoes <- function() {
  c1 <- function(href, titulo, texto) a(class = "cartao", href = href, tags$h4(titulo), p(texto))
  div(class = "cartoes",
    c1("municipios/index.html", "Municípios", "Os 141 municípios de MT em tabela e mapa, com o perfil de cada um."),
    c1("indicadores/index.html", "Indicadores", sprintf("Os %d indicadores, com mapa dos 141 municípios, ranking e comparação por bioma e por tipo.", nrow(IND))),
    c1("resultados/tipologia.html", "Resultados", "Tipologia municipal da AF, posse no Censo e reforma agrária, emissões e desmatamento, dinâmica 2006–2017."),
    c1("pilotos/index.html", "Áreas-piloto", "As três áreas do estudo de campo, uma por bioma, só com identificação."),
    c1("objetivos/index.html", "Objetivos", "Os seis objetivos específicos (OE1 a OE6) e a situação de cada um."),
    c1("literatura/index.html", "Literatura", "As buscas de literatura em números e as listas de referências, só com metadados."),
    c1("dados/index.html", "Dados", "Explorador dos indicadores e downloads com dicionário, fontes e licenças."),
    c1("biblioteca/index.html", "Biblioteca", "Leituras de base com link para o DOI ou a página oficial."),
    c1("sobre.html", "Sobre", "O projeto, o recorte, as regras de conteúdo e como citar."))
}

# =============================================================================
# Literatura (literatura/*.qmd) e Biblioteca: dados de dados_site/literatura/
# (gravados por scripts/05_preparar_literatura.py)
#
#   ler_lit(f)                      -> tibble de dados_site/literatura/<f>, texto vazio em vez de NA
#   PAN                             -> panorama.csv (contagens das bases)
#   pan(id)                         -> valor do panorama (stop se faltar)
#   pan_txt(id)                     -> valor formatado em pt-BR
#   fluxo_caixas(passos)            -> caixas em sequência; passos = list(c(valor, rotulo), ...)
#   link_doi(doi)                   -> link(s) https://doi.org/<doi>; vários separados por ";"
#   filtro_lista_lit(id_tab, ordem) -> filtro de seleção (valor exato) para colunas do reactable
#   filtro_igual_lit                -> método de filtro por igualdade
# =============================================================================
ler_lit <- function(f) {
  x <- ler(ds("literatura", f), colClasses = "character", na.strings = NULL)
  x <- mutate(x, across(everything(), ~ ifelse(is.na(.x), "", .x)))
  for (k in intersect(c("ano", "n_refs", "valor"), names(x))) x[[k]] <- suppressWarnings(as.integer(x[[k]]))
  x
}
PAN <- if (file.exists(ds("literatura", "panorama.csv"))) ler(ds("literatura", "panorama.csv")) else NULL
pan <- function(id) { v <- PAN$valor[PAN$id == id]; if (length(v) != 1) stop("contagem ausente: ", id); v }
pan_txt <- function(id) fmt_valor(pan(id), "int")

fluxo_caixas <- function(passos) {
  cx <- function(v, r) div(style = "border: 1px solid #dde1ea; border-radius: 8px; padding: .5rem .8rem; background: #fff; min-width: 120px; flex: 1 1 120px;",
                           div(style = "font-size: 1.35rem; font-weight: 700; color: #1F4D3A;", v),
                           div(style = "font-size: .8rem; color: #4b5563;", r))
  seta <- span(style = "align-self: center; color: #9ca3af; font-size: 1.2rem;", `aria-hidden` = "true", "→")
  itens <- list()
  for (i in seq_along(passos)) {
    if (i > 1) itens[[length(itens) + 1]] <- seta
    itens[[length(itens) + 1]] <- cx(passos[[i]][1], passos[[i]][2])
  }
  div(style = "display: flex; flex-wrap: wrap; gap: .5rem; align-items: stretch; margin: .6rem 0 1rem;", itens)
}

link_doi <- function(doi) {
  if (is.na(doi) || !nzchar(doi)) return("—")
  d <- trimws(strsplit(doi, ";", fixed = TRUE)[[1]])
  tagList(lapply(seq_along(d), function(i) tagList(if (i > 1) "; ",
    a(href = paste0("https://doi.org/", d[i]), target = "_blank", rel = "noopener", d[i]))))
}

filtro_lista_lit <- function(id_tab, ordem = NULL) function(values, name) {
  v <- unique(as.character(values)); v <- v[!is.na(v) & v != ""]
  v <- if (is.null(ordem)) sort_pt(v) else c(intersect(ordem, v), sort_pt(setdiff(v, ordem)))
  tags$select(class = "form-select form-select-sm", `aria-label` = paste("Filtrar", name),
              onchange = sprintf("Reactable.setFilter('%s', '%s', event.target.value || undefined)", id_tab, name),
              tags$option(value = "", "Todos"), lapply(v, function(x) tags$option(value = x, x)))
}
filtro_igual_lit <- JS("function(rows, columnId, filterValue) { return rows.filter(function(row) { return String(row.values[columnId]) === filterValue }) }")

# Rótulo curto dos grupos da tabela comparativa do OE4 (só na exibição; os CSV trazem o nome completo)
grupo_curto <- function(g) {
  m <- c("Assentamentos e agricultura familiar no Brasil" = "Assentamentos e AF no Brasil",
         "Pagamento por serviço ambiental e carbono (componentes de método)" = "PSA e carbono (método)",
         "Mato Grosso e entorno" = "Mato Grosso e entorno")
  ifelse(g %in% names(m), unname(m[g]), g)
}
