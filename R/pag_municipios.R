# =============================================================================
# R/pag_municipios.R - funções das páginas de municípios e de indicadores
# =============================================================================
# Complementa R/funcoes.R (que precisa estar carregado antes). Uso:
#
#   ```{r}
#   #| include: false
#   source(file.path(Sys.getenv("QUARTO_PROJECT_DIR", "."), "R", "funcoes.R"))
#   source(file.path(RAIZ, "R", "pag_municipios.R"))
#   ```
#
# Lê só objetos já carregados por R/funcoes.R (MUN, IND, SER, ULT, GEO, AGR, TOT)
# e dados_site/. Valores com X, – ou ... sempre saem por fmt_celula/html_celula
# ou pelo texto de SINAL_TXT; nunca como 0 ou como célula vazia.
#
# MAPA SVG LEVE (sem leaflet; 38 a 54 KB por mapa, conforme a tolerância)
#   svg_mapa_mt(destaque = NULL, modo = "bioma", alternar = FALSE, prefixo = "",
#               id = "mapa-mt", links = TRUE, largura_max = NULL, tol = 1500)
#       141 municípios coloridos por bioma ou por tipo do M1; sedes das áreas-
#       piloto contornadas; destaque = id_municipio contornado em laranja;
#       alternar = TRUE põe os botões Bioma | Tipo do M1; clique abre o perfil
#       (só onde municipios/<slug>.qmd existe). Dica pelo atributo data-tip.
#   barra_biomas(mun_id)        -> barra empilhada com o % de cada bioma
#
# PERFIL DO MUNICÍPIO
#   tv(id, mun_id, unidade = FALSE)  -> texto do valor ou do sinal ("X (sigilo IBGE)")
#   unid(r)                          -> unidade como aparece na tela (R$ mil -> R$ quando fmt = brl_mil)
#   grade_kpis_mun(mun_id, ids)      -> cartões dos indicadores-chave do município (kpi_mun)
#   cabecalho_municipio(mun_id)      -> chips de bioma e tipo, % dos biomas, código IBGE
#   aviso_sede(mun_id)               -> aviso da área-piloto (NULL se não é sede)
#   texto_perfil(mun_id)             -> parágrafos com números inline (fonte, unidade e ano)
#   tabela_posicao(mun_id, ids)      -> posição no bioma, no tipo e em MT
#   tabela_tema_mun(dim, mun_id, nome, prefixo) -> indicadores do tema no perfil (versão leve de tabela_dim)
#   svg_linhas_leve(series, fmt, titulo, w, h)  -> linhas sem um ponto por ano; dica por ano com todos os valores
#   svg_seeg_mun(mun_id, nome)       -> minissérie SEEG do município (1970–2024; MUT e remoções desde 1990)
#   link_piloto(slug, prefixo)       -> página da área-piloto, se existir
#
# PÁGINAS DE MUNICÍPIOS E DE INDICADORES
#   tabela_municipios(prefixo = "", id_tab = "tab-municipios") -> 141 municípios, busca e filtros
#   links_sidra(fonte)               -> fonte com links para as tabelas do SIDRA
#   meta_indicador(id)               -> tema, unidade, ano, fonte, cálculo
#   notas_indicador(id)              -> chr (markdown) com as notas obrigatórias do indicador
#   cartoes_indicador(id)            -> MT (agregado, mediana, total oficial) e contagem de sinais
#   cartoes_sedes(id, prefixo)       -> valor nas 3 sedes, com posição no bioma e em MT
#   series_sedes(id)                 -> série das 3 sedes (indicadores com série)
#   series_grupos(id, recorte, incluir_mt) -> série do agregado por bioma ou tipo (SEEG em MtCO2e)
#   ano_ini(id), periodo_serie(id), NOTA_1990 -> início real das séries do SEEG (MUT e remoções: 1990)
#   tabela_ind_recorte(id, prefixo)  -> 141 municípios com coluna de sinal, filtros e download
#   cartoes_tema(dim, prefixo = "")  -> cartões dos indicadores de um tema (página índice)
# =============================================================================

.cache_pm <- new.env(parent = emptyenv())
# O SEEG só estima mudança de uso da terra e remoções a partir de 1990. Em dados_site, 1970–1989
# levam o sinal ... (não disponível) nesses dois indicadores; os gráficos começam em 1990 para eles.
ANO_INI_SERIE <- c(seeg_mut = 1990L, seeg_remocoes = 1990L)
ano_ini <- function(id) if (id %in% names(ANO_INI_SERIE)) ANO_INI_SERIE[[id]] else 1970L
periodo_serie <- function(id) sprintf("%d–%d", ano_ini(id), max(SER$ano[SER$indicador == id]))
NOTA_1990 <- tr(paste("Ressalta-se que o SEEG estima as emissões de mudança de uso da terra e florestas e as remoções apenas a partir de 1990.",
                      "Por essa razão, as emissões brutas apresentam um salto em 1990, uma vez que, antes desse ano, a série não inclui esse setor."),
                "SEEG estimates land-use change and forestry emissions and removals only from 1990 onwards. Gross emissions therefore jump in 1990, because the series does not include this sector before that year.")
SLUG_BIOMA <- c("Amazônia" = "amazonia", "Cerrado" = "cerrado", "Pantanal" = "pantanal")
DEC_CSV <- c(int = 0, dec1 = 3, dec2 = 4, dec3 = 5, pct1 = 4, pct2 = 5, brl = 2, brl_mil = 3, usd = 2)

# ---- Mapa SVG ------------------------------------------------------------------
# Projeção policônica do Brasil (SIRGAS 2000, EPSG:5880), simplificação de
# Douglas-Peucker por polígono e coordenadas inteiras relativas (path "l").
caminhos_svg <- function(tol = 1500, largura = 1000) {
  ch <- paste0("p", tol, "_", largura)
  if (!is.null(.cache_pm[[ch]])) return(.cache_pm[[ch]])
  g <- st_transform(GEO, 5880)
  s <- st_simplify(st_geometry(g), dTolerance = tol, preserveTopology = TRUE)
  bb <- st_bbox(g); k <- largura / (bb[["xmax"]] - bb[["xmin"]])
  alt <- ceiling((bb[["ymax"]] - bb[["ymin"]]) * k)
  d <- vapply(seq_along(s), function(i) {
    cc <- st_coordinates(s[[i]])
    lc <- grep("^L", colnames(cc))
    anel <- do.call(paste, c(as.data.frame(cc[, lc, drop = FALSE]), sep = "_"))
    partes <- lapply(split(seq_len(nrow(cc)), factor(anel, levels = unique(anel))), function(ix) {
      x <- round((cc[ix, "X"] - bb[["xmin"]]) * k); y <- round((bb[["ymax"]] - cc[ix, "Y"]) * k)
      fica <- c(TRUE, diff(x) != 0 | diff(y) != 0); x <- x[fica]; y <- y[fica]
      n <- length(x)
      if (n > 1 && x[n] == x[1] && y[n] == y[1]) { x <- x[-n]; y <- y[-n] }
      if (length(x) < 3) return("")
      nums <- as.vector(rbind(diff(x), diff(y)))
      paste0("M", x[1], " ", y[1], "l", sub("^ ", "", paste0(ifelse(nums < 0, "", " "), nums, collapse = "")), "z")
    })
    paste(unlist(partes), collapse = "")
  }, character(1))
  out <- list(d = d, w = largura, h = alt, id = g$id_municipio)
  .cache_pm[[ch]] <- out
  out
}

css_mapa <- function(id) {
  b <- paste(sprintf("#%s[data-modo=bioma] .b-%s{fill:%s}", id, SLUG_BIOMA, COR_BIOMA[names(SLUG_BIOMA)]), collapse = "")
  t <- paste(sprintf("#%s[data-modo=tipo] .t-%s{fill:%s}", id, tolower(names(COR_TIPO)), COR_TIPO), collapse = "")
  paste0("<style>", b, t,
         sprintf("#%s svg{display:block;width:100%%;height:auto}", id),
         sprintf("#%s .mun path{stroke:#fff;stroke-width:.7px;vector-effect:non-scaling-stroke;fill-opacity:.88}", id),
         sprintf("#%s .mun a:hover path,#%s .mun a:focus path{fill-opacity:1;stroke:#111827;stroke-width:1.6px}", id, id),
         sprintf("#%s.com-destaque .mun path{fill-opacity:.5}#%s.com-destaque .mun path.dest{fill-opacity:1}", id, id),
         sprintf("#%s .contorno path{fill:none;vector-effect:non-scaling-stroke;pointer-events:none}", id),
         sprintf("#%s[data-modo=bioma] .leg-tipo,#%s[data-modo=tipo] .leg-bioma{display:none}", id, id),
         sprintf("#%s .leg-mapa{display:flex;flex-wrap:wrap;gap:.35rem .5rem;margin-top:.4rem;font-size:.78rem;align-items:center}", id),
         sprintf("#%s .leg-sede{display:flex;flex-wrap:wrap;gap:.2rem .9rem;font-size:.76rem;color:#374151;margin-top:.3rem}#%s .leg-sede>span{white-space:nowrap;display:inline-flex;align-items:center;gap:.3rem}", id, id),
         "</style>")
}

svg_mapa_mt <- function(destaque = NULL, modo = c("bioma", "tipo"), alternar = FALSE, prefixo = "",
                        id = "mapa-mt", links = TRUE, largura_max = NULL, tol = 1500) {
  modo <- match.arg(modo)
  P <- caminhos_svg(tol = tol)
  g <- sf::st_drop_geometry(GEO)
  perfil <- vapply(g$slug, tem_perfil, logical(1))
  piloto <- MUN$piloto[match(g$id_municipio, MUN$id_municipio)]
  dica <- sprintf("%s · %s · %s%s", g$municipio, nome_bioma(g$bioma), g$tipo_m1,
                  ifelse(g$sede_piloto, tr(paste0(" · sede da área-piloto ", piloto), paste0(" · host municipality of the ", piloto, " pilot area")), ""))
  caminho <- sprintf('<path class="b-%s t-%s%s" d="%s" data-tip="%s"/>', SLUG_BIOMA[g$bioma], tolower(g$tipo_m1),
                     ifelse(g$id_municipio %in% destaque, " dest", ""), P$d, esc(dica))
  caminho <- ifelse(links & perfil, sprintf('<a href="%s%s.html" aria-label="%s">%s</a>', prefixo, g$slug,
                                            esc(paste(tr("Perfil de", "Profile of"), g$municipio)), caminho), caminho)
  sedes <- paste(sprintf('<path d="%s"/>', P$d[g$sede_piloto]), collapse = "")
  dest <- if (!is.null(destaque)) paste(sprintf('<path d="%s"/>', P$d[g$id_municipio %in% destaque]), collapse = "") else ""
  nome_dest <- if (!is.null(destaque)) paste(g$municipio[g$id_municipio %in% destaque], collapse = ", ") else ""
  rotulo <- if (is.null(destaque)) sprintf(tr("Mapa dos 141 municípios de Mato Grosso por %s", "Map of the 141 municipalities of Mato Grosso by %s"), if (modo == "bioma") tr("bioma", "biome") else tr("tipo do M1", "M1 type"))
            else sprintf(tr("Localização de %s em Mato Grosso", "Location of %s in Mato Grosso"), nome_dest)
  svg <- sprintf(paste0('<svg viewBox="0 0 %d %d" role="group" aria-label="%s">',
                        '<g class="mun" fill-rule="evenodd">%s</g>',
                        '<g class="contorno" stroke="#111827" stroke-width="2.2px">%s</g>',
                        '<g class="contorno" stroke="%s" stroke-width="3.6px">%s</g></svg>'),
                 P$w, P$h, esc(rotulo), paste(caminho, collapse = ""), sedes, COR[["sede"]], dest)
  nb <- table(factor(MUN$bioma, BIOMAS)); nt <- table(factor(MUN$tipo_m1, names(TIPOS)))
  leg_b <- div(class = "leg-mapa leg-bioma", lapply(BIOMAS, function(b) span(class = paste0("chip chip-", SLUG_BIOMA[[b]]), sprintf("%s (%d)", nome_bioma(b), nb[[b]]))),
               span(class = "sub", tr("IBGE, Biomas 1:250 mil (2019), bioma dominante", "Dominant biome: IBGE, Biomes 1:250,000 (2019)")))
  leg_t <- div(class = "leg-mapa leg-tipo", lapply(names(TIPOS), function(t) span(class = paste0("chip chip-", tolower(t)), title = TIPOS[[t]],
                                                                                   sprintf("%s · %s (%d)", t, TIPOS[[t]], nt[[t]]))),
               selo_provisorio(), span(class = "sub", tr("Manuscrito 1 do Projeto RESA, k = 5", "RESA Project Manuscript 1, k = 5")))
  sede <- div(class = "leg-sede",
              span(HTML('<svg width="14" height="11" aria-hidden="true"><rect x="1" y="1" width="12" height="9" fill="none" stroke="#111827" stroke-width="2"/></svg>'),
                   tr("sede de área-piloto", "pilot-area host municipality")),
              if (!is.null(destaque)) span(HTML(sprintf('<svg width="14" height="11" aria-hidden="true"><rect x="1" y="1" width="12" height="9" fill="none" stroke="%s" stroke-width="2.5"/></svg>', COR[["sede"]])),
                                           nome_dest))
  botoes <- if (alternar) div(class = "btn-group btn-group-sm mb-2", role = "group", `aria-label` = tr("Colorir o mapa por", "Colour the map by"),
    tags$button(type = "button", class = paste("btn btn-outline-primary", if (modo == "bioma") "active"), `aria-pressed` = tolower(modo == "bioma"),
                onclick = "var w=this.closest('.mapa-svg');w.dataset.modo='bioma';w.querySelectorAll('.btn-group .btn').forEach(function(b){b.classList.remove('active');b.setAttribute('aria-pressed','false')});this.classList.add('active');this.setAttribute('aria-pressed','true')",
                tr("Bioma", "Biome")),
    tags$button(type = "button", class = paste("btn btn-outline-primary", if (modo == "tipo") "active"), `aria-pressed` = tolower(modo == "tipo"),
                onclick = "var w=this.closest('.mapa-svg');w.dataset.modo='tipo';w.querySelectorAll('.btn-group .btn').forEach(function(b){b.classList.remove('active');b.setAttribute('aria-pressed','false')});this.classList.add('active');this.setAttribute('aria-pressed','true')",
                tr("Tipo do M1", "M1 type")))
  div(class = paste("mapa-svg", if (!is.null(destaque)) "com-destaque"), id = id, `data-modo` = modo,
      style = if (!is.null(largura_max)) sprintf("max-width:%dpx", largura_max),
      HTML(css_mapa(id)), botoes, HTML(svg), leg_b, leg_t, sede)
}

barra_biomas <- function(mun_id) {
  m <- MUN[MUN$id_municipio == mun_id, ]
  p <- c("Amazônia" = m$pct_amazonia, "Cerrado" = m$pct_cerrado, "Pantanal" = m$pct_pantanal)
  p[is.na(p)] <- 0
  x0 <- c(0, cumsum(p)[-3])
  seg <- paste(sprintf(tr('<rect x="%.2f" y="0" width="%.2f" height="10" fill="%s" data-tip="%s: %s do território"/>',
                          '<rect x="%.2f" y="0" width="%.2f" height="10" fill="%s" data-tip="%s: %s of the territory"/>'),
                       x0, p, COR_BIOMA[names(p)], nome_bioma(names(p)), fmt_valor(p, "pct1"))[p > 0], collapse = "")
  o <- order(-p); o <- o[p[o] > 0]
  txt <- paste(sprintf("%s %s", nome_bioma(names(p)[o]), fmt_valor(p[o], "pct1")), collapse = " · ")
  tagList(HTML(sprintf('<svg viewBox="0 0 100 10" preserveAspectRatio="none" width="100%%" height="10" style="max-width:320px;display:block;border-radius:3px;margin:.2rem 0" role="img" aria-label="%s">%s</svg>', esc(txt), seg)),
          span(class = "sub", txt, tr(" do território (IBGE, Biomas 1:250 mil, 2019). O bioma dominante determina o grupo a que o município pertence.",
                                  " of the territory (IBGE, Biomes 1:250,000, 2019). The municipality is grouped by its dominant biome.")))
}

# ---- Perfil do município ---------------------------------------------------------
tv <- function(id, mun_id, unidade = FALSE) {
  r <- info_ind(id); u <- ultimo(id, mun_id)
  if (identical(u$sinal, "valor")) paste0(fmt_valor(u$valor, r$fmt), if (unidade) paste0(" ", r$unidade) else "")
  else SINAL_TXT[[u$sinal]]
}
tem_valor <- function(id, mun_id) identical(ultimo(id, mun_id)$sinal, "valor")
# Unidade como aparece na tela: valores "brl_mil" são exibidos em reais (R$ 81,4 mi), não em R$ mil
unid <- function(r) if (identical(r$fmt, "brl_mil")) sub(tr("R\\$ mil", "R\\$ thousand"), "R$", r$unidade) else r$unidade

# Cartão KPI do perfil (como kpi() de R/funcoes.R, com a unidade da tela e o empate em zero)
kpi_mun <- function(id, mun_id, prefixo = "../indicadores/") {
  r <- info_ind(id); s <- resumo_ind(id, mun_id)
  comp <- comp_kpi(r, s)
  sit <- situacao(s$valor_calc, s$med_bioma, r$sentido)
  div(class = "kpi",
      div(class = "kpi-rotulo", a(href = url_ind(id, prefixo), r$rotulo_curto)),
      div(class = "kpi-valor", HTML(html_celula(s$valor, s$sinal, r$fmt))),
      div(class = "kpi-meta", paste0(unid(r), if (!is.na(s$ano)) paste0(" · ", s$ano) else "")),
      div(class = "kpi-comp", comp,
          if (!isTRUE(r$soma == 1) && sit$cls != "sit-neutra") span(class = paste("sit", sit$cls), sit$txt)))
}
grade_kpis_mun <- function(mun_id, ids = IND$id[IND$kpi == 1], prefixo = "../indicadores/")
  div(class = "kpi-grade", lapply(ids, kpi_mun, mun_id = mun_id, prefixo = prefixo))
tt <- function(id) TOT$valor[TOT$id == id]
med_txt <- function(id, mun_id) { r <- info_ind(id); fmt_valor(resumo_ind(id, mun_id)$med_bioma, r$fmt) }

link_piloto <- function(slug, prefixo = "../pilotos/") {
  if (is.na(slug) || !nzchar(slug)) return(paste0(prefixo, "index.html"))
  if (file.exists(file.path(RAIZ, "pilotos", paste0(slug, ".qmd")))) paste0(prefixo, slug, ".html") else paste0(prefixo, "index.html")
}

cabecalho_municipio <- function(mun_id) {
  m <- MUN[MUN$id_municipio == mun_id, ]
  nt <- sum(MUN$tipo_m1 == m$tipo_m1)
  div(class = "cabecalho-mun",
      p(style = "margin-bottom:.3rem", chip_bioma(m$bioma), " ", chip_tipo(m$tipo_m1),
        span(class = "sub", style = "margin-left:.5rem;white-space:nowrap", sprintf(tr("Código IBGE %d", "IBGE code %d"), m$id_municipio))),
      barra_biomas(mun_id),
      p(class = "sub", style = "margin-top:.3rem",
        HTML(sprintf(tr(paste0("No Manuscrito 1 do Projeto RESA, o município integra o tipo municipal da agricultura familiar %s, que reúne %d municípios ",
                               "(tipologia obtida por <i>k-means</i>, com k = 5, a partir dos escores da análise fatorial de 21 variáveis do Censo Agropecuário 2017). ",
                               '<a href="../resultados/tipologia.html">Detalhes da tipologia</a>.'),
                        paste0("RESA Project Manuscript 1 assigns the municipality to type %s, a group of %d municipalities, in its municipal typology of family farming. ",
                               "The typology applies <i>k-means</i>, with k = 5, to scores from a factor analysis of 21 variables in the 2017 Agricultural Census. ",
                               '<a href="../resultados/tipologia.html">Typology details</a>.')), m$tipo_m1, nt))))
}

aviso_sede <- function(mun_id) {
  m <- MUN[MUN$id_municipio == mun_id, ]
  if (!isTRUE(m$sede_piloto)) return(NULL)
  pl <- PIL[PIL$id_municipio == mun_id, ]
  div(class = "aviso-municipio",
      p(style = "margin-bottom:.35rem", tags$b(sprintf(tr("Sede da área-piloto %s. ", "Host municipality of the %s pilot area. "), m$piloto)), selo_conciliacao(), " ",
        HTML(sprintf(tr('Modalidade: %s. Bioma da área-piloto: %s (%s). Reconhecimento de campo: %s. <a href="%s">Página da área-piloto</a>.',
                        'Project type: %s. Pilot-area biome: %s (%s). Field reconnaissance: %s. <a href="%s">Pilot-area page</a>.'),
                     esc(pl$modalidade), nome_bioma(pl$bioma), esc(sub(" \\(([0-9]{4})\\)", ", \\1", pl$bioma_fonte)), esc(pl$reconhecimento_campo),
                     link_piloto(m$piloto_slug)))),
      p(style = "margin-bottom:0", tags$b(tr("O município não é a área-piloto. ", "The municipality is not the pilot area. ")),
        tr("Os números desta página descrevem o município inteiro ou o conjunto de sua agricultura familiar. ",
           "The figures on this page describe the whole municipality or all of its family farms. "),
        tr("Desse modo, fornecem o contexto da área-piloto, mas não a medem; os números de famílias e de área referentes à área-piloto somente serão publicados após a conciliação das fontes.",
           "They therefore provide context for the pilot area but do not measure it. Pilot-area figures for families and area will be published only once the sources have been reconciled.")))
}

variacao_txt <- function(id, mun_id) {
  u <- ultimo(id, mun_id)
  if (!identical(u$sinal, "valor")) return(paste(tr("apresentou variação", "changed by"), SINAL_TXT[[u$sinal]]))
  v <- u$valor
  if (abs(v) < 0.05) tr("permaneceu estável", "remained stable") else if (v > 0) paste(tr("cresceu", "rose by"), fmt_valor(v, "pct1")) else paste(tr("diminuiu", "fell by"), fmt_valor(-v, "pct1"))
}

texto_perfil <- function(mun_id) {
  m <- MUN[MUN$id_municipio == mun_id, ]; nome <- m$municipio; b <- m$bioma
  mb <- sprintf(tr("mediana dos municípios do bioma %s", "municipal median in the %s biome"), nome_bioma(b))
  P <- list()
  # 1. Estrutura
  P[[1]] <- sprintf(tr(paste0(
    "Em 2017, o Censo Agropecuário do Instituto Brasileiro de Geografia e Estatística (IBGE) registrou <b>%s estabelecimentos da agricultura familiar</b> (AF) em %s, o que correspondia a %s dos estabelecimentos agropecuários do município ",
    "(no conjunto de MT, essa participação era de %s). A AF ocupava %s ha, isto é, %s da área dos estabelecimentos, com área média de <b>%s ha por estabelecimento</b> (%s: %s ha; média de MT: %s ha). ",
    "Além disso, o pessoal ocupado na AF somava %s pessoas."),
    paste0(
    "The 2017 Agricultural Census of the Brazilian Institute of Geography and Statistics (IBGE) recorded <b>%s family farms</b> in %s, or %s of the municipality’s agricultural establishments ",
    "(%s for Mato Grosso as a whole). They occupied %s ha, or %s of the area of agricultural establishments, averaging <b>%s ha per establishment</b> (%s: %s ha; Mato Grosso mean: %s ha). ",
    "Persons employed on family farms totalled %s.")),
    tv("estab_af", mun_id), nome, tv("pct_estab_af", mun_id), fmt_valor(tt("pct_af_estab_mt"), "pct1"),
    tv("area_af", mun_id), tv("pct_area_af", mun_id), tv("area_media_af", mun_id), mb, med_txt("area_media_af", mun_id),
    fmt_valor(tt("area_media_af_mt"), "dec1"), tv("pessoal_af", mun_id))
  P[[1]] <- paste0(P[[1]], " ", if (tem_valor("valor_prod_af", mun_id))
    sprintf(tr("O valor da produção da AF alcançou <b>%s</b> (valores de 2017), o equivalente a %s por estabelecimento; %s.",
               "The value of family-farm production was <b>%s</b> (2017 values), equivalent to %s per establishment. %s."),
            tv("valor_prod_af", mun_id), tv("valor_prod_estab_af", mun_id),
            if (tem_valor("pct_valor_animal_af", mun_id)) sprintf(tr("a produção animal, por sua vez, respondeu por %s desse valor", "Animal production accounted for %s of this value"), tv("pct_valor_animal_af", mun_id))
            else sprintf(tr("a parcela da produção animal, contudo, não é publicada: %s", "However, the share from animal production is not published: %s"), tv("pct_valor_animal_af", mun_id)))
    else sprintf(tr("O valor da produção da AF não é publicado para o município: %s.", "The value of family-farm production is not published for this municipality: %s."), tv("valor_prod_af", mun_id)))
  # 2. Tecnologia e alimentos
  # Frase com o valor ou, quando o sinal é – (zero absoluto), com "nenhum"
  frase_pct <- function(id, com_valor, nenhum) {
    u <- ultimo(id, mun_id)
    if (identical(u$sinal, TRACO)) sprintf(nenhum, paste0(TRACO, tr(", zero absoluto", ", true zero"))) else sprintf(com_valor, tv(id, mun_id))
  }
  P[[2]] <- paste0(sprintf(tr(paste0(
    "Quanto à tecnologia, à assistência e ao crédito, verifica-se que, em 2017, %s dos estabelecimentos da AF tinham trator, %s recebiam orientação técnica e %s obtiveram financiamento ",
    "(%s: %s, %s e %s, respectivamente). "),
    paste0(
    "In 2017, %s of family farms had a tractor, %s received technical guidance and %s obtained financing ",
    "(%s: %s, %s and %s). ")),
    tv("pct_trator_af", mun_id), nenhum_en(tv("pct_orientacao_af", mun_id)), nenhum_en(tv("pct_financiamento_af", mun_id)), sprintf(tr("medianas dos municípios do bioma %s", "municipal medians in the %s biome"), nome_bioma(b)),
    med_txt("pct_trator_af", mun_id), med_txt("pct_orientacao_af", mun_id), med_txt("pct_financiamento_af", mun_id)),
    frase_pct("pct_consumo_proprio_af", tr("Observa-se, ainda, que %s dos estabelecimentos da AF produziam principalmente para consumo próprio", "In addition, %s of family farms produced mainly for their own consumption"),
              tr("Observa-se, ainda, que nenhum estabelecimento da AF produzia principalmente para consumo próprio (%s)", "No family farms produced mainly for their own consumption (%s)")),
    frase_pct("pct_leite_af", tr(" e que %s produziam leite de vaca.", " and %s produced cow’s milk."), tr(" e que nenhum estabelecimento da AF produzia leite de vaca (%s).", " and none produced cow’s milk (%s).")))
  # 3. Posse
  e46 <- ultimo("estab_af_46504", mun_id)
  txt46 <- if (identical(e46$sinal, "valor") && isTRUE(e46$valor > 0))
    sprintf(tr("Em relação à posse, a categoria 46504 do Censo 2017, que corresponde à condição de concessionário(a) ou assentado(a) aguardando titulação definitiva, reunia %s, o que representava %s da AF do município (no conjunto de MT, %s).",
               "On land tenure, the 2017 Census recorded %s in category 46504 (status of grantee or settler awaiting a definitive title), or %s of the municipality’s family farms (%s for Mato Grosso as a whole)."),
            if (e46$valor == 1) tr("<b>1 estabelecimento da AF</b>", "<b>one family farm</b>") else sprintf(tr("<b>%s estabelecimentos da AF</b>", "<b>%s family farms</b>"), tv("estab_af_46504", mun_id)),
            tv("pct_estab_46504", mun_id), fmt_valor(tt("pct_46504_estab_mt"), "pct1"))
  else if (identical(e46$sinal, TRACO) || (identical(e46$sinal, "valor") && isTRUE(e46$valor == 0)))
    sprintf(tr("Em relação à posse, o Censo 2017 não registrou estabelecimento da AF na categoria 46504, que corresponde à condição de concessionário(a) ou assentado(a) aguardando titulação definitiva; o valor publicado é %s.",
               "On land tenure, the 2017 Census recorded no family farms in category 46504 (status of grantee or settler awaiting a definitive title); the published value is %s."),
            tv("estab_af_46504", mun_id))
  else sprintf(tr("Em relação à posse, o número de estabelecimentos da AF na categoria 46504, que corresponde à condição de concessionário(a) ou assentado(a) aguardando titulação definitiva, não é publicado: %s.",
                    "On land tenure, the number of family farms in category 46504 (status of grantee or settler awaiting a definitive title) is not published: %s."),
               tv("estab_af_46504", mun_id))
  npa <- ultimo("n_pa", mun_id)$valor
  txtpa <- if (isTRUE(npa > 0))
    sprintf(tr("No Sistema de Informações de Projetos de Reforma Agrária (SIPRA) do Instituto Nacional de Colonização e Reforma Agrária (INCRA), %s sede no município, com %s famílias assentadas e %s ha (Relatório 0227, posição de 03/06/2025; cada projeto é contabilizado apenas no município-sede).",
               "The Agrarian Reform Projects Information System (SIPRA) of the National Institute for Colonisation and Agrarian Reform (INCRA) records %s based in the municipality, with %s settled families and %s ha (Report 0227, as at 3 June 2025). Each project is counted only in its host municipality."),
            if (npa == 1) tr("1 projeto de assentamento tem", "one settlement project") else sprintf(tr("%s projetos de assentamento têm", "%s settlement projects"), tv("n_pa", mun_id)),
            tv("fam_pa", mun_id), tv("area_pa", mun_id))
  else tr("O Sistema de Informações de Projetos de Reforma Agrária (SIPRA) do Instituto Nacional de Colonização e Reforma Agrária (INCRA) não registra projeto de assentamento com sede no município (Relatório 0227, posição de 03/06/2025).",
          "The Agrarian Reform Projects Information System (SIPRA) of the National Institute for Colonisation and Agrarian Reform (INCRA) records no settlement projects based in the municipality (Report 0227, as at 3 June 2025).")
  sub46 <- if (isTRUE(npa > 0) && !(identical(e46$sinal, "valor") && isTRUE(e46$valor > 0)))
    tr("Ressalta-se que a ausência de registro na categoria 46504 não implica ausência de famílias assentadas, uma vez que a categoria sub-registra a reforma agrária: o produtor que já obteve o título aparece como proprietário(a).",
       "The absence of records in category 46504 does not imply that there are no settled families, because the category understates the extent of agrarian reform: producers who have already obtained their title appear as owners.")
  else tr("Cabe ressaltar que a categoria 46504 sub-registra a reforma agrária, uma vez que o produtor que já obteve o título aparece como proprietário(a).",
          "Category 46504 understates the extent of agrarian reform, because producers who have already obtained their title appear as owners.")
  P[[3]] <- paste(txt46, txtpa, sub46, tr('O tema é discutido em <a href="../resultados/posse.html">Posse no Censo e reforma agrária</a>.',
                                          'See <a href="../resultados/posse.html">Census tenure data and agrarian reform</a> for a discussion.'))
  # 4. Clima e dinâmica
  ub <- ultimo("seeg_emissao_bruta", mun_id)
  P[[4]] <- if (identical(ub$sinal, "valor") && isTRUE(ub$valor > 0)) {
    pm <- 100 * ultimo("seeg_mut", mun_id)$valor / ub$valor; pa <- 100 * ultimo("seeg_agropecuaria", mun_id)$valor / ub$valor
    sprintf(tr(paste0("Para 2024, o Sistema de Estimativas de Emissões e Remoções de Gases de Efeito Estufa (SEEG 13) estimou emissões brutas de <b>%s mil tCO2e</b> (GWP-AR5) no município inteiro, e não apenas na AF. Desse total, %s provieram da mudança de uso da terra e florestas e %s, da agropecuária. ",
                      "As remoções, no mesmo ano, somaram %s mil tCO2e."),
               paste0("For 2024, the Greenhouse Gas Emissions and Removals Estimation System (SEEG 13) estimated gross emissions of <b>%s thousand tCO2e</b> (GWP-AR5) for the whole municipality, not only for family farming. Of this total, %s came from land-use change and forestry and %s from agriculture and livestock. ",
                      "Removals in the same year totalled %s thousand tCO2e.")),
            tv("seeg_emissao_bruta", mun_id), fmt_valor(pm, "pct1"), fmt_valor(pa, "pct1"), tv("seeg_remocoes", mun_id))
  } else sprintf(tr("Emissões brutas estimadas para 2024 pelo Sistema de Estimativas de Emissões e Remoções de Gases de Efeito Estufa (SEEG 13), no município inteiro: %s mil tCO2e.",
                     "Gross emissions for the whole municipality, as estimated for 2024 by the Greenhouse Gas Emissions and Removals Estimation System (SEEG 13): %s thousand tCO2e."), tv("seeg_emissao_bruta", mun_id))
  P[[4]] <- paste(P[[4]], sprintf(tr(paste0("Por fim, entre os Censos Agropecuários de 2006 e 2017, o número de estabelecimentos agropecuários do município (AF e não AF) %s, e a área %s."),
                                             "Between the 2006 and 2017 Agricultural Censuses, the number of agricultural establishments in the municipality (family and non-family farms) %s, and their area %s."),
                                  variacao_txt("var_estab_0617", mun_id), variacao_txt("var_area_0617", mun_id)))
  tagList(lapply(P, function(x) p(HTML(x))))
}

tabela_posicao <- function(mun_id, ids = IND$id[IND$kpi == 1], prefixo = "../indicadores/") {
  m <- MUN[MUN$id_municipio == mun_id, ]
  ut_ids <- ids_grupo("tipo", m$tipo_m1)
  d <- bind_rows(lapply(ids, function(id) {
    r <- info_ind(id); s <- resumo_ind(id, mun_id)
    u <- ULT$ultimos[ULT$ultimos$indicador == id & ULT$ultimos$id_municipio %in% ut_ids, ]
    pos_t <- if (is.na(s$valor_calc)) NA_integer_ else sum(u$valor_calc > s$valor_calc, na.rm = TRUE) + 1L
    n_t <- sum(!is.na(u$valor_calc))
    pos <- function(p, n, vals) {
      if (is.na(p)) return(sprintf(tr("sem posição: %s", "not ranked: %s"), SINAL_TXT[[s$sinal]]))
      emp <- sum(abs(vals - s$valor_calc) < 1e-9, na.rm = TRUE) - 1L
      paste0(tr(sprintf("%dº maior de %d", p, n), posicao_en(p, n)), if (emp > 0) sprintf(tr('<div class="sub">empatado com %d</div>', if (emp == 1) '<div class="sub">tied with %d other</div>' else '<div class="sub">tied with %d others</div>'), emp) else "")
    }
    cel <- function(p, n, med, vals) { sit <- situacao(s$valor_calc, med, r$sentido)
      sprintf(tr('<b>%s</b><div class="sub">mediana %s <span class="sit %s">%s</span></div>', '<b>%s</b><div class="sub">median %s <span class="sit %s">%s</span></div>'), pos(p, n, vals), fmt_valor(med, r$fmt), sit$cls, sit$txt) }
    tibble(Indicador = sprintf('<a href="%s">%s</a><div class="sub">%s · %s</div>', url_ind(id, prefixo), esc(r$rotulo_curto), esc(unid(r)), s$ano),
           Valor = sprintf("<b>%s</b>", html_celula(s$valor, s$sinal, r$fmt)),
           Bioma = cel(s$pos_bioma, s$n_bioma, s$med_bioma, s$vals_bioma),
           Tipo = cel(pos_t, n_t, s$med_tipo, u$valor_calc),
           MT = cel(s$pos_mt, s$n_mt, s$med_mt, s$vals_mt))
  }))
  reactable(d, compact = TRUE, sortable = FALSE, pagination = FALSE, wrap = TRUE, class = "tabela-dim",
            columns = list(Indicador = colDef(name = tr("Indicador", "Indicator"), html = TRUE, minWidth = 200),
                           Valor = colDef(name = tr("Valor", "Value"), html = TRUE, align = "right", minWidth = 95),
                           Bioma = colDef(html = TRUE, name = tr(paste("No bioma", m$bioma), paste("In the", nome_bioma(m$bioma), "biome")), minWidth = 150),
                           Tipo = colDef(html = TRUE, name = tr(paste0("No tipo ", m$tipo_m1, " do M1"), paste0("In M1 type ", m$tipo_m1)), minWidth = 150),
                           MT = colDef(html = TRUE, name = tr("Em Mato Grosso", "In Mato Grosso"), minWidth = 150)))
}

svg_seeg_mun <- function(mun_id, nome) {
  ser <- list(c("seeg_emissao_bruta", COR[["mun"]], 2.8, ""), c("seeg_mut", "#b45309", 2, ""),
              c("seeg_agropecuaria", "#eda100", 2, ""), c("seeg_remocoes", "#2a78d6", 1.8, "5,3"))
  linhas <- lapply(ser, function(z) {
    s <- SER[SER$indicador == z[1] & SER$id_municipio == mun_id & SER$ano >= ano_ini(z[1]), ] |> arrange(ano)
    list(nome = info_ind(z[1])$rotulo_curto, cor = z[2], larg = as.numeric(z[3]), dash = z[4], x = s$ano, y = s$valor_calc)
  })
  svg_linhas_leve(linhas, fmt = "dec1", titulo = tr(paste0("Emissões e remoções de GEE, ", nome, ", 1970–2024 (mil tCO2e)"), paste0("GHG emissions and removals, ", nome, ", 1970–2024 (thousand tCO2e)")), h = 240)
}

# ---- Tabela dos 141 municípios (página índice) ------------------------------------
# name recebe a chave da coluna (usada no setFilter); rotulo_en é o nome legível do aria-label em inglês
filtro_select <- function(id_tab, opcoes, rotulos = opcoes, rotulo_en = NULL) function(values, name)
  tags$select(class = "form-select form-select-sm", `aria-label` = tr(paste("Filtrar", name), paste("Filter by", if (is.null(rotulo_en)) name else rotulo_en)),
              onchange = sprintf("Reactable.setFilter('%s', '%s', event.target.value || undefined)", id_tab, name),
              tags$option(value = "", tr("Todos", "All")),
              lapply(seq_along(opcoes), function(i) tags$option(value = opcoes[i], rotulos[i])))
filtro_igual <- JS("function(rows, columnId, filterValue) { return rows.filter(function(row) { return String(row.values[columnId]) === filterValue }) }")

tabela_municipios <- function(prefixo = "", prefixo_ind = "../indicadores/", id_tab = "tab-municipios",
                              ids = c("estab_af", "pct_estab_af", "area_media_af", "pct_estab_46504", "pct_area_46504",
                                      "valor_prod_estab_af", "n_pa", "fam_pa", "seeg_emissao_bruta", "var_estab_0617")) {
  # Uma só ordem para nomes e valores: as linhas seguem d e os valores são casados pelo código IBGE
  d <- ordenar_pt(MUN) |>
    transmute(id_municipio, Município = municipio, slug, sede = sede_piloto, piloto, Bioma = bioma, Tipo = tipo_m1)
  html <- list()
  for (id in ids) {
    r <- info_ind(id); u <- ULT$ultimos[ULT$ultimos$indicador == id, ]
    u <- u[match(d$id_municipio, u$id_municipio), ]
    stopifnot(identical(as.integer(u$id_municipio), as.integer(d$id_municipio)))
    d[[id]] <- u$valor_calc
    html[[id]] <- html_celula(u$valor, u$sinal, r$fmt)
  }
  col_ind <- lapply(ids, function(id) local({
    r <- info_ind(id); h <- html[[id]]
    colDef(header = HTML(sprintf('<a href="%s">%s</a><div class="sub">%s · %s</div>', url_ind(id, prefixo_ind),
                                 esc(r$rotulo_curto), esc(unid(r)), ano_ref(id))),
           html = TRUE, align = "right", minWidth = 115, filterable = FALSE, sortNALast = TRUE,
           cell = function(v, i) h[i])
  }))
  names(col_ind) <- ids
  cols <- c(list(
    id_municipio = colDef(show = FALSE),
    slug = colDef(show = FALSE), sede = colDef(show = FALSE), piloto = colDef(show = FALSE),
    # name = NULL em português: um name explícito em chave com acento muda o dataKey do reactable
    Município = colDef(name = tr(NULL, "Municipality"), minWidth = 175, sticky = "left", filterable = FALSE, html = TRUE,
      cell = function(v, i) {
        nm <- if (tem_perfil(d$slug[i])) sprintf('<a href="%s%s.html">%s</a>', prefixo, d$slug[i], esc(v)) else esc(v)
        if (isTRUE(d$sede[i])) paste0(nm, sprintf(tr('<div class="sub">sede da área-piloto %s</div>', '<div class="sub">host municipality of the %s pilot area</div>'), esc(d$piloto[i]))) else nm
      }),
    Bioma = colDef(name = tr("Bioma", "Biome"), minWidth = 120, html = TRUE, filterInput = filtro_select(id_tab, BIOMAS, nome_bioma(BIOMAS), rotulo_en = "biome"), filterMethod = filtro_igual,
                   cell = function(v) sprintf('<span class="chip chip-%s">%s</span>', SLUG_BIOMA[[v]], nome_bioma(v))),
    Tipo = colDef(name = tr("Tipo do M1", "M1 type"), minWidth = 120, html = TRUE,
                  filterInput = filtro_select(id_tab, names(TIPOS), sprintf("%s · %s", names(TIPOS), TIPOS), rotulo_en = "M1 type"), filterMethod = filtro_igual,
                  cell = function(v) sprintf(tr('<span class="chip chip-%s" data-tip="%s · %s (rótulo provisório)">%s</span>', '<span class="chip chip-%s" data-tip="%s · %s (provisional label)">%s</span>'), tolower(v), v, esc(TIPOS[[v]]), v))),
    col_ind)
  reactable(d, elementId = id_tab, columns = cols, filterable = TRUE, searchable = TRUE, compact = TRUE, striped = TRUE,
            highlight = TRUE, defaultSorted = "Município", defaultPageSize = 20, showPageSizeOptions = TRUE,
            pageSizeOptions = c(20, 50, 141), wrap = TRUE)
}

# ---- Páginas de indicador ------------------------------------------------------------
links_sidra <- function(fonte) {
  f <- esc(fonte)
  m <- regmatches(f, gregexpr("\\b6[0-9]{3}\\b", f))[[1]]
  if (!grepl("SIDRA", f) || !length(m)) return(HTML(f))
  for (t in unique(m)) f <- sub(sprintf("\\b%s\\b", t), sprintf('<a href="https://sidra.ibge.gov.br/tabela/%s">%s</a>', t, t), f)
  HTML(f)
}

REGRA_TXT <- tr(c(soma = "soma dos municípios", razao = "razão das somas dos municípios", variacao = "variação das somas dos municípios"),
                c(soma = "municipal sum", razao = "ratio of municipal sums", variacao = "change in municipal sums"))

meta_indicador <- function(id) {
  r <- info_ind(id)
  ano <- if (identical(r$origem, "sipra")) tr("2025 (posição de 03/06/2025)", "2025 (as at 3 June 2025)")
         else if (isTRUE(r$serie == 1)) sprintf(tr("%s (série %s)", "%s (series %s)"), r$ano_ref, periodo_serie(id))
         else if (identical(r$origem, "censo2006_2017")) tr("2006 e 2017 (variação entre os Censos)", "2006 and 2017 (change between the Censuses)") else as.character(r$ano_ref)
  sentido <- tr(c("-1" = "valores menores são mais favoráveis", "0" = "indicador de contexto, sem sentido de melhor ou pior", "1" = "valores maiores são mais favoráveis"),
                c("-1" = "lower values are more favourable", "0" = "context indicator: neither higher nor lower values are better", "1" = "higher values are more favourable"))[[as.character(r$sentido)]]
  linha <- function(rot, ...) tagList(tags$dt(style = "font-weight:600;color:#4b5563", rot), tags$dd(style = "margin:0", ...))
  div(class = "meta-ind",
      tags$dl(style = "display:grid;grid-template-columns:minmax(7.5rem,max-content) 1fr;gap:.25rem 1rem;font-size:.92rem;margin:0 0 1rem",
              linha(tr("Tema", "Theme"), a(href = paste0("index.html#", r$dim), r$tema)),
              linha(tr("Unidade", "Unit"), r$unidade, if (identical(r$fmt, "brl_mil")) span(class = "sub", tr(" · exibida em reais (mil, mi, bi); no CSV, em R$ mil", " · shown in reais (thousand, million, billion); in R$ thousand in the CSV"))),
              linha(tr("Ano de referência", "Reference year"), ano),
              linha(tr("Fonte", "Source"), links_sidra(r$fonte)),
              linha(tr("Cálculo", "Calculation"), r$calculo,
                    span(class = "sub", sprintf(tr(" · agregados por %s · %s. Os nomes das variáveis constam do dicionário dos downloads.", " · aggregated as the %s · %s. Variable names are listed in the data dictionary included with the downloads."), REGRA_TXT[[r$agregacao]], sentido))),
              if (!is.na(r$nota) && nzchar(r$nota)) linha(tr("Nota", "Note"), r$nota)))
}

notas_indicador <- function(id) {
  r <- info_ind(id); n <- character(0)
  if (identical(r$origem, "seeg")) {
    soma <- agregado(id, "MT")$valor
    est <- c(seeg_emissao_bruta = "seeg_bruta_mt_2024", seeg_mut = "seeg_mut_mt_2024", seeg_agropecuaria = "seeg_agro_mt_2024")
    comp <- ""
    if (id %in% names(est)) {
      tot <- 1000 * tt(est[[id]]); dif <- tot - soma
      comp <- if (abs(dif) < 0.05) sprintf(tr(" Em 2024, a soma dos municípios atinge %s mil tCO2e, valor igual ao total estadual do SEEG.", " In 2024, the municipal sum is %s thousand tCO2e, equal to the SEEG state total."), fmt_valor(soma, "dec1"))
              else sprintf(tr(" Em 2024, a soma dos municípios atinge %s mil tCO2e, ao passo que o total estadual do SEEG é de %s mil tCO2e; a diferença, de %s mil tCO2e, não é atribuída a nenhum município.",
                              " In 2024, the municipal sum is %s thousand tCO2e and the SEEG state total is %s thousand tCO2e. The difference of %s thousand tCO2e is not attributed to any municipality."),
                           fmt_valor(soma, "dec1"), fmt_valor(tot, "dec1"), fmt_valor(dif, "dec1"))
    }
    n <- c(n, paste0(tr("**O SEEG mede o município inteiro, e não a agricultura familiar.** As estimativas do Sistema de Estimativas de Emissões e Remoções de Gases de Efeito Estufa (SEEG 13, Observatório do Clima, GWP-AR5) abrangem todas as atividades do território municipal.",
                        "**SEEG measures the whole municipality, not family farming.** Estimates from the Greenhouse Gas Emissions and Removals Estimation System (SEEG 13, Observatório do Clima, GWP-AR5) cover all activities in the municipal territory."), comp,
                     tr(" Os dados municipais do SEEG não integram os downloads do site até a conferência da licença; para obtê-los, deve-se recorrer ao portal do SEEG. ",
                        " SEEG municipal data will not be included in the website’s downloads until the licence has been checked. To obtain them, use the SEEG portal. "), NOTA_1990))
  }
  if (identical(r$origem, "censo2006_2017"))
    n <- c(n, tr("**Dinâmica 2006–2017: todos os estabelecimentos agropecuários (AF e não AF).** A soma municipal de 2006 não coincide com a tabela estadual do Instituto Brasileiro de Geografia e Estatística (IBGE): 112.987 contra 112.978 estabelecimentos e 48,69 contra 47,81 milhões de ha. Por essa razão, as variações municipais devem ser interpretadas com essa ressalva.",
                 "**2006–2017 dynamics: all agricultural establishments (family and non-family farms).** The 2006 municipal sum does not match the state table from the Brazilian Institute of Geography and Statistics (IBGE): 112,987 against 112,978 establishments and 48.69 against 47.81 million ha. Municipal changes should be interpreted with this caveat in mind."))
  if (grepl("46504", id))
    n <- c(n, tr("**A categoria 46504 sub-registra a reforma agrária.** A categoria reúne apenas os produtores na condição de concessionário(a) ou assentado(a) aguardando titulação definitiva (Censo 2017); o produtor que já obteve o título, por sua vez, aparece como proprietário(a). Portanto, a categoria não equivale ao total de assentados. O tema é discutido em [Posse no Censo e reforma agrária](../resultados/posse.qmd).",
                 "**Category 46504 understates the extent of agrarian reform.** It includes only producers with the status of grantee or settler awaiting a definitive title (2017 Census); producers who have already obtained their title appear as owners. The category is therefore not equivalent to the total number of settlers. See [Census tenure data and agrarian reform](../resultados/posse.qmd) for a discussion."))
  if (identical(r$origem, "sipra"))
    n <- c(n, tr("**O Sistema de Informações de Projetos de Reforma Agrária (SIPRA) contabiliza cada projeto no município-sede** (INCRA, Relatório 0227, posição de 03/06/2025). Os projetos que se estendem por mais de um município não são divididos entre eles; além disso, as áreas-piloto de crédito fundiário não constituem projetos do INCRA.",
                 "**The Agrarian Reform Projects Information System (SIPRA) counts each project in its host municipality** (INCRA, Report 0227, as at 3 June 2025). Projects extending across more than one municipality are not divided between them, and land credit pilot areas are not INCRA projects."))
  if (identical(r$origem, "censo2017") && !grepl("46504", id))
    n <- c(n, tr("A agricultura familiar segue a definição da Lei 11.326/2006, na tipologia do Censo Agropecuário 2017. O sinal X indica dado sob sigilo do Instituto Brasileiro de Geografia e Estatística (IBGE), e não zero.",
                 "Family farming is as defined by Law 11.326/2006, following the typology of the 2017 Agricultural Census. The symbol X marks a value suppressed by the Brazilian Institute of Geography and Statistics (IBGE), not zero."))
  n
}

TOT_IND <- c(estab_af = "tot_af_estab", pct_estab_af = "pct_af_estab_mt", area_af = "tot_af_area", pct_area_af = "pct_af_area_mt",
             area_media_af = "area_media_af_mt", pessoal_af = "tot_af_pessoal", valor_prod_af = "vbp_af_mt",
             estab_af_46504 = "tot_46504_estab", pct_estab_46504 = "pct_46504_estab_mt", pct_area_46504 = "pct_46504_area_mt",
             n_pa = "n_pa_mt", fam_pa = "fam_pa_mt", area_pa = "area_pa_mt",
             seeg_emissao_bruta = "seeg_bruta_mt_2024", seeg_mut = "seeg_mut_mt_2024", seeg_agropecuaria = "seeg_agro_mt_2024")

cartoes_indicador <- function(id) {
  r <- info_ind(id); ag <- agregado(id, "MT"); e <- escala_natural(r)
  cont <- table(factor(ULT$ultimos$sinal[ULT$ultimos$indicador == id], c("valor", "X", TRACO, "...")))
  oficial <- if (id %in% names(TOT_IND)) {
    t <- TOT[TOT$id == TOT_IND[[id]], ]
    f <- if (identical(t$unidade, "MtCO2e")) 1000 else 1
    cartao_kpi(tr("Total oficial de Mato Grosso", "Official total for Mato Grosso"), fmt_valor(t$valor * f, r$fmt), paste0(unid(r), " · ", t$ano), t$fonte)
  }
  div(class = "kpi-grade",
      cartao_kpi(paste("Mato Grosso,", REGRA_TXT[[r$agregacao]]), fmt_valor(ag$valor * e$f, e$fmt), paste0(unid(r), " · ", ag$ano),
                 sprintf(tr("%d de %d municípios com valor publicado", "%d of %d municipalities with a published value"), ag$n_usados, ag$n_mun)),
      oficial,
      cartao_kpi(tr("Mediana dos municípios de MT", "Median across MT municipalities"), fmt_valor(ag$mediana * e$f, e$fmt), paste0(unid(r), " · ", ag$ano),
                 sprintf(tr("%s é tratado como zero; X e ... são excluídos", "%s is treated as zero; X and ... are excluded"), TRACO)),
      cartao_kpi(tr("Sinais do IBGE nos 141 municípios", "IBGE symbols in the 141 municipalities"), HTML(sprintf(tr('%d <span class="sub">com valor</span>', '%d <span class="sub">with a value</span>'), cont[["valor"]])),
                 HTML(sprintf('<span class="sinal sinal-x">X</span> %d · <span class="sinal sinal-zero">%s</span> %d · <span class="sinal sinal-nd">...</span> %d',
                              cont[["X"]], TRACO, cont[[TRACO]], cont[["..."]])),
                 tr("X: sigilo · –: zero absoluto · ...: não disponível", "X: suppressed · –: true zero · ...: not available")))
}

cartoes_sedes <- function(id, prefixo = "../municipios/") {
  r <- info_ind(id)
  div(class = "kpi-grade", lapply(seq_len(nrow(SEDES)), function(i) {
    m <- SEDES[i, ]; s <- resumo_ind(id, m$id_municipio)
    pos <- if (is.na(s$pos_bioma)) tr("sem posição no ranking", "not ranked") else tr(sprintf("%dº maior de %d no bioma %s · %dº de %d em MT", s$pos_bioma, s$n_bioma, m$bioma, s$pos_mt, s$n_mt),
                                                                                       sprintf("%s in the %s biome · %s of %d in MT", posicao_en(s$pos_bioma, s$n_bioma), nome_bioma(m$bioma), ordinal(s$pos_mt), s$n_mt))
    nome <- if (tem_perfil(m$slug)) a(href = url_mun(m$slug, prefixo), m$municipio) else m$municipio
    div(class = "kpi",
        div(class = "kpi-rotulo", nome, span(class = "sub", tr(paste0(" · sede da área-piloto ", m$piloto), paste0(" · host municipality of the ", m$piloto, " pilot area")))),
        div(class = "kpi-valor", HTML(html_celula(s$valor, s$sinal, r$fmt))),
        div(class = "kpi-meta", paste0(unid(r), if (!is.na(s$ano)) paste0(" · ", s$ano) else "")),
        div(class = "kpi-comp", pos, tags$br(), sprintf(tr("Mediana do bioma: %s", "Biome median: %s"), fmt_valor(s$med_bioma, r$fmt))))
  }))
}

series_sedes <- function(id) {
  r <- info_ind(id); e <- escala_natural(r)
  cores <- c(COR[["mun"]], COR[["sede"]], "#2a78d6")
  ser <- lapply(seq_len(nrow(SEDES)), function(i) {
    s <- SER[SER$indicador == id & SER$id_municipio == SEDES$id_municipio[i] & SER$ano >= ano_ini(id), ] |> arrange(ano)
    list(nome = SEDES$municipio[i], cor = cores[i], larg = 2.4, dash = "", x = s$ano, y = s$valor_calc * e$f)
  })
  svg_linhas(ser, fmt = e$fmt, titulo = paste0(r$rotulo, tr(" — municípios-sede das áreas-piloto", " — pilot-area host municipalities")))
}

# Soma (ou agregado) por bioma ou por tipo ao longo dos anos; SEEG em MtCO2e (fator 1/1000)
series_grupos <- function(id, recorte = c("bioma", "tipo"), incluir_mt = FALSE) {
  recorte <- match.arg(recorte)
  r <- info_ind(id); e <- escala_natural(r)
  f <- if (identical(r$origem, "seeg")) 1 / 1000 else e$f
  fm <- if (identical(r$origem, "seeg")) "dec1" else e$fmt
  a <- AGR[AGR$indicador == id & AGR$ano >= ano_ini(id) & (AGR$recorte == recorte | (incluir_mt & AGR$recorte == "mt")), ]
  if (n_distinct(a$ano) < 2) return("")
  grupos <- if (recorte == "tipo") names(TIPOS) else BIOMAS
  cores <- if (recorte == "tipo") COR_TIPO else COR_BIOMA
  ser <- lapply(grupos, function(g) { x <- a[a$grupo == g, ] |> arrange(ano)
    list(nome = if (recorte == "tipo") paste0(g, " · ", TIPOS[[g]]) else nome_bioma(g), cor = cores[[g]], larg = 2.4, dash = "", x = x$ano, y = x$valor * f) })
  if (incluir_mt) { x <- a[a$grupo == "MT", ] |> arrange(ano)
    ser <- c(ser, list(list(nome = tr("Mato Grosso (soma dos municípios)", "Mato Grosso (municipal sum)"), cor = "#111827", larg = 2, dash = "2,3", x = x$ano, y = x$valor * f))) }
  svg_linhas(ser, fmt = fm, titulo = paste0(r$rotulo, tr(" por ", " by "), if (recorte == "tipo") tr("tipo do M1", "M1 type") else tr("bioma", "biome"),
                                            if (identical(r$origem, "seeg")) " (MtCO2e)" else ""))
}

tabela_ind_recorte <- function(id, prefixo = "../municipios/") {
  r <- info_ind(id); id_tab <- paste0("tab-", gsub("_", "-", id)); VP <- tr("valor publicado", "published value")
  u <- ULT$ultimos[ULT$ultimos$indicador == id, ] |>
    left_join(select(MUN, id_municipio, municipio, slug, bioma, tipo_m1, sede_piloto), by = "id_municipio")
  u <- u[order(-u$valor_calc, order(ordem_pt(u$municipio)), na.last = TRUE), ]
  # No CSV, a célula do número traz o próprio sinal quando não há número (X, – ou ...), como nas tabelas do IBGE
  d <- transmute(u, id_municipio, municipio, slug, bioma, tipo_m1, indicador = id, ano,
                 ordem = valor_calc, exibir = html_celula(valor, sinal, r$fmt),
                 valor = ifelse(sinal == "valor", num_csv(valor, DEC_CSV[[r$fmt]]), sinal), sinal, sinal_txt = ifelse(sinal == "valor", VP, unname(SINAL_TXT[sinal])),
                 unidade = r$unidade, sede = sede_piloto)
  dl <- c("id_municipio", "municipio", "bioma", "tipo_m1", "indicador", "ano", "valor", "sinal", "unidade")
  botao <- if (isTRUE(r$download == 1))
    tags$button(class = "btn btn-sm btn-outline-primary mb-2", type = "button",
                onclick = sprintf("Reactable.downloadDataCSV('%s', 'resa_%s.csv', {columnIds: [%s]})", id_tab, id,
                                  paste0("'", dl, "'", collapse = ", ")),
                tr("Baixar o recorte filtrado (CSV)", "Download filtered rows (CSV)"))
  else p(class = "nota-fonte", tr("Os dados municipais do SEEG não estão disponíveis para download no site até a conclusão da conferência da licença.",
                                  "SEEG municipal data cannot be downloaded from this website until the licence has been checked."))
  tagList(
    botao,
    reactable(d, elementId = id_tab, filterable = TRUE, searchable = TRUE, compact = TRUE, striped = TRUE, highlight = TRUE,
              defaultPageSize = 20, showPageSizeOptions = TRUE, pageSizeOptions = c(20, 50, 141),
              columns = list(
                id_municipio = colDef(name = tr("Código IBGE", "IBGE code"), minWidth = 90, filterable = FALSE),
                municipio = colDef(name = tr("Município", "Municipality"), minWidth = 170, filterable = FALSE, html = TRUE,
                                   cell = function(v, i) { nm <- if (tem_perfil(d$slug[i])) sprintf('<a href="%s">%s</a>', url_mun(d$slug[i], prefixo), esc(v)) else esc(v)
                                     if (isTRUE(d$sede[i])) paste0("<b>", nm, tr('</b> <span class="sub">sede de área-piloto</span>', '</b> <span class="sub">pilot-area host municipality</span>')) else nm }),
                slug = colDef(show = FALSE), sede = colDef(show = FALSE), indicador = colDef(show = FALSE),
                exibir = colDef(show = FALSE), valor = colDef(show = FALSE), sinal = colDef(show = FALSE), unidade = colDef(show = FALSE),
                bioma = colDef(name = tr("Bioma", "Biome"), minWidth = 110, html = TRUE, filterInput = filtro_select(id_tab, BIOMAS, nome_bioma(BIOMAS), rotulo_en = "biome"), filterMethod = filtro_igual,
                               cell = function(v) sprintf('<span class="chip chip-%s">%s</span>', SLUG_BIOMA[[v]], nome_bioma(v))),
                tipo_m1 = colDef(name = tr("Tipo do M1", "M1 type"), minWidth = 110, html = TRUE,
                                 filterInput = filtro_select(id_tab, names(TIPOS), sprintf("%s · %s", names(TIPOS), TIPOS), rotulo_en = "M1 type"), filterMethod = filtro_igual,
                                 cell = function(v) sprintf(tr('<span class="chip chip-%s" data-tip="%s · %s (rótulo provisório)">%s</span>', '<span class="chip chip-%s" data-tip="%s · %s (provisional label)">%s</span>'), tolower(v), v, esc(TIPOS[[v]]), v)),
                ordem = colDef(name = tr(paste0("Valor (", unid(r), ")"), paste0("Value: ", unid(r))), align = "right", html = TRUE, sortNALast = TRUE, filterable = FALSE,
                               minWidth = 120, cell = function(v, i) d$exibir[i]),
                sinal_txt = colDef(name = tr("Sinal", "Symbol"), minWidth = 130, filterInput = filtro_select(id_tab, c(VP, unname(SINAL_TXT)), rotulo_en = "symbol"),
                                   filterMethod = filtro_igual,
                                   style = function(v) if (!identical(v, VP)) list(fontWeight = 600) else list(color = "#6b7280")),
                ano = colDef(name = tr("Ano", "Year"), align = "center", minWidth = 60, filterable = FALSE))),
    p(class = "nota-fonte", tr("O arquivo CSV contém uma linha por município, com o valor (separador decimal em ponto) e o sinal. Quando o sinal é X (sigilo), ",
                                "The CSV file has one row per municipality, giving the value (with a decimal point) and the symbol. When the symbol is X (suppressed), "),
      TRACO, tr(" (zero absoluto) ou ... (não disponível), a coluna do valor registra o próprio sinal, à semelhança das tabelas do IBGE. As células com X ou ... não equivalem a zero, e o sinal – indica zero absoluto.",
                " (true zero) or ... (not available), the value column shows the symbol itself, as in the IBGE tables. Cells with X or ... do not mean zero, and the symbol – indicates a true zero."),
      if (isTRUE(r$download == 1)) tagList(tr(" O conjunto completo dos indicadores, acompanhado de dicionário, encontra-se no arquivo ",
                                              " The full set of indicators, with a data dictionary, is in the file "),
                                           a(href = paste0(ARQ_REL, "dados/resa_indicadores_municipios.csv"), download = NA, "resa_indicadores_municipios.csv"),
                                           " (", a(href = "../dados/index.html", tr("Dados", "Data")), ")."))
  )
}

cartoes_tema <- function(dim, prefixo = "") {
  g <- IND[IND$dim == dim, ] |> arrange(ordem)
  div(class = "lista-ind", lapply(seq_len(nrow(g)), function(j) {
    r <- g[j, ]; ag <- agregado(r$id, "MT"); e <- escala_natural(r)
    nx <- ag$n_x
    a(class = "cartao cartao-ind", href = paste0(prefixo, r$id, ".html"),
      h4(r$rotulo_curto, if (isTRUE(r$kpi == 1)) span(class = "selo", tr("chave", "key"))),
      p(paste0(unid(r), " · ", if (identical(r$origem, "sipra")) "2025" else if (isTRUE(r$serie == 1)) periodo_serie(r$id) else r$ano_ref)),
      p(style = "margin-top:.25rem", tags$b(fmt_valor(ag$valor * e$f, e$fmt)), span(class = "sub", paste0(" MT, ", REGRA_TXT[[r$agregacao]]))),
      if (isTRUE(nx > 0)) p(class = "sub", sprintf(tr("%d %s com X (sigilo)", "%d %s with X (suppressed)"), nx, if (nx == 1) tr("município", "municipality") else tr("municípios", "municipalities"))))
  }))
}

# ---- Versões leves para os 141 perfis --------------------------------------------
# Faixa de posição: os outros municípios num só <path> (pontos com stroke-linecap round)
svg_posicao_leve <- function(vals, destaque, med_ref, fmt, nome, w = 130, h = 26) {
  vals <- vals[is.finite(vals)]
  if (length(vals) < 2 || !destaque %in% names(vals)) return("")
  r <- range(c(vals, med_ref), na.rm = TRUE); if (diff(r) == 0) r <- r + c(-1, 1)
  sx <- function(v) 6 + (v - r[1]) / diff(r) * (w - 12)
  outros <- vals[names(vals) != destaque]
  pts <- paste(sprintf("M%.0f 13h0", sx(outros)), collapse = "")
  mt <- if (is.finite(med_ref)) sprintf(tr('<line x1="%.0f" x2="%.0f" y1="4" y2="22" stroke="#6b7280" stroke-dasharray="2,2" data-tip="Mediana de MT: %s"/>',
                                           '<line x1="%.0f" x2="%.0f" y1="4" y2="22" stroke="#6b7280" stroke-dasharray="2,2" data-tip="MT median: %s"/>'),
                                        sx(med_ref), sx(med_ref), fmt_valor(med_ref, fmt)) else ""
  sprintf(paste0(tr('<svg class="strip" viewBox="0 0 %d %d" width="%d" height="%d" role="img" aria-label="Posição entre os municípios do bioma">',
                    '<svg class="strip" viewBox="0 0 %d %d" width="%d" height="%d" role="img" aria-label="Rank among municipalities in the biome">'),
                 '<line x1="6" x2="%d" y1="13" y2="13" stroke="#e5e7eb" stroke-width="2"/>%s',
                 '<path d="%s" stroke="#b9d3c5" stroke-width="6.5" stroke-linecap="round" fill="none"/>',
                 '<circle cx="%.1f" cy="13" r="5.5" fill="%s" stroke="#fff" stroke-width="1.5" data-tip="%s: %s"/></svg>'),
          w, h, w, h, w - 6, mt, pts, sx(vals[[destaque]]), COR[["mun"]], esc(nome), fmt_valor(vals[[destaque]], fmt))
}

tabela_tema_mun <- function(dim, mun_id, nome_mun, prefixo = "../indicadores/") {
  ids <- IND$id[IND$dim == dim][order(IND$ordem[IND$dim == dim])]
  m <- MUN[MUN$id_municipio == mun_id, ]
  d <- bind_rows(lapply(ids, function(id) {
    r <- info_ind(id); s <- resumo_ind(id, mun_id); sit <- situacao(s$valor_calc, s$med_bioma, r$sentido)
    nota <- if (!is.na(r$nota) && nzchar(r$nota)) sprintf(' <span class="nota-i" title="%s">ⓘ</span>', esc(r$nota)) else ""
    ser <- if (isTRUE(r$serie == 1)) { x <- SER[SER$indicador == id & SER$id_municipio == mun_id & SER$ano >= ano_ini(id), ]; svg_sparkline(x$ano, x$valor_calc) } else ""
    tibble(
      Indicador = sprintf('<a href="%s">%s</a>%s<div class="sub">%s</div>', url_ind(id, prefixo), esc(r$rotulo), nota, esc(unid(r))),
      Valor = sprintf('<b>%s</b><div class="sub">%s</div>', html_celula(s$valor, s$sinal, r$fmt), ifelse(is.na(s$ano), "", s$ano)),
      Posicao = sprintf('%s<div class="sub">%s</div>%s', svg_posicao_leve(s$vals_bioma, as.character(mun_id), s$med_mt, r$fmt, nome_mun),
                        ifelse(is.na(s$pos_bioma), paste(tr("sem posição:", "not ranked:"), SINAL_TXT[s$sinal]), tr(sprintf("%dº maior de %d", s$pos_bioma, s$n_bioma), posicao_en(s$pos_bioma, s$n_bioma))),
                        if (nzchar(ser)) paste0(tr('<div class="sub">série ', '<div class="sub">series '), periodo_serie(id), '</div>', ser) else ""),
      Bioma = sprintf(tr('<span class="sit %s">%s</span><div class="sub">mediana %s</div>', '<span class="sit %s">%s</span><div class="sub">median %s</div>'), sit$cls, sit$txt, fmt_valor(s$med_bioma, r$fmt)),
      Tipo = fmt_valor(s$med_tipo, r$fmt),
      MT = fmt_valor(s$med_mt, r$fmt))
  }))
  reactable(d, compact = TRUE, highlight = TRUE, sortable = FALSE, pagination = FALSE, wrap = TRUE, class = "tabela-dim",
            columns = list(
              Indicador = colDef(name = tr("Indicador", "Indicator"), html = TRUE, minWidth = 220),
              Valor = colDef(name = tr("Valor", "Value"), html = TRUE, align = "right", minWidth = 95),
              Posicao = colDef(name = tr(paste("Posição no bioma", m$bioma), paste("Rank in the", nome_bioma(m$bioma), "biome")), html = TRUE, align = "center", minWidth = 150),
              Bioma = colDef(name = tr(paste("Frente ao bioma", m$bioma), paste("Relative to the", nome_bioma(m$bioma), "biome")), html = TRUE, align = "center", minWidth = 120),
              Tipo = colDef(name = tr(paste0("Mediana do tipo ", m$tipo_m1), paste0("Type ", m$tipo_m1, " median")), align = "right", minWidth = 95),
              MT = colDef(name = tr("Mediana MT", "MT median"), align = "right", minWidth = 90)))
}

# Linhas sem um círculo por ponto: a dica de cada ano (faixa vertical) traz todos os valores
svg_linhas_leve <- function(series, fmt, titulo = "", w = 680, h = 250) {
  xs <- sort(unique(unlist(lapply(series, `[[`, "x")))); ys <- unlist(lapply(series, `[[`, "y")); ys <- ys[is.finite(ys)]
  if (length(xs) < 2 || length(ys) < 2) return("")
  pl <- 62; pr <- 14; pt <- 12; pb <- 26
  xr <- range(xs); yt <- pretty(range(c(0, ys)), n = 5); yr <- range(yt)
  sx <- function(x) pl + (x - xr[1]) / diff(xr) * (w - pl - pr)
  sy <- function(y) h - pb - (y - yr[1]) / diff(yr) * (h - pt - pb)
  grade <- paste(sprintf('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#eef0f4"/><text x="%d" y="%.1f" text-anchor="end" font-size="11" fill="#6b7280">%s</text>',
                         pl, w - pr, sy(yt), sy(yt), pl - 6, sy(yt) + 4, fmt_eixo(yt)), collapse = "")
  xt <- pretty(xr, n = 6); xt <- xt[xt >= xr[1] & xt <= xr[2]]
  eixo <- paste(sprintf('<text x="%.1f" y="%d" text-anchor="middle" font-size="11" fill="#6b7280">%d</text>', sx(xt), h - 8, as.integer(xt)), collapse = "")
  linhas <- paste(vapply(series, function(s) {
    o <- order(s$x); x <- s$x[o]; y <- s$y[o]; ok <- is.finite(y)
    if (sum(ok) < 2) return("")
    sprintf('<polyline fill="none" stroke="%s" stroke-width="%s" %s points="%s"/>', s$cor, s$larg,
            if (nzchar(s$dash)) sprintf('stroke-dasharray="%s"', s$dash) else "",
            paste(sprintf("%.1f,%.1f", sx(x[ok]), sy(y[ok])), collapse = " "))
  }, character(1)), collapse = "")
  passo <- (w - pl - pr) / (length(xs) - 1)
  faixas <- paste(vapply(xs, function(a) {
    v <- vapply(series, function(s) { y <- s$y[s$x == a]; if (length(y) && is.finite(y[1])) paste0(s$nome, ": ", fmt_valor(y[1], fmt)) else NA_character_ }, character(1))
    sprintf('<rect x="%.1f" y="%d" width="%.1f" height="%d" fill="transparent" data-tip="%d · %s"/>', sx(a) - passo / 2, pt, passo, h - pt - pb,
            as.integer(a), esc(paste(v[!is.na(v)], collapse = " · ")))
  }, character(1)), collapse = "")
  leg <- paste(vapply(series, function(s) sprintf('<span class="leg-item"><svg width="22" height="8"><line x1="0" x2="22" y1="4" y2="4" stroke="%s" stroke-width="%s" %s/></svg>%s</span>',
                                                  s$cor, s$larg, if (nzchar(s$dash)) sprintf('stroke-dasharray="%s"', s$dash) else "", esc(s$nome)), character(1)), collapse = "")
  sprintf('<figure class="grafico-svg"><svg viewBox="0 0 %d %d" width="100%%" role="img" aria-label="%s">%s%s%s%s</svg><figcaption class="legenda-svg">%s</figcaption></figure>',
          w, h, esc(titulo), grade, eixo, linhas, faixas, leg)
}
