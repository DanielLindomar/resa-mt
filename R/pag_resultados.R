# =============================================================================
# R/pag_resultados.R - funções das páginas de Resultados (resultados/*.qmd)
# =============================================================================
# Carregar depois de R/funcoes.R, no primeiro chunk da página:
#
#   ```{r}
#   #| include: false
#   source(file.path(Sys.getenv("QUARTO_PROJECT_DIR", "."), "R", "funcoes.R"))
#   source(file.path(Sys.getenv("QUARTO_PROJECT_DIR", "."), "R", "pag_resultados.R"))
#   ```
#
# Lê só dados_site/resultados/, gravado por scripts/04_preparar_resultados.py.
# Os números do Manuscrito 1 (M1) vêm prontos de NUMEROS_FINAIS.csv, como texto
# pt-BR: use m1(id) e nunca recalcule. Os demais números (SEEG, proxy x PRODES,
# dinâmica) foram calculados no script 04; formate com num() de R/funcoes.R.
#
# OBJETOS
#   M1N       m1_numeros.csv: id, valor (texto pt-BR), valor_bruto, unidade, ano,
#             status_m1, arquivo_m1, tabela_m1 (tabela de TABELAS_FINAIS.md)
#   M1REP     m1_representativos.csv: tipo, posicao, id_municipio, municipio, slug, bioma
#   EMI       emissoes_grupos.csv: recorte (mt|bioma|tipo), grupo, n_mun, periodo,
#             bruta_soma, pct_do_total_municipal, bruta_mediana_municipal (MtCO2e/ano,
#             média 2010-2020), *_soma e pct_* por setor (agro, energia, mut, proc, resid),
#             remocao_soma, estab_af, area_af, t_por_estab_af, t_por_ha_af (+ _mediana)
#   EMI_TES   emissoes_testes.csv: recorte, metrica, rotulo, n, gl, H, p, epsilon2
#   EMI_RES   emissoes_resumo.csv: id (ano_ini, ano_fim, total_estadual_media,
#             total_municipios_media, nao_alocado_media), valor, unidade (MtCO2e/ano)
#   PROX_EST  proxy_prodes_estadual.csv: ano, proxy_ha, prodes_taxa_ha, razao (2010-2020)
#   PROX_RES  proxy_prodes_resumo.csv: id, valor, unidade (totais, razões, Pearson, Spearman)
#   PROX_BIO  proxy_prodes_bioma.csv: escala_bioma, bioma, periodos, n_anos, ano_ini, ano_fim,
#             n_mun, pearson, spearman, razao, proxy_total_ha, prodes_total_ha
#   DIN       dinamica_grupos.csv: recorte, grupo, n_mun, estab_2006/2017, var_estab,
#             area_2006/2017, var_area, area_media_2006/2017, var_area_media,
#             mediana_var_*, n_mun_estab_cai, n_mun_area_cai
#   DIN_TES   dinamica_testes.csv (como EMI_TES)
#   DIN_CONC  dinamica_conciliacao.csv: item, rotulo, unidade, soma_municipal,
#             tabela_estadual, tabela_confronto_ibge, diferenca, pct_diferenca
#   PRT, PRB  dados_site/prodes_mt_taxa.csv e prodes_mt_bioma.csv (série oficial)
#
# FUNÇÕES
#   m1(id)                    -> chr, valor de NUMEROS_FINAIS como está (pt-BR)
#   m1x(id)                   -> chr, "3,22x" vira "3,22 vezes"
#   m1_ic(id)                 -> num c(inf, sup), lido de um texto "[a; b]"
#   m1_re(id, padrao, k = 1)  -> chr, k-ésimo grupo da regex num valor composto
#   m1_partes(id, sep = " / ")-> chr, partes de um valor "a / b / c"
#   ic_br(id)                 -> "a a b" a partir de "[a; b]"; sci_br("4,4e-6") -> "4,4 × 10<sup>−6</sup>"
#   nf(...)                   -> p.nota-fonte com os pedaços colados (paste0)
#   fonte_m1(tabelas, ids)    -> p.nota-fonte com a tabela do M1 (os ids ficam só no código, como registro)
#   FONTE_BENEF               -> crédito da contagem de beneficiários do INCRA (só agregados)
#   fonte_ind(ids)            -> p.nota-fonte com a fonte dos indicadores do site
#   txt_p(p), fmt_r(x, d = 2) -> "p < 0,001" / "p = 0,034"; coeficiente pt-BR
#   rot_tipo(t)               -> tagList(chip do tipo com rótulo + selo "rótulo provisório")
#   cab_tipo(t)               -> HTML de cabeçalho de coluna com o tipo e o selo
#   figura_res(arquivo, legenda, nota = NULL, pasta = "figuras/")
#   tabela_perfis_m1()        -> Tabela 3 do M1 (reactable)
#   cartoes_tipos()           -> um cartão por tipo, com os traços que o definem
#   tabela_representativos()  -> 3 municípios mais próximos do centroide por tipo
#   lista_municipios_tipo()   -> <details> com os municípios de cada tipo
#   tabela_tipo_bioma()       -> contingência tipo x bioma (1:250 mil)
#   svg_regua_regra()         -> régua da regra de decisão (m oblimin e promax)
#   tabela_validacao_incra()  -> Tabela A.15 (por tipo) ; tabela_spearman_incra()
#   svg_cobertura_46504()     -> barra: 42.014 estab. da reforma agrária x categoria 46504
#   tabela_posse_municipal()  -> 141 municípios: 46504 (Censo 2017) x SIPRA (2025), com sinais
#   tabela_emissoes(recorte)  -> emissões por tipo ou bioma ; svg_composicao(recorte)
#   tabela_testes(d, recorte, metricas = NULL) -> Kruskal-Wallis
#   tabela_intensidades()     -> tCO2e por estab. e por ha da AF (leitura com cautela)
#   svg_proxy_prodes()        -> proxy x taxa PRODES, 2010-2020 ; tabela_proxy_estadual()
#   tabela_proxy_bioma()
#   svg_prodes_taxa(), svg_prodes_bioma() -> série oficial (2026 marcado como estimado)
#   tabela_dinamica(recorte)  -> estabelecimentos, área e área média 2006 x 2017
#   svg_dinamica()            -> variações por tipo e bioma (barras divergentes)
#   tabela_conciliacao()      -> soma municipal x tabelas estaduais (2006 e 2017)
#   tabela_sedes_dinamica()   -> os três municípios-sede das áreas-piloto
#   DESM, DESM_TES, DESM_RHO  -> desmatamento PRODES 2017–2025 por município, testes e Spearman (Artigo A refeito)
#   tabela_desmat(recorte)    -> desmatamento PRODES 2017–2025 por tipo ou bioma
# =============================================================================

dsr <- function(...) file.path(RAIZ, "dados_site", "resultados", ...)
ler_txt <- function(f) tibble::as_tibble(data.table::fread(f, encoding = "UTF-8", colClasses = "character", na.strings = NULL))

M1N      <- ler_txt(dsr("m1_numeros.csv"))
M1REP    <- ler(dsr("m1_representativos.csv"))
EMI      <- ler(dsr("emissoes_grupos.csv"))
EMI_TES  <- ler(dsr("emissoes_testes.csv"))
EMI_RES  <- ler(dsr("emissoes_resumo.csv"))
PROX_EST <- ler(dsr("proxy_prodes_estadual.csv"))
PROX_RES <- ler(dsr("proxy_prodes_resumo.csv"))
PROX_BIO <- ler(dsr("proxy_prodes_bioma.csv"))
DIN      <- ler(dsr("dinamica_grupos.csv"))
DIN_TES  <- ler(dsr("dinamica_testes.csv"))
DIN_CONC <- ler(dsr("dinamica_conciliacao.csv"))
PRT      <- ler(ds("prodes_mt_taxa.csv"))
PRB      <- ler(ds("prodes_mt_bioma.csv"))

GRUPOS_T3 <- c(names(TIPOS), "MT")
COR_SETOR <- c(mut = "#1F4D3A", agro = "#d4a017", energia = "#2a78d6", proc = "#8b5cf6", resid = "#9ca3af")
NOME_SETOR <- c(mut = "Mudança de uso da terra e florestas", agro = "Agropecuária", energia = "Energia",
                proc = "Processos industriais", resid = "Resíduos")

# ---- Números do M1 ------------------------------------------------------------
m1 <- function(id) {
  v <- M1N$valor[M1N$id == id]
  if (length(v) != 1) stop("id do Manuscrito 1 ausente de m1_numeros.csv: ", id)
  v
}
m1x <- function(id) sub("x$", " vezes", m1(id))
m1_ic <- function(id) {
  x <- regmatches(m1(id), regexpr("\\[[^]]+\\]", m1(id)))
  x <- gsub("[][ ]", "", gsub("−", "-", x))
  as.numeric(sub(",", ".", strsplit(x, ";")[[1]], fixed = TRUE))
}
m1_tabela <- function(id) M1N$tabela_m1[M1N$id == id]
# Parte de um valor composto de NUMEROS_FINAIS (ex.: "39,24 (8); p = 4,4e-6; ..."): k-ésimo grupo da regex
m1_re <- function(id, padrao, k = 1) {
  m <- regmatches(m1(id), regexec(padrao, m1(id)))[[1]]
  if (length(m) < k + 1) stop("padrão não achado em ", id, ": ", padrao)
  m[k + 1]
}
m1_partes <- function(id, sep = " / ") trimws(strsplit(m1(id), sep, fixed = TRUE)[[1]])
ic_br <- function(id) { x <- m1_re(id, "\\[([^]]+)\\]"); sub("; ", " a ", x, fixed = TRUE) }   # "[a; b]" -> "a a b"
sci_br <- function(s) {                                                                      # "4,4e-6" -> "4,4 × 10^−6"
  if (!grepl("e", s, fixed = TRUE)) return(s)
  p <- strsplit(s, "e", fixed = TRUE)[[1]]
  sprintf("%s × 10<sup>%s</sup>", p[1], sub("-", "−", p[2], fixed = TRUE))
}

nf <- function(...) p(class = "nota-fonte", paste0(...))   # nota de fonte: junta os pedaços sem espaço extra

# Fonte dos indicadores do site (como fonte_rodape() de R/funcoes.R, sem espaço antes da pontuação)
fonte_ind <- function(ids, prefixo = "../")
  p(class = "nota-fonte", HTML(paste0(
    "Fonte: ", esc(paste(unique(IND$fonte[IND$id %in% ids]), collapse = "; ")),
    ". Bioma dominante: IBGE, Biomas 1:250 mil (2019). Tipos municipais: Manuscrito 1 do Projeto RESA (k = 5; rótulos provisórios). ",
    "Nos agregados, o sinal ", TRACO, " (zero absoluto) é computado como zero, e os sinais X e ... são excluídos. Detalhes na página <a href=\"", prefixo, "dados/index.html\">Dados</a>.")))

# ids: os números do M1 citados no trecho (registro no código; não aparecem na página)
fonte_m1 <- function(tabelas, ids = NULL, extra = NULL)
  p(class = "nota-fonte", paste0(
    "Fonte: Manuscrito 1 do Projeto RESA (em preparação), ", tabelas, "; dados do IBGE, Censo Agropecuário 2017",
    if (!is.null(extra)) extra, ". Os números foram transcritos dos resultados finais do manuscrito, sem recálculo."))

FONTE_BENEF <- paste("INCRA, relação de beneficiários da reforma agrária em MT (Superintendência Regional SR-13;",
                     "assentados e titulados homologados até 30/09/2017), utilizada apenas em contagens agregadas por município, sem dados pessoais")

# ---- Formatação --------------------------------------------------------------------
txt_p <- function(p) ifelse(is.na(p), "—", ifelse(p < 0.001, "p < 0,001", paste("p =", num(p, 3))))
fmt_r <- function(x, d = 2) gsub("-", "−", num(x, d), fixed = TRUE)
pct_txt <- function(x, d = 1) paste0(fmt_r(x, d), "%")

rot_tipo <- function(t) chip_tipo(t, rotulo = TRUE, provisorio = TRUE)
cab_tipo <- function(t) sprintf('%s<div class="sub">%s</div>%s', as.character(chip_tipo(t, rotulo = FALSE)),
                                esc(TIPOS[[t]]), as.character(selo_provisorio()))
nome_grupo <- function(g) if (g %in% names(TIPOS)) as.character(rot_tipo(g)) else if (g == "MT") "<b>Mato Grosso</b>" else as.character(chip_bioma(g))

figura_res <- function(arquivo, legenda, nota = NULL, pasta = "figuras/")
  tags$figure(class = "figure figura-res",
              tags$a(href = paste0(pasta, arquivo), class = "lightbox",
                     tags$img(src = paste0(pasta, arquivo), alt = legenda, class = "img-fluid", loading = "lazy")),
              tags$figcaption(class = "figure-caption", legenda, if (!is.null(nota)) tags$span(class = "nota-fonte", tags$br(), nota)))

nota_rotulos_figura <- function()
  "Nota: na legenda da figura, os tipos aparecem com outra redação de rótulo, igualmente provisória. Os tipos são os mesmos (T1 a T5, com os mesmos municípios); neste site, adota-se a redação da tabela, acompanhada do selo “rótulo provisório”."

# ---- Tipologia: Tabela 3 -----------------------------------------------------------
tabela_perfis_m1 <- function() {
  par <- function(a, b) function(g) sprintf("%s (%s)", m1(sprintf(a, g)), m1(sprintf(b, g)))
  um  <- function(a) function(g) m1(sprintf(a, g))
  linhas <- list(
    list("Municípios", "número", um("T3_%s_N")),
    list("F1 · Lavoura temporária mecanizada", "escore: média truncada em ±3 (mediana)", par("T3_%s_F1_MEDIA_WINSOR", "T3_%s_F1_MEDIANA")),
    list("F2 · Porte agregado", "escore: média truncada em ±3 (mediana)", par("T3_%s_F2_MEDIA_WINSOR", "T3_%s_F2_MEDIANA")),
    list("F3 · Horticultura e irrigação", "escore: média truncada em ±3 (mediana)", par("T3_%s_F3_MEDIA_WINSOR", "T3_%s_F3_MEDIANA")),
    list("F4 · Lavoura permanente", "escore: média truncada em ±3 (mediana)", par("T3_%s_F4_MEDIA_WINSOR", "T3_%s_F4_MEDIANA")),
    list("F5 · Posse aguardando titulação (46504)", "escore: média truncada em ±3 (mediana)", par("T3_%s_F5_MEDIA_WINSOR", "T3_%s_F5_MEDIANA")),
    list("Estab. da AF na categoria 46504", "% ponderado pelos estabelecimentos", um("T3_%s_PCT_ESTAB_46504_PONDERADA")),
    list("Estab. da AF na categoria 46504", "% média municipal (mediana)", par("T3_%s_PCT_ESTAB_46504_MEDIA_MUNICIPAL_TODOS", "T3_%s_PCT_ESTAB_46504_MEDIANA_MUNICIPAL")),
    list("Municípios com estab. na categoria 46504", "número (46504 > 0)", um("T3_%s_N_MUNIS_COM_ESTAB_46504")),
    list("Área da AF na categoria 46504", "% ponderado, apenas municípios sem X", um("T3_%s_PCT_AREA_46504_PONDERADA_SEM_SIGILO")),
    list("Municípios com X na área 46504", "número", um("T3_%s_N_MUNIS_SIGILO_AREA_46504")),
    list("Área média da AF", "ha por estab.: ponderada (mediana municipal)", par("T3_%s_AREA_MEDIA_AF_HA_POR_ESTAB_PONDERADA", "T3_%s_AREA_MEDIA_AF_HA_POR_ESTAB_MEDIANA_MUNICIPAL")),
    list("Estab. da AF por município", "média (mediana)", par("T3_%s_ESTAB_AF_POR_MUNICIPIO_MEDIA", "T3_%s_ESTAB_AF_POR_MUNICIPIO_MEDIANA")),
    list("Estab. da AF", "soma dos municípios", um("T3_%s_SOMA_ESTAB_AF")),
    list("Bioma dominante", "municípios: Amazônia / Cerrado / Pantanal (IBGE 1:250 mil)",
         function(g) paste(m1(sprintf("T3_%s_BIOMA250_AMAZONIA", g)), m1(sprintf("T3_%s_BIOMA250_CERRADO", g)),
                           m1(sprintf("T3_%s_BIOMA250_PANTANAL", g)), sep = " / ")),
    list("Beneficiários do INCRA por 100 estab. da AF", "assentados e titulados homologados até 30/09/2017", um("INCRA_%s_REF_POR100AF_PONDERADO")),
    list("Estabilidade do tipo nas reamostras (Jaccard)", "duas formas de cálculo: repetições / clusterboot",
         function(g) if (g == "MT") "—" else paste(m1(sprintf("T3_%s_JACCARD_BOOTSTRAP_REPETICOES", g)),
                                                    m1(sprintf("T3_%s_JACCARD_BOOTSTRAP_CLUSTERBOOT_PADRAO", g)), sep = " / ")))
  d <- bind_rows(lapply(linhas, function(l) {
    vals <- vapply(GRUPOS_T3, l[[3]], character(1))
    c(list(Indicador = sprintf('%s<div class="sub">%s</div>', esc(l[[1]]), esc(l[[2]]))), as.list(setNames(vals, GRUPOS_T3)))
  }))
  cols <- c(list(Indicador = colDef(html = TRUE, minWidth = 185, sticky = "left")),
            setNames(lapply(names(TIPOS), function(t) colDef(html = TRUE, header = HTML(cab_tipo(t)), align = "right", minWidth = 100)), names(TIPOS)),
            list(MT = colDef(name = "Mato Grosso", align = "right", minWidth = 85, style = list(fontWeight = 600))))
  reactable(d, compact = TRUE, sortable = FALSE, pagination = FALSE, wrap = TRUE, striped = TRUE, columns = cols, class = "tabela-res")
}

cartoes_tipos <- function() {
  # As frases comparativas abaixo ("o menor", "o maior") são conferidas contra os números
  vt <- function(campo) setNames(as.numeric(M1N$valor_bruto[match(sprintf("T3_%s_%s", names(TIPOS), campo), M1N$id)]), names(TIPOS))
  stopifnot(names(which.min(vt("F2_MEDIA_WINSOR"))) == "T1", names(which.max(vt("F5_MEDIA_WINSOR"))) == "T2",
            names(which.max(vt("F2_MEDIA_WINSOR"))) == "T3", names(which.max(vt("F1_MEDIA_WINSOR"))) == "T4",
            names(which.max(vt("F3_MEDIA_WINSOR"))) == "T5", names(which.min(vt("AREA_MEDIA_AF_HA_POR_ESTAB_PONDERADA"))) == "T5",
            all(as.numeric(M1N$valor_bruto[match(sprintf("T3_T1_F%d_MEDIANA", 1:5), M1N$id)]) < 0),
            all(as.numeric(M1N$valor_bruto[match(sprintf("T3_T2_F%d_MEDIA_WINSOR", 1:4), M1N$id)]) < 0))
  sedes <- function(t) { s <- SEDES[SEDES$tipo_m1 == t, ]
    if (nrow(s)) p(class = "sub", paste0("Sede de área-piloto neste tipo: ", paste(s$municipio, collapse = ", "), ".")) }
  txt <- list(
    T1 = c(sprintf("Reúne %s municípios. Todos os escores medianos são negativos, e o porte agregado (F2) é o menor entre os cinco tipos (%s).", m1("T3_T1_N"), m1("T3_T1_F2_MEDIA_WINSOR")),
           sprintf("%s%% dos estabelecimentos da AF estão na categoria 46504 (total de MT: %s%%).", m1("T3_T1_PCT_ESTAB_46504_PONDERADA"), m1("T3_MT_PCT_ESTAB_46504_PONDERADA")),
           sprintf("O rótulo “Baixo porte agregado” refere-se ao total do município, e não ao tamanho do estabelecimento: a área média da AF é de %s ha (média de MT: %s ha).", m1("T3_T1_AREA_MEDIA_AF_HA_POR_ESTAB_PONDERADA"), m1("T3_MT_AREA_MEDIA_AF_HA_POR_ESTAB_PONDERADA"))),
    T2 = c(sprintf("Reúne %s municípios e apresenta o maior escore de posse aguardando titulação (F5 = %s), com F1 a F4 negativos.", m1("T3_T2_N"), m1("T3_T2_F5_MEDIA_WINSOR")),
           sprintf("%s%% dos estabelecimentos da AF estão na categoria 46504, proporção que corresponde a %s a média de MT.", m1("T3_T2_PCT_ESTAB_46504_PONDERADA"), m1x("RAZAO_T2_46504_VS_MT")),
           sprintf("Nenhum município do tipo apresenta X na área da categoria 46504 (%s de %s).", m1("T3_T2_N_MUNIS_SIGILO_AREA_46504"), m1("T3_T2_N"))),
    T3 = c(sprintf("Reúne %s municípios, %s dos quais na Amazônia, e apresenta o maior porte agregado (F2 = %s).", m1("T3_T3_N"), m1("T3_T3_BIOMA250_AMAZONIA"), m1("T3_T3_F2_MEDIA_WINSOR")),
           sprintf("Apenas %s%% dos estabelecimentos da AF estão na categoria 46504; contudo, registram-se %s beneficiários do INCRA por 100 estabelecimentos da AF (total de MT: %s).",
                   m1("T3_T3_PCT_ESTAB_46504_PONDERADA"), m1("INCRA_T3_REF_POR100AF_PONDERADO"), m1("INCRA_MT_REF_POR100AF_PONDERADO")),
           "A posse “baixa” refere-se à condição declarada ao Censo, conforme se discute na página sobre a posse."),
    T4 = c(sprintf("Reúne %s municípios (%s na Amazônia e %s no Cerrado) e apresenta o maior escore de lavoura temporária mecanizada (F1 = %s).", m1("T3_T4_N"),
                   m1("T3_T4_BIOMA250_AMAZONIA"), m1("T3_T4_BIOMA250_CERRADO"), m1("T3_T4_F1_MEDIA_WINSOR")),
           sprintf("%s%% dos estabelecimentos da AF estão na categoria 46504, proporção que corresponde a %s a média de MT.", m1("T3_T4_PCT_ESTAB_46504_PONDERADA"), m1x("RAZAO_T4_46504_VS_MT")),
           sprintf("Essa proporção depende de Itanhangá: sem esse município, ela cai para %s%% (%s a média).",
                   trimws(strsplit(m1("PREV_SEM_ITANHANGA_T4"), "/")[[1]][2]), m1x("RAZAO_T4_46504_VS_MT_SEM_ITANHANGA"))),
    T5 = c(sprintf("Reúne %s municípios e apresenta o maior escore de horticultura e irrigação (F3 = %s), além de porte agregado elevado (F2 = %s).", m1("T3_T5_N"),
                   m1("T3_T5_F3_MEDIA_WINSOR"), m1("T3_T5_F2_MEDIA_WINSOR")),
           sprintf("Apresenta a menor área média da AF, de %s ha por estabelecimento, e %s%% dos estabelecimentos da AF na categoria 46504.",
                   m1("T3_T5_AREA_MEDIA_AF_HA_POR_ESTAB_PONDERADA"), m1("T3_T5_PCT_ESTAB_46504_PONDERADA")),
           sprintf("O F4 do tipo depende de Colniza: sem esse município, a média bruta cai para %s.", m1("OUT_T5_F4_SEM_COLNIZA"))))
  div(class = "cartoes cartoes-tipos", lapply(names(TIPOS), function(t)
    div(class = paste("cartao cartao-tipo", paste0("borda-", tolower(t))),
        div(class = "cartao-topo", rot_tipo(t)),
        tags$ul(lapply(txt[[t]], tags$li)), sedes(t))))
}

link_mun <- function(nome, slug, prefixo = "../municipios/")
  if (tem_perfil(slug)) sprintf('<a href="%s">%s</a>', url_mun(slug, prefixo), esc(nome)) else esc(nome)

tabela_representativos <- function() {
  d <- bind_rows(lapply(names(TIPOS), function(t) {
    r <- M1REP[M1REP$tipo == t, ]; r <- r[order(r$posicao), ]
    tibble(Tipo = as.character(rot_tipo(t)),
           `1º` = link_mun(r$municipio[1], r$slug[1]), `2º` = link_mun(r$municipio[2], r$slug[2]),
           `3º` = link_mun(r$municipio[3], r$slug[3]))
  }))
  reactable(d, compact = TRUE, sortable = FALSE, pagination = FALSE, wrap = TRUE,
            columns = list(Tipo = colDef(html = TRUE, minWidth = 260), `1º` = colDef(html = TRUE),
                           `2º` = colDef(html = TRUE), `3º` = colDef(html = TRUE)))
}

lista_municipios_tipo <- function(prefixo = "../municipios/") {
  tagList(lapply(names(TIPOS), function(t) {
    m <- ordenar_pt(MUN[MUN$tipo_m1 == t, ])
    nomes <- vapply(seq_len(nrow(m)), function(i) {
      x <- link_mun(m$municipio[i], m$slug[i], prefixo)
      if (isTRUE(m$sede_piloto[i])) sprintf("<b>%s</b> (sede de área-piloto)", x) else x }, character(1))
    tags$details(class = "lista-tipo",
                 tags$summary(rot_tipo(t), sprintf(" %d municípios", nrow(m))),
                 p(HTML(paste(nomes, collapse = "; ")), "."))
  }))
}

tabela_tipo_bioma <- function() {
  d <- bind_rows(lapply(GRUPOS_T3, function(g) {
    a <- m1(sprintf("T3_%s_BIOMA250_AMAZONIA", g)); c_ <- m1(sprintf("T3_%s_BIOMA250_CERRADO", g)); pn <- m1(sprintf("T3_%s_BIOMA250_PANTANAL", g))
    tibble(Tipo = nome_grupo(g), `Amazônia` = a, Cerrado = c_, Pantanal = pn, Total = m1(sprintf("T3_%s_N", g)))
  }))
  reactable(d, compact = TRUE, sortable = FALSE, pagination = FALSE, wrap = TRUE,
            columns = list(Tipo = colDef(html = TRUE, minWidth = 260),
                           `Amazônia` = colDef(html = TRUE, header = HTML(as.character(chip_bioma("Amazônia"))), align = "right"),
                           Cerrado = colDef(html = TRUE, header = HTML(as.character(chip_bioma("Cerrado"))), align = "right"),
                           Pantanal = colDef(html = TRUE, header = HTML(as.character(chip_bioma("Pantanal"))), align = "right"),
                           Total = colDef(align = "right", style = list(fontWeight = 600))))
}

# Régua da regra de decisão: faixas 0-0,20 / 0,20-0,35 / >= 0,35 e os pontos com IC
svg_regua_regra <- function() {
  w <- 680; h <- 150; pl <- 150; pr <- 20
  sx <- function(v) pl + v / 0.5 * (w - pl - pr)
  faixa <- function(a, b, cor, rot) sprintf('<rect x="%.1f" y="18" width="%.1f" height="104" fill="%s"/><text x="%.1f" y="12" text-anchor="middle" font-size="11" fill="#374151">%s</text>',
                                            sx(a), sx(b) - sx(a), cor, (sx(a) + sx(b)) / 2, rot)
  linha <- function(y, m, ic, cor, rot, cheio = TRUE)
    sprintf('<text x="%d" y="%.1f" text-anchor="end" font-size="12" fill="#1f2937">%s</text><line x1="%.1f" x2="%.1f" y1="%.1f" y2="%.1f" stroke="%s" stroke-width="2.4"/><circle cx="%.1f" cy="%.1f" r="6" fill="%s" stroke="%s" stroke-width="2" data-tip="%s: m = %s; IC 95%% %s a %s"/><text x="%.1f" y="%.1f" font-size="11" fill="#1f2937" font-weight="700">%s</text>',
            pl - 10, y + 4, rot, sx(ic[1]), sx(ic[2]), y, y, cor, sx(m), y, if (cheio) cor else "#fff", cor, esc(rot),
            fmt_r(m, 3), fmt_r(ic[1], 3), fmt_r(ic[2], 3), sx(m) - 12, y - 10, fmt_r(m, 3))
  eixo <- paste(sprintf('<line x1="%.1f" x2="%.1f" y1="122" y2="127" stroke="#6b7280"/><text x="%.1f" y="140" text-anchor="middle" font-size="11" fill="#6b7280">%s</text>',
                        sx(seq(0, 0.5, 0.1)), sx(seq(0, 0.5, 0.1)), sx(seq(0, 0.5, 0.1)), fmt_r(seq(0, 0.5, 0.1), 1)), collapse = "")
  svg <- sprintf('<svg viewBox="0 0 %d %d" width="100%%" role="img" aria-label="Regra de decisão: maior correlação da posse com escala ou mecanização">%s%s%s<line x1="%.1f" x2="%.1f" y1="122" y2="122" stroke="#6b7280"/>%s%s%s</svg>',
                 w, h, faixa(0, 0.20, "#eef6f1", "independência"), faixa(0.20, 0.35, "#fff4d6", "independência parcial"),
                 faixa(0.35, 0.5, "#fde4e1", "reformulação"), sx(0), sx(0.5), eixo,
                 linha(55, as.numeric(M1N$valor_bruto[M1N$id == "REGRA_M"]), m1_ic("REGRA_M_IC_BOOT_IID"), "#1F4D3A", "Oblimin (principal)"),
                 linha(95, as.numeric(M1N$valor_bruto[M1N$id == "REGRA_M_PROMAX"]), m1_ic("REGRA_M_IC_BOOT_IID_PROMAX"), "#6b7280", "Promax (sensibilidade)", FALSE))
  tagList(HTML(sprintf('<figure class="grafico-svg">%s<figcaption class="legenda-svg">Fonte: Elaboração própria com base no M1 do Projeto RESA (Tabelas A.2 e A.3). Nota: m corresponde ao maior valor absoluto entre Φ posse × escala e Φ posse × mecanização. Ponto: estimativa; linha: IC 95%% por <i>bootstrap</i> (2.000 reamostras de municípios).</figcaption></figure>', svg)))
}

# ---- Posse: validação com o INCRA ----------------------------------------------------
tabela_validacao_incra <- function() {
  L <- list(c("PCT_REF_DO_MT", "% dos beneficiários do INCRA de MT", "%"),
            c("REF_POR100AF_PONDERADO", "Beneficiários do INCRA por 100 estab. da AF", "por 100"),
            c("COBERTURA_46504AF_SOBRE_REF", "Cobertura: estab. da AF em 46504 ÷ beneficiários", "razão"),
            c("COBERTURA_46504AF_MAIS_PROPRA_SOBRE_REF", "Cobertura: (46504 + proprietários titulados pela reforma agrária) ÷ beneficiários", "razão"),
            c("PCT_ALT_S4_AF_PONDERADO", "Medida combinada: 46504 + proprietários titulados pela reforma agrária", "% dos estab. da AF"),
            c("PCT_TITULADO_BENEF_SIPRA", "Beneficiários já titulados no SIPRA", "%"),
            c("ANO_CRIACAO_MEDIO_POND_FAMILIAS", "Ano médio de criação dos projetos", "ponderado por famílias"),
            c("PCT_FAMILIAS_PROJETOS_ATE1995", "Famílias em projetos criados até 1995", "%"),
            c("PCT_FAMILIAS_COLONIZACAO_ANTIGA", "Famílias em projetos de colonização antigos", "%"),
            c("PCT_FAMILIAS_PE_ESTADUAL", "Famílias em projetos estaduais", "%"))
  d <- bind_rows(lapply(L, function(l) c(list(Indicador = sprintf('%s<div class="sub">%s</div>', esc(l[2]), esc(l[3]))),
                                        as.list(setNames(vapply(GRUPOS_T3, function(g) m1(sprintf("INCRA_%s_%s", g, l[1])), character(1)), GRUPOS_T3)))))
  cols <- c(list(Indicador = colDef(html = TRUE, minWidth = 250, sticky = "left")),
            setNames(lapply(names(TIPOS), function(t) colDef(html = TRUE, header = HTML(cab_tipo(t)), align = "right", minWidth = 115)), names(TIPOS)),
            list(MT = colDef(name = "Mato Grosso", align = "right", minWidth = 95, style = list(fontWeight = 600))))
  reactable(d, compact = TRUE, sortable = FALSE, pagination = FALSE, wrap = TRUE, striped = TRUE, columns = cols, class = "tabela-res")
}

tabela_spearman_incra <- function() {
  sub <- c("141" = "Todos os municípios (141)", REFGT0 = "Com algum beneficiário (132)", REFGE100 = "Com 100 beneficiários ou mais (99)")
  d <- bind_rows(lapply(names(sub), function(s) tibble(
    `Municípios` = sub[[s]],
    `% da AF em 46504` = m1(sprintf("INCRA_RHO_PCT_ESTAB_%s", s)),
    `Escore F5 (posse)` = m1(sprintf("INCRA_RHO_F5_%s", s)),
    `Medida combinada` = m1(sprintf("INCRA_RHO_S4_%s", s)))))
  reactable(d, compact = TRUE, sortable = FALSE, pagination = FALSE, wrap = TRUE,
            columns = list(`Municípios` = colDef(minWidth = 190)))
}

svg_cobertura_46504 <- function() {
  tot <- as.numeric(M1N$valor_bruto[M1N$id == "MARQUES2021_ESTAB_RA_MT"])
  dentro <- as.numeric(M1N$valor_bruto[M1N$id == "TOT_TODOS_46504_ESTAB"])
  w <- 680; h <- 92; x0 <- 10; L <- w - 20; xd <- x0 + L * dentro / tot
  svg <- sprintf(paste0('<svg viewBox="0 0 %d %d" width="100%%" role="img" aria-label="Estabelecimentos da reforma agrária e categoria 46504">',
                        '<rect x="%d" y="26" width="%.1f" height="34" fill="#4a3aa7" data-tip="No máximo %s estabelecimentos (%s%%) na categoria 46504"/>',
                        '<rect x="%.1f" y="26" width="%.1f" height="34" fill="#d9d6ee" data-tip="Pelo menos %s estabelecimentos (%s%%) fora da categoria 46504"/>',
                        '<text x="%d" y="18" font-size="12" fill="#1f2937">No máximo %s (%s%%) na categoria 46504</text>',
                        '<text x="%d" y="18" font-size="12" fill="#1f2937" text-anchor="end">pelo menos %s (%s%%) fora dela</text>',
                        '<text x="%d" y="80" font-size="11" fill="#6b7280">%s estabelecimentos da reforma agrária identificados no Censo 2017 pelo IBGE com o INCRA (MARQUES, 2021)</text></svg>'),
                 w, h, x0, xd - x0, m1("TOT_TODOS_46504_ESTAB"), m1("COBERTURA_MAX_46504_MARQUES"),
                 xd, x0 + L - xd, m1("INCRA_LIM_INF_RA_FORA_46504"), m1("INCRA_LIM_INF_RA_FORA_46504_PCT"),
                 x0, m1("TOT_TODOS_46504_ESTAB"), m1("COBERTURA_MAX_46504_MARQUES"),
                 w - 10, m1("INCRA_LIM_INF_RA_FORA_46504"), m1("INCRA_LIM_INF_RA_FORA_46504_PCT"), x0, m1("MARQUES2021_ESTAB_RA_MT"))
  HTML(sprintf('<figure class="grafico-svg">%s</figure>', svg))
}

tabela_posse_municipal <- function(prefixo = "../municipios/") {
  ids <- c(e = "estab_af_46504", p = "pct_estab_46504", a = "pct_area_46504", n = "n_pa", f = "fam_pa")
  U <- ULT$ultimos[ULT$ultimos$indicador %in% ids, c("id_municipio", "indicador", "valor", "sinal", "valor_calc")]
  d <- MUN[, c("id_municipio", "municipio", "slug", "bioma", "tipo_m1", "sede_piloto")]
  for (k in names(ids)) {
    u <- U[U$indicador == ids[[k]], ]; r <- info_ind(ids[[k]])
    j <- match(d$id_municipio, u$id_municipio)
    d[[paste0(k, "_v")]] <- u$valor_calc[j]
    d[[paste0(k, "_h")]] <- html_celula(u$valor[j], u$sinal[j], r$fmt)
  }
  d <- d[order(-d$p_v, d$municipio), ]
  d$Município <- vapply(seq_len(nrow(d)), function(i) {
    x <- link_mun(d$municipio[i], d$slug[i], prefixo)
    if (isTRUE(d$sede_piloto[i])) sprintf('<b>%s</b><div class="sub">sede de área-piloto</div>', x) else x }, character(1))
  vis <- d[, c("Município", "bioma", "tipo_m1", "e_v", "p_v", "a_v", "n_v", "f_v")]
  num_col <- function(nome, k, sub) colDef(html = TRUE, header = HTML(sprintf('%s<div class="sub">%s</div>', nome, sub)), align = "right",
                                           sortNALast = TRUE, minWidth = 105, cell = function(v, i) d[[paste0(k, "_h")]][i])
  reactable(vis, searchable = TRUE, compact = TRUE, striped = TRUE, defaultPageSize = 15, showPageSizeOptions = TRUE,
            pageSizeOptions = c(15, 50, 141), wrap = TRUE, class = "tabela-res",
            language = reactableLang(searchPlaceholder = "Buscar município", noData = "Nenhum município",
                                     pageInfo = "{rowStart}–{rowEnd} de {rows} municípios", pagePrevious = "anterior", pageNext = "próxima",
                                     pageSizeOptions = "Mostrar {rows}"),
            columns = list(
              Município = colDef(html = TRUE, minWidth = 170),
              bioma = colDef(name = "Bioma", minWidth = 85),
              tipo_m1 = colDef(name = "Tipo (M1)", align = "center", minWidth = 70),
              e_v = num_col("Estab. da AF em 46504", "e", "Censo 2017"),
              p_v = num_col("% da AF em 46504", "p", "dos estab., Censo 2017"),
              a_v = num_col("% da área da AF em 46504", "a", "Censo 2017"),
              n_v = num_col("Projetos de assentamento", "n", "SIPRA, 2025"),
              f_v = num_col("Famílias assentadas", "f", "SIPRA, 2025")))
}

# ---- Emissões --------------------------------------------------------------------------
grupos_rec <- function(recorte) if (recorte == "tipo") c(names(TIPOS), "MT") else c(BIOMAS, "MT")
linha_emi <- function(g) EMI[EMI$grupo == g, ]

tabela_emissoes <- function(recorte = c("tipo", "bioma")) {
  recorte <- match.arg(recorte)
  d <- bind_rows(lapply(grupos_rec(recorte), function(g) { x <- linha_emi(g)
    a24 <- agregado("seeg_emissao_bruta", g, 2024)$valor / 1000
    tibble(Grupo = nome_grupo(g), `Municípios` = as.character(x$n_mun),
           Soma = num(x$bruta_soma, 1), Pct = pct_txt(x$pct_do_total_municipal, 1),
           Mediana = num(x$bruta_mediana_municipal, 2), A2024 = num(a24, 1)) }))
  reactable(d, compact = TRUE, sortable = FALSE, pagination = FALSE, wrap = TRUE, class = "tabela-res",
            columns = list(Grupo = colDef(name = if (recorte == "tipo") "Tipo do M1" else "Bioma (IBGE 1:250 mil)", html = TRUE, minWidth = 250),
                           `Municípios` = colDef(align = "right", minWidth = 80),
                           Soma = colDef(html = TRUE, header = HTML('Emissões brutas<div class="sub">MtCO2e/ano, média 2010–2020</div>'), align = "right"),
                           Pct = colDef(html = TRUE, header = HTML('Participação<div class="sub">% da soma dos 141 municípios</div>'), align = "right"),
                           Mediana = colDef(html = TRUE, header = HTML('Mediana municipal<div class="sub">MtCO2e/ano, 2010–2020</div>'), align = "right"),
                           A2024 = colDef(html = TRUE, header = HTML('Emissões brutas<div class="sub">MtCO2e, 2024</div>'), align = "right")))
}

svg_composicao <- function(recorte = c("tipo", "bioma")) {
  recorte <- match.arg(recorte)
  gs <- grupos_rec(recorte); set <- names(COR_SETOR)
  w <- 680; lh <- 30; pl <- 110; pr <- 10; h <- length(gs) * lh + 10
  sx <- function(v) pl + v / 100 * (w - pl - pr)
  rot <- function(g) if (g %in% names(TIPOS)) paste0(g, " · ", TIPOS[[g]], " (rótulo provisório)") else if (g == "MT") "Mato Grosso" else g
  curto <- function(g) if (g == "MT") "Mato Grosso" else g
  partes <- vapply(seq_along(gs), function(i) {
    x <- linha_emi(gs[i]); y <- (i - 1) * lh + 5; acc <- 0
    seg <- vapply(set, function(s) { v <- x[[paste0("pct_", s)]]
      out <- sprintf('<rect x="%.1f" y="%d" width="%.1f" height="%d" fill="%s" data-tip="%s · %s: %s%%"/>', sx(acc), y, sx(acc + v) - sx(acc), lh - 10,
                     COR_SETOR[[s]], esc(rot(gs[i])), NOME_SETOR[[s]], fmt_r(v, 1))
      if (v >= 7) out <- paste0(out, sprintf('<text x="%.1f" y="%d" font-size="11" fill="%s" text-anchor="middle">%s%%</text>', (sx(acc) + sx(acc + v)) / 2,
                                              y + 15, if (s %in% c("mut", "energia", "proc")) "#fff" else "#1f2937", num(v, 0)))
      acc <<- acc + v; out }, character(1))
    sprintf('<text x="%d" y="%d" font-size="12" text-anchor="end" fill="#1f2937"%s>%s</text>%s', pl - 8, y + 15,
            if (gs[i] == "MT") ' font-weight="700"' else "", esc(curto(gs[i])), paste(seg, collapse = ""))
  }, character(1))
  leg <- paste(vapply(set, function(s) sprintf('<span class="leg-item"><svg width="12" height="12"><rect width="12" height="12" fill="%s"/></svg>%s</span>',
                                               COR_SETOR[[s]], NOME_SETOR[[s]]), character(1)), collapse = "")
  nota <- if (recorte == "tipo") '<span class="leg-item">T1 a T5: tipos do Manuscrito 1 (rótulos provisórios na tabela acima).</span>' else ""
  HTML(sprintf('<figure class="grafico-svg"><svg viewBox="0 0 %d %d" width="100%%" role="img" aria-label="Composição setorial das emissões brutas por %s">%s</svg><figcaption class="legenda-svg">%s%s</figcaption></figure>',
               w, h, recorte, paste(partes, collapse = ""), leg, nota))
}

tabela_testes <- function(d, recorte, metricas = NULL) {
  x <- d[d$recorte == recorte, ]
  if (!is.null(metricas)) x <- x[x$metrica %in% metricas, ]
  t <- tibble(Medida = x$rotulo, H = num(x$H, 2), gl = as.character(x$gl), p = txt_p(as.numeric(x$p)), Efeito = fmt_r(x$epsilon2, 3))
  reactable(t, compact = TRUE, sortable = FALSE, pagination = FALSE, wrap = TRUE,
            columns = list(Medida = colDef(minWidth = 260), H = colDef(name = "H de Kruskal-Wallis", align = "right"),
                           gl = colDef(name = "graus de liberdade", align = "right"), p = colDef(align = "right"),
                           Efeito = colDef(html = TRUE, header = HTML("Tamanho de efeito<div class=\"sub\">ε² = H ÷ (n − 1)</div>"), align = "right")))
}

tabela_intensidades <- function() {
  d <- bind_rows(lapply(grupos_rec("tipo"), function(g) { x <- linha_emi(g)
    tibble(Grupo = nome_grupo(g), E1 = num(x$t_por_estab_af, 0), E2 = num(x$t_por_estab_af_mediana, 0),
           H1 = num(x$t_por_ha_af, 1), H2 = num(x$t_por_ha_af_mediana, 1)) }))
  reactable(d, compact = TRUE, sortable = FALSE, pagination = FALSE, wrap = TRUE, class = "tabela-res",
            columns = list(Grupo = colDef(name = "Tipo do M1", html = TRUE, minWidth = 250),
                           E1 = colDef(html = TRUE, header = HTML('tCO2e por estab. da AF<div class="sub">razão das somas</div>'), align = "right"),
                           E2 = colDef(html = TRUE, header = HTML('tCO2e por estab. da AF<div class="sub">mediana municipal</div>'), align = "right"),
                           H1 = colDef(html = TRUE, header = HTML('tCO2e por ha da AF<div class="sub">razão das somas</div>'), align = "right"),
                           H2 = colDef(html = TRUE, header = HTML('tCO2e por ha da AF<div class="sub">mediana municipal</div>'), align = "right")))
}

# ---- Proxy de desmatamento x PRODES ----------------------------------------------------
pres <- function(id) PROX_RES$valor[PROX_RES$id == id]

svg_proxy_prodes <- function() {
  HTML(svg_linhas(list(
    list(nome = "Proxy dos Artigos A e B (SEEG, mudança de uso da terra ÷ 150 tCO2e/ha)", cor = "#b42318", larg = 2.6, dash = "",
         x = PROX_EST$ano, y = PROX_EST$proxy_ha / 100),
    list(nome = "PRODES: taxa oficial de MT (Amazônia Legal)", cor = "#1F4D3A", larg = 2.6, dash = "",
         x = PROX_EST$ano, y = PROX_EST$prodes_taxa_ha / 100)),
    fmt = "int", titulo = "Proxy de desmatamento e PRODES em MT, km² por ano, 2010–2020", h = 250))
}

tabela_proxy_estadual <- function() {
  d <- tibble(Ano = as.character(PROX_EST$ano), Proxy = num(PROX_EST$proxy_ha, 0), PRODES = num(PROX_EST$prodes_taxa_ha, 0),
              Razao = num(PROX_EST$razao, 2))
  d <- bind_rows(d, tibble(Ano = "2010–2020", Proxy = num(pres("proxy_total_ha"), 0), PRODES = num(pres("prodes_total_ha"), 0),
                           Razao = num(pres("razao_total"), 2)))
  reactable(d, compact = TRUE, sortable = FALSE, pagination = FALSE,
            rowStyle = function(i) if (i == nrow(d)) list(fontWeight = 700, borderTop = "2px solid #d1d5db"),
            columns = list(Ano = colDef(minWidth = 80),
                           Proxy = colDef(html = TRUE, header = HTML('Proxy dos Artigos A e B<div class="sub">ha</div>'), align = "right"),
                           PRODES = colDef(html = TRUE, header = HTML('PRODES, taxa de MT<div class="sub">ha</div>'), align = "right"),
                           Razao = colDef(html = TRUE, header = HTML('Razão<div class="sub">proxy ÷ PRODES</div>'), align = "right")))
}

tabela_proxy_bioma <- function() {
  x <- PROX_BIO[PROX_BIO$escala_bioma == "IBGE 1:250 mil (2019)", ]
  d <- tibble(Bioma = vapply(x$bioma, function(b) as.character(chip_bioma(b)), character(1)),
              `Municípios` = as.character(x$n_mun), Anos = sprintf("%d–%d (%d)", x$ano_ini, x$ano_fim, x$n_anos),
              Pearson = fmt_r(x$pearson, 2), Spearman = fmt_r(x$spearman, 2), Razao = num(x$razao, 1))
  reactable(d, compact = TRUE, sortable = FALSE, pagination = FALSE, wrap = TRUE,
            columns = list(Bioma = colDef(html = TRUE, minWidth = 110), `Municípios` = colDef(align = "right"),
                           Anos = colDef(name = "Anos com período anual", minWidth = 130),
                           Pearson = colDef(align = "right"), Spearman = colDef(align = "right"),
                           Razao = colDef(html = TRUE, header = HTML('Razão<div class="sub">proxy ÷ incremento PRODES</div>'), align = "right")))
}

# ---- Série oficial do PRODES -----------------------------------------------------------
# Gráfico de linhas com pontos cheios (período anual) ou vazados (período plurianual,
# mostrado como média anual) e pontos soltos, sem linha (estimativa ou dado parcial).
svg_pontos <- function(series, titulo, w = 680, h = 280, unidade = "km²") {
  ys <- unlist(lapply(series, `[[`, "y")); xs <- unlist(lapply(series, `[[`, "x"))
  pl <- 56; pr <- 14; pt <- 12; pb <- 26
  xr <- range(xs); yt <- pretty(c(0, ys), n = 5); yr <- range(yt)
  sx <- function(x) pl + (x - xr[1]) / diff(xr) * (w - pl - pr)
  sy <- function(y) h - pb - (y - yr[1]) / diff(yr) * (h - pt - pb)
  grade <- paste(sprintf('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#eef0f4"/><text x="%d" y="%.1f" text-anchor="end" font-size="11" fill="#6b7280">%s</text>',
                         pl, w - pr, sy(yt), sy(yt), pl - 6, sy(yt) + 4, num(yt, 0)), collapse = "")
  xt <- pretty(xr, n = 8); xt <- xt[xt >= xr[1] & xt <= xr[2]]
  eixo <- paste(sprintf('<text x="%.1f" y="%d" text-anchor="middle" font-size="11" fill="#6b7280">%d</text>', sx(xt), h - 8, as.integer(xt)), collapse = "")
  corpo <- vapply(series, function(s) {
    o <- order(s$x); x <- s$x[o]; y <- s$y[o]; oco <- s$oco[o]; tip <- s$tip[o]; liga <- s$liga[o]
    xl <- x[liga]; yl <- y[liga]
    path <- if (length(xl) >= 2) sprintf('<path d="%s" fill="none" stroke="%s" stroke-width="%s"/>',
                                         paste0(c("M", rep("L", length(xl) - 1)), sprintf("%.1f %.1f", sx(xl), sy(yl)), collapse = " "), s$cor, s$larg) else ""
    pts <- paste(sprintf('<circle cx="%.1f" cy="%.1f" r="%s" fill="%s" stroke="%s" stroke-width="1.6" data-tip="%s"/>', sx(x), sy(y),
                         ifelse(oco, "3.6", "2.8"), ifelse(oco, "#fff", s$cor), s$cor, esc(tip)), collapse = "")
    paste0(path, pts)
  }, character(1))
  sprintf('<svg viewBox="0 0 %d %d" width="100%%" role="img" aria-label="%s">%s%s%s</svg>', w, h, esc(titulo), grade, eixo, paste(corpo, collapse = ""))
}

svg_prodes_taxa <- function() {
  t <- PRT[order(PRT$ano), ]; est <- t$status != "consolidada"
  s <- list(nome = "Taxa", cor = "#1F4D3A", larg = 2.2, x = t$ano, y = t$taxa_km2, oco = est, liga = !est,
            tip = sprintf("%d: %s km²%s", t$ano, num(t$taxa_km2, 0), ifelse(est, " (taxa estimada; excluída dos cálculos)", "")))
  svg <- svg_pontos(list(s), "Taxa anual de desmatamento do PRODES em Mato Grosso, km²")
  HTML(sprintf('<figure class="grafico-svg">%s<figcaption class="legenda-svg"><span class="leg-item"><svg width="22" height="10"><line x1="0" x2="22" y1="5" y2="5" stroke="#1F4D3A" stroke-width="2.2"/><circle cx="11" cy="5" r="2.8" fill="#1F4D3A"/></svg>taxa consolidada, %d–%d</span><span class="leg-item"><svg width="12" height="12"><circle cx="6" cy="6" r="3.6" fill="#fff" stroke="#1F4D3A" stroke-width="1.6"/></svg>%s: taxa estimada (excluída dos cálculos)</span></figcaption></figure>',
               svg, min(t$ano[!est]), max(t$ano[!est]), paste(t$ano[est], collapse = ", ")))
}

svg_prodes_bioma <- function() {
  b <- PRB[order(PRB$bioma, PRB$ano), ]
  ser <- lapply(BIOMAS, function(bi) { x <- b[b$bioma == bi, ]; parc <- x$status != "consolidado"; anual <- x$n_anos == 1
    v <- x$desmat_km2 / x$n_anos
    list(nome = bi, cor = COR_BIOMA[[bi]], larg = 2, x = x$ano, y = v, oco = parc | !anual, liga = !parc,
         tip = sprintf("%s · %d: %s km²%s", bi, x$ano, num(v, 0),
                       ifelse(parc, " (incremento parcial; excluído dos cálculos)",
                              ifelse(anual, "", sprintf(" por ano (média do período de %d anos encerrado em %d)", x$n_anos, x$ano))))) })
  svg <- svg_pontos(ser, "Incremento anual de desmatamento do PRODES em Mato Grosso, por bioma, km²")
  leg <- paste(vapply(BIOMAS, function(bi) sprintf('<span class="leg-item"><svg width="22" height="10"><line x1="0" x2="22" y1="5" y2="5" stroke="%s" stroke-width="2"/><circle cx="11" cy="5" r="2.8" fill="%s"/></svg>%s</span>',
                                                   COR_BIOMA[[bi]], COR_BIOMA[[bi]], bi), character(1)), collapse = "")
  HTML(sprintf('<figure class="grafico-svg">%s<figcaption class="legenda-svg">%s<span class="leg-item"><svg width="12" height="12"><circle cx="6" cy="6" r="3.6" fill="#fff" stroke="#6b7280" stroke-width="1.6"/></svg>ponto vazado: média anual de período de 2 a 4 anos ou dado parcial de 2026 (sem linha, excluído dos cálculos)</span></figcaption></figure>', svg, leg))
}

# ---- Dinâmica 2006-2017 ----------------------------------------------------------------
tabela_dinamica <- function(recorte = c("tipo", "bioma")) {
  recorte <- match.arg(recorte)
  d <- bind_rows(lapply(grupos_rec(recorte), function(g) { x <- DIN[DIN$grupo == g, ]
    tibble(Grupo = nome_grupo(g), `Municípios` = as.character(x$n_mun),
           E6 = num(x$estab_2006, 0), E7 = num(x$estab_2017, 0), VE = pct_txt(x$var_estab),
           A6 = num(x$area_2006 / 1e6, 2), A7 = num(x$area_2017 / 1e6, 2), VA = pct_txt(x$var_area),
           M6 = num(x$area_media_2006, 0), M7 = num(x$area_media_2017, 0), VM = pct_txt(x$var_area_media)) }))
  sub <- function(a, b) HTML(sprintf('%s<div class="sub">%s</div>', a, b))
  reactable(d, compact = TRUE, sortable = FALSE, pagination = FALSE, wrap = TRUE, class = "tabela-res",
            columnGroups = list(colGroup("Estabelecimentos", c("E6", "E7", "VE")), colGroup("Área, milhões de ha", c("A6", "A7", "VA")),
                                colGroup("Área média (ha por estab.)", c("M6", "M7", "VM"))),
            columns = list(Grupo = colDef(name = if (recorte == "tipo") "Tipo do M1" else "Bioma (IBGE 1:250 mil)", html = TRUE, minWidth = 200, sticky = "left"),
                           `Municípios` = colDef(name = "Mun.", align = "right", minWidth = 55),
                           E6 = colDef(name = "2006", align = "right"), E7 = colDef(name = "2017", align = "right"),
                           VE = colDef(name = "variação", align = "right", style = list(fontWeight = 600)),
                           A6 = colDef(name = "2006", align = "right"), A7 = colDef(name = "2017", align = "right"),
                           VA = colDef(name = "variação", align = "right", style = list(fontWeight = 600)),
                           M6 = colDef(name = "2006", align = "right"), M7 = colDef(name = "2017", align = "right"),
                           VM = colDef(name = "variação", align = "right", style = list(fontWeight = 600))))
}

tabela_medianas_dinamica <- function(recorte = c("tipo", "bioma")) {
  recorte <- match.arg(recorte)
  d <- bind_rows(lapply(grupos_rec(recorte), function(g) { x <- DIN[DIN$grupo == g, ]
    tibble(Grupo = nome_grupo(g), ME = pct_txt(x$mediana_var_estab), MA = pct_txt(x$mediana_var_area), MM = pct_txt(x$mediana_var_area_media),
           CE = sprintf("%d de %d", x$n_mun_estab_cai, x$n_mun), CA = sprintf("%d de %d", x$n_mun_area_cai, x$n_mun)) }))
  reactable(d, compact = TRUE, sortable = FALSE, pagination = FALSE, wrap = TRUE, class = "tabela-res",
            columns = list(Grupo = colDef(name = if (recorte == "tipo") "Tipo do M1" else "Bioma", html = TRUE, minWidth = 240),
                           ME = colDef(html = TRUE, header = HTML('Estab.<div class="sub">variação mediana</div>'), align = "right"),
                           MA = colDef(html = TRUE, header = HTML('Área<div class="sub">variação mediana</div>'), align = "right"),
                           MM = colDef(html = TRUE, header = HTML('Área média<div class="sub">variação mediana</div>'), align = "right"),
                           CE = colDef(html = TRUE, header = HTML('Perderam estab.<div class="sub">municípios</div>'), align = "right"),
                           CA = colDef(html = TRUE, header = HTML('Perderam área<div class="sub">municípios</div>'), align = "right")))
}

svg_dinamica <- function() {
  gs <- c(names(TIPOS), "MT", BIOMAS)
  met <- c(var_estab = "Estabelecimentos", var_area = "Área", var_area_media = "Área média")
  w <- 680; lh <- 24; top <- 26; pl <- 100; gap <- 14; pw <- (w - pl - 2 * gap - 10) / 3
  h <- top + length(gs) * lh + 26
  vals <- unlist(lapply(names(met), function(m) DIN[[m]][match(gs, DIN$grupo)]))
  lim <- max(abs(vals)) * 1.15
  rot <- function(g) if (g %in% names(TIPOS)) paste0(g, " · ", TIPOS[[g]], " (rótulo provisório)") else if (g == "MT") "Mato Grosso" else g
  cor <- function(g) if (g %in% names(TIPOS)) COR_TIPO[[g]] else if (g == "MT") "#111827" else COR_BIOMA[[g]]
  y_de <- function(i) top + (i - 1) * lh + if (gs[i] %in% BIOMAS) 8 else 0
  nomes <- paste(vapply(seq_along(gs), function(i) sprintf('<text x="%d" y="%.1f" font-size="11.5" text-anchor="end" fill="#1f2937"%s>%s</text>',
                                                            pl - 8, y_de(i) + 15, if (gs[i] == "MT") ' font-weight="700"' else "",
                                                            esc(if (gs[i] == "MT") "Mato Grosso" else gs[i])), character(1)), collapse = "")
  paineis <- paste(vapply(seq_along(met), function(k) {
    x0 <- pl + (k - 1) * (pw + gap); zero <- x0 + pw / 2
    sx <- function(v) zero + v / lim * (pw / 2)
    barras <- paste(vapply(seq_along(gs), function(i) { v <- DIN[[names(met)[k]]][DIN$grupo == gs[i]]; y <- y_de(i)
      sprintf('<rect x="%.1f" y="%.1f" width="%.1f" height="%d" fill="%s" data-tip="%s · %s: %s%%"/><text x="%.1f" y="%.1f" font-size="10" fill="#374151" text-anchor="%s">%s</text>',
              min(zero, sx(v)), y + 4, abs(sx(v) - zero), lh - 9, cor(gs[i]), esc(rot(gs[i])), met[[k]], fmt_r(v, 1),
              if (v >= 0) sx(v) + 3 else sx(v) - 3, y + 15, if (v >= 0) "start" else "end", fmt_r(v, 1)) }, character(1)), collapse = "")
    sprintf('<text x="%.1f" y="14" font-size="12" font-weight="700" text-anchor="middle" fill="#1F4D3A">%s</text><line x1="%.1f" x2="%.1f" y1="%d" y2="%d" stroke="#9ca3af"/>%s',
            zero, met[[k]], zero, zero, top, h - 22, barras)
  }, character(1)), collapse = "")
  HTML(sprintf('<figure class="grafico-svg"><svg viewBox="0 0 %d %d" width="100%%" role="img" aria-label="Variação 2006–2017 por tipo e por bioma">%s%s</svg><figcaption class="legenda-svg">Nota: variação de 2017 sobre 2006, em %%, calculada sobre as somas dos municípios de cada grupo, para o conjunto dos estabelecimentos agropecuários. T1 a T5: tipos do Manuscrito 1 (rótulos provisórios na tabela acima).</figcaption></figure>',
               w, h, nomes, paineis))
}

tabela_conciliacao <- function() {
  x <- DIN_CONC
  f <- function(v, u) ifelse(is.na(v), "—", if (u == "R$ mil") paste0("R$ ", num(v / 1e6, 2), " bi") else num(v, 0))
  d <- bind_rows(lapply(seq_len(nrow(x)), function(i) tibble(
    Item = x$rotulo[i], Soma = f(x$soma_municipal[i], x$unidade[i]), Estadual = f(x$tabela_estadual[i], x$unidade[i]),
    Confronto = f(x$tabela_confronto_ibge[i], x$unidade[i]),
    Dif = if (x$unidade[i] == "R$ mil") paste0("R$ ", num(x$diferenca[i] / 1e6, 2), " bi (", pct_txt(x$pct_diferenca[i]), ")")
          else if (x$diferenca[i] == 0) "0"
          else sprintf("%s (%s)", fmt_r(x$diferenca[i], 0),
                       if (abs(x$pct_diferenca[i]) < 0.01) "menos de 0,01%" else pct_txt(x$pct_diferenca[i], 1)))))
  reactable(d, compact = TRUE, sortable = FALSE, pagination = FALSE, wrap = TRUE,
            columns = list(Item = colDef(minWidth = 230), Soma = colDef(name = "Soma dos 141 municípios", align = "right"),
                           Estadual = colDef(html = TRUE, header = HTML('Tabela estadual<div class="sub">comparação 2006–2017, coluna Total</div>'), align = "right"),
                           Confronto = colDef(html = TRUE, header = HTML('Tabela de confronto do IBGE<div class="sub">série histórica dos Censos</div>'), align = "right"),
                           Dif = colDef(name = "Soma − tabela estadual", align = "right")))
}

tabela_sedes_dinamica <- function() {
  ss <- SEDES[order(SEDES$municipio), ]
  dd <- ler(ds("dinamica_2006_2017.csv"))
  d <- bind_rows(lapply(seq_len(nrow(ss)), function(i) { x <- dd[dd$id_municipio == ss$id_municipio[i], ]
    tibble(`Município` = sprintf('%s<div class="sub">%s</div>', link_mun(ss$municipio[i], ss$slug[i]), esc(ss$piloto[i])),
           Tipo = as.character(rot_tipo(ss$tipo_m1[i])),
           E = sprintf('%s → %s<div class="sub">%s</div>', num(x$n_estab_total_2006, 0), num(x$n_estab_total_2017, 0), pct_txt(x$pct_var_n_estab)),
           A = sprintf('%s → %s<div class="sub">%s</div>', num(x$area_total_ha_2006, 0), num(x$area_total_ha_2017, 0), pct_txt(x$pct_var_area))) }))
  reactable(d, compact = TRUE, sortable = FALSE, pagination = FALSE, wrap = TRUE, class = "tabela-res",
            columns = list(`Município` = colDef(name = "Município (área-piloto)", html = TRUE, minWidth = 150),
                           Tipo = colDef(html = TRUE, minWidth = 200),
                           E = colDef(html = TRUE, header = HTML('Estabelecimentos<div class="sub">2006 → 2017 (variação)</div>'), align = "right", minWidth = 130),
                           A = colDef(html = TRUE, header = HTML('Área, ha<div class="sub">2006 → 2017 (variação)</div>'), align = "right", minWidth = 170)))
}

# ---- Desmatamento por tipo: Artigo A refeito com o PRODES municipal oficial ------------
# O Artigo A estimou o desmatamento por tipo com a proxy do SEEG (mudança de uso da terra ÷ 150 tCO2e/ha),
# na tipologia anterior. Aqui a pergunta é refeita com o incremento oficial do PRODES por município
# (objetivos/dados/, gravado por scripts/06_preparar_oe1.py), na janela 2017–2025, em que os três biomas
# têm períodos anuais e consolidados. Área municipal: projeção equivalente de Albers (como no OE1).
JANELA_A <- "2017–2025"
DESM_RES <- ler(file.path(RAIZ, "objetivos", "dados", "prodes_mt_municipios_resumo.csv"))
DESM <- local({
  r <- DESM_RES[DESM_RES$bioma_prodes == "Total" & DESM_RES$janela == JANELA_A, c("id_municipio", "desmat_km2")]
  d <- MUN[, c("id_municipio", "municipio", "slug", "bioma", "tipo_m1")]
  d$desmat_km2 <- r$desmat_km2[match(d$id_municipio, r$id_municipio)]
  area <- as.numeric(st_area(st_transform(GEO, "ESRI:102033"))) / 1e6
  d$area_km2 <- area[match(d$id_municipio, GEO$id_municipio)]
  d$pct <- 100 * d$desmat_km2 / d$area_km2
  u <- ULT$ultimos[ULT$ultimos$indicador == "pct_estab_46504", ]
  d$pct_46504 <- u$valor_calc[match(d$id_municipio, u$id_municipio)]
  stopifnot(nrow(d) == 141, !anyNA(d$desmat_km2), !anyNA(d$area_km2), !anyNA(d$pct_46504))
  d
})
DESM_GR <- bind_rows(lapply(c("tipo", "bioma"), function(rec) {
  col <- if (rec == "tipo") "tipo_m1" else "bioma"
  bind_rows(lapply(grupos_rec(rec), function(g) { x <- if (g == "MT") DESM else DESM[DESM[[col]] == g, ]
    tibble(recorte = rec, grupo = g, n_mun = nrow(x), soma = sum(x$desmat_km2), pct_mt = 100 * sum(x$desmat_km2) / sum(DESM$desmat_km2),
           pct_territorio = 100 * sum(x$desmat_km2) / sum(x$area_km2), mediana = median(x$desmat_km2), mediana_pct = median(x$pct)) }))
}))
ROT_DESM <- c(desmat_km2 = "Desmatamento 2017–2025 (km²)", pct = "Desmatamento 2017–2025 (% do território)")
DESM_TES <- bind_rows(lapply(c(tipo = "tipo_m1", bioma = "bioma"), function(col)
  bind_rows(lapply(names(ROT_DESM), function(m) {
    kt <- kruskal.test(DESM[[m]], factor(DESM[[col]])); n <- nrow(DESM); h <- unname(kt$statistic)
    tibble(metrica = m, rotulo = ROT_DESM[[m]], n = n, gl = unname(kt$parameter), H = h, p = kt$p.value, epsilon2 = h / (n - 1))
  }))), .id = "recorte")
DESM_RHO <- bind_rows(lapply(names(ROT_DESM), function(m) {
  ct <- suppressWarnings(cor.test(DESM$pct_46504, DESM[[m]], method = "spearman", exact = FALSE))
  tibble(metrica = m, rho = unname(ct$estimate), p = ct$p.value) }))

tabela_desmat <- function(recorte = c("tipo", "bioma")) {
  recorte <- match.arg(recorte)
  x <- DESM_GR[DESM_GR$recorte == recorte, ]
  d <- tibble(Grupo = vapply(x$grupo, nome_grupo, character(1)), `Municípios` = as.character(x$n_mun),
              Soma = num(x$soma, 0), Pct = pct_txt(x$pct_mt, 1), Terr = pct_txt(x$pct_territorio, 2),
              Med = num(x$mediana, 1), MedPct = pct_txt(x$mediana_pct, 2))
  reactable(d, compact = TRUE, sortable = FALSE, pagination = FALSE, wrap = TRUE, class = "tabela-res",
            columns = list(Grupo = colDef(name = if (recorte == "tipo") "Tipo do M1" else "Bioma (IBGE 1:250 mil)", html = TRUE, minWidth = 250),
                           `Municípios` = colDef(align = "right", minWidth = 80),
                           Soma = colDef(html = TRUE, header = HTML('Desmatamento<div class="sub">km², soma 2017–2025</div>'), align = "right"),
                           Pct = colDef(html = TRUE, header = HTML('Participação<div class="sub">% da soma dos 141 municípios</div>'), align = "right"),
                           Terr = colDef(html = TRUE, header = HTML('Desmatado<div class="sub">% do território do grupo</div>'), align = "right"),
                           Med = colDef(html = TRUE, header = HTML('Mediana municipal<div class="sub">km², 2017–2025</div>'), align = "right"),
                           MedPct = colDef(html = TRUE, header = HTML('Mediana municipal<div class="sub">% do território</div>'), align = "right")))
}
