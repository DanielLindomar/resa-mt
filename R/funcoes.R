# =============================================================================
# R/funcoes.R - funções compartilhadas pelas páginas do Observatório RESA-MT
# =============================================================================
# As páginas leem só dados_site/ (scripts/01_preparar_dados.py grava os CSV;
# scripts/02_converter_rds.R grava os .rds). Uso no topo de cada página:
#
#   ```{r}
#   #| include: false
#   source(file.path(Sys.getenv("QUARTO_PROJECT_DIR", "."), "R", "funcoes.R"))
#   ```
#
# readr, ggplot2 e S7 não são usados: a política de Controle de Aplicativos do
# Windows bloqueia as DLLs. CSV com data.table::fread; gráficos em SVG gerado
# aqui; mapas com leaflet sem camada de fundo; tabelas com reactable.
#
# SINAIS DO IBGE. Toda célula tem `sinal` em {"valor", "X", "–", "..."}:
#   X   = sigilo do IBGE; "–" = zero absoluto; ... = não disponível.
#   `valor` fica NA quando o sinal não é "valor". `valor_calc` (só nos .rds)
#   = valor, ou 0 quando o sinal é "–", ou NA para X e ...; use valor_calc em
#   medianas, posições e cores, e fmt_celula()/html_celula() para mostrar.
#   Nunca mostre X, – ou ... como 0 ou como célula vazia.
#
# -----------------------------------------------------------------------------
# OBJETOS CARREGADOS
#   RAIZ   raiz do projeto Quarto; ds(...) = caminho em dados_site/
#   IND    tibble, 1 linha por indicador (34): id, ordem, dim, tema, rotulo,
#          rotulo_curto, unidade, fmt, ano_ref, kpi, serie, soma, sentido,
#          agregacao, numerador, denominador, fator, origem, fonte, arquivo,
#          variavel, nota, download
#   MUN    tibble, 141 municípios: id_municipio, municipio, slug, bioma,
#          pct_amazonia, pct_cerrado, pct_pantanal, tipo_m1, rotulo_m1,
#          sede_piloto, piloto, piloto_slug
#   SEDES  MUN só com os 3 municípios-sede das áreas-piloto
#   SER    tibble longo: id_municipio, indicador, ano, valor, sinal, valor_calc
#   ULT    list(ano_ref = tibble(indicador, ano_ref), ultimos = SER no ano_ref)
#   GEO    sf com os 141 polígonos: id_municipio, municipio, slug, bioma,
#          tipo_m1, rotulo_m1, sede_piloto
#   AGR    tibble de agregados: indicador, ano, recorte (mt|bioma|tipo), grupo
#          (MT | Amazônia, Cerrado, Pantanal | T1..T5), regra, valor, mediana,
#          n_mun, n_usados, n_valor, n_x, n_zero, n_nd
#   TOT    tibble totais_mt.csv (totais estaduais oficiais): id, rotulo, valor,
#          unidade, ano, fonte
#   PIL    tibble pilotos.csv (3 áreas-piloto, só identificação)
#   TEMAS  dim -> nome do tema; TIPOS T1..T5 -> rótulo provisório;
#          BIOMAS c("Amazônia", "Cerrado", "Pantanal")
#   COR, COR_BIOMA, COR_TIPO, COR_X, COR_ND  cores (iguais às figuras do M1)
#   TRACO  o caractere "–" (zero absoluto)
#
# FORMATAÇÃO (pt-BR: vírgula decimal, ponto de milhar)
#   num(x, d = 0)                        -> chr; NA vira "—"; arredonda meio para cima (como o M1)
#   ordem_pt(x), ordenar_pt(df, col)     -> ordem alfabética do português (stringi, pt_BR)
#   escala(x, prefixo = "")              -> chr com "mil", "mi", "bi"
#   fmt_valor(x, fmt)                    -> chr; fmt em int, dec1, dec2, dec3,
#                                           pct1, pct2, brl, brl_mil, usd
#   fmt_celula(valor, sinal, fmt)        -> chr; X, – ou ... quando é o caso
#   html_celula(valor, sinal, fmt)       -> chr HTML; X, – e ... com dica (title)
#   fmt_eixo(v)                          -> rótulos de eixo
#   num_csv(x, d)                        -> número para CSV (ponto decimal, sem zeros à direita)
#   esc(x)                               -> escapa &, <, >, "
#   legenda_sinais()                     -> div com a legenda X / – / ...
#
# CONSULTAS
#   info_ind(id)                         -> linha de IND
#   ano_ref(id)                          -> ano de referência do indicador
#   ultimo(id, mun_id)                   -> list(valor, sinal, valor_calc, ano)
#   ids_grupo(recorte, grupo = NULL)     -> ids; recorte "mt", "bioma", "tipo"
#   agregado(id, grupo, ano = NULL)      -> list(valor, mediana, regra, n_mun,
#                                           n_usados, n_x, n_zero, n_nd, ano)
#   resumo_ind(id, mun_id)               -> list(valor, sinal, valor_calc, ano,
#                                           bioma, tipo, pos_bioma, n_bioma,
#                                           pos_mt, n_mt, med_bioma, med_tipo,
#                                           med_mt, agr_bioma, agr_tipo, agr_mt,
#                                           vals_bioma, vals_mt)
#   situacao(valor, mediana, sentido)    -> list(txt, cls) para os selos ▲ ▼
#   tem_perfil(slug)                     -> TRUE se municipios/<slug>.qmd existe
#   url_ind(id, prefixo = "../indicadores/"), url_mun(slug, prefixo = "../municipios/")
#
# ELEMENTOS DE PÁGINA
#   faixa_versao(texto = NULL)           -> div.faixa-versao
#   aviso_municipio()                    -> "o município não é a área-piloto"
#   nota_correcao_prodes()               -> nota de correção do PRODES (19/10/2026)
#   chip_bioma(b), chip_tipo(t, rotulo = TRUE, provisorio = TRUE)
#   selo_provisorio(), selo_conciliacao()
#   selo_situacao(estado)                -> estado em concluido, andamento, confirmar ("a confirmar"), previsto
#   cartao_kpi(rotulo, valor, meta = NULL, comp = NULL) -> div.kpi genérico
#   kpi(id, mun_id, prefixo = "../indicadores/")       -> div.kpi do indicador
#   grade_kpis(mun_id, ids = IND$id[IND$kpi == 1], prefixo = "../indicadores/")
#   figura_m1(arquivo, legenda, prefixo = "../")       -> figura de resultados/figuras/m1/
#   fonte_rodape(ids = NULL, prefixo = "../")          -> parágrafo de fontes
#
# GRÁFICOS SVG (texto HTML; inserir com HTML() ou cat em bloco asis)
#   svg_sparkline(x, y, w = 110, h = 28, cor)
#   svg_posicao(vals, destaque, med_ref, fmt, w = 130, h = 26, rotulo = "")
#       vals = vetor nomeado por id_municipio; destaque = id (chr)
#   svg_linhas(series, fmt, titulo = "", w = 680, h = 260, nome_finas = NULL)
#       series = lista de list(nome, cor, larg, dash, x, y[, leg = FALSE])
#   serie_mun_medianas(id, mun_id, nome_mun) -> município x mediana do bioma x mediana de MT
#   series_agregados(id, recorte = "tipo", campo = "valor", incluir_mt = FALSE)
#       -> uma linha por grupo (bioma ou tipo), com o agregado (ou a mediana)
#   ranking(id, recorte = "mt", grupo = NULL, n_max = 20, destaque = SEDES$id_municipio,
#           prefixo = "../municipios/") -> tagList com barras (maiores + sedes) e nota dos sem valor
#
# TABELAS (reactable)
#   tabela_dim(dim, mun_id, nome_mun, prefixo = "../indicadores/") -> indicadores do tema no perfil
#   tabela_indicador(id, prefixo = "../municipios/")              -> 141 municípios
#   tabela_agregados(id, ano = NULL)                             -> MT, biomas e tipos
#   tabela_por_grupo(ids, recorte = "tipo", ano = NULL, incluir_mt = TRUE, prefixo = "../indicadores/")
#   resumo_tema(dim, prefixo = "../indicadores/")                -> MT e biomas por indicador do tema
#
# NAVEGAÇÃO
#   navegacao_municipio(mun_id)          -> ← anterior · lista · próximo → (os 141 perfis, em ordem alfabética)
#   navegacao_indicador(id)              -> ← todos · lista por tema · próximo →
#
# MAPAS (leaflet, sem camada de fundo)
#   mapa_municipio(mun_id = NULL, altura = 360, prefixo = "", cor_por = "bioma")
#       141 municípios por bioma (ou "tipo"), sedes contornadas, clique abre o perfil
#   mapa_indicador(id, altura = 460, prefixo = "../municipios/")
#       coroplético; X em cinza com a dica "X (sigilo IBGE)"; ... em cinza claro
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(htmltools); library(reactable); library(leaflet); library(sf)
})

RAIZ <- Sys.getenv("QUARTO_PROJECT_DIR", unset = ".")
source(file.path(RAIZ, "R", "idioma.R"))
ds   <- function(...) file.path(RAIZ, "dados_site", ...)
ler  <- function(f, ...) tibble::as_tibble(data.table::fread(f, encoding = "UTF-8", ...))

TRACO <- "–"
IND  <- ler(ds("indicadores.csv"), na.strings = "")
MUN  <- ler(ds("municipios.csv"))
SER  <- readRDS(ds("serie.rds"))
ULT  <- readRDS(ds("ultimos.rds"))
GEO  <- readRDS(ds("geo_mt.rds"))
AGR  <- readRDS(ds("agregados.rds"))
TOT  <- ler(ds("totais_mt.csv"))
PIL  <- ler(ds("pilotos.csv"))
SEDES <- MUN[MUN$sede_piloto, ]

TEMAS <- c(estrutura = "Estrutura da agricultura familiar", tecnologia = "Tecnologia, assistência e crédito",
           alimentos = "Produção e alimentos", posse = "Posse e reforma agrária",
           clima = "Clima (SEEG 13)", dinamica = "Dinâmica 2006–2017")
TIPOS <- c(T1 = "Baixo porte agregado", T2 = "Posse aguardando titulação, sem especialização",
           T3 = "Grande porte agregado", T4 = "Mecanizado com posse aguardando titulação",
           T5 = "Hortícola-irrigado")
BIOMAS <- c("Amazônia", "Cerrado", "Pantanal")

COR_BIOMA <- c("Amazônia" = "#1baf7a", "Cerrado" = "#eb6834", "Pantanal" = "#2a78d6")
COR_TIPO  <- c(T1 = "#c3c2b7", T2 = "#4a3aa7", T3 = "#008300", T4 = "#eda100", T5 = "#e87ba4")
COR <- c(mun = "#1F4D3A", sede = "#b45309", barra = "#7fb59a", mt = "#6b7280", bom = "#1b7f4b", ruim = "#b42318")
COR_X  <- "#c4c7ce"   # X (sigilo IBGE)
COR_ND <- "#eceef2"   # ... (não disponível)
SINAL_TXT <- setNames(c("X (sigilo IBGE)", paste(TRACO, "(zero absoluto)"), "... (não disponível)"), c("X", TRACO, "..."))

# ---- Formatação pt-BR -------------------------------------------------------
# Arredonda meio para cima (1.164,5 -> 1.165), a mesma regra dos números do Manuscrito 1.
# O formatC sozinho arredonda o meio para o par (1.164,5 -> 1.164).
arred <- function(x, d = 0) { k <- 10^d; sign(x) * floor(abs(x) * k + 0.5 + 1e-9) / k }
num <- function(x, d = 0) ifelse(is.na(x), "—",
  formatC(arred(x, d), format = "f", digits = d, big.mark = ".", decimal.mark = ","))

escala <- function(x, prefixo = "") {
  a <- abs(x)
  ifelse(is.na(x), "—",
  ifelse(a >= 1e9, paste0(prefixo, num(x / 1e9, 1), " bi"),
  ifelse(a >= 1e6, paste0(prefixo, num(x / 1e6, 1), " mi"),
  ifelse(a >= 1e4, paste0(prefixo, num(x / 1e3, 1), " mil"),
         paste0(prefixo, num(x, 0))))))
}

fmt_valor <- function(x, fmt) {
  switch(fmt,
    int = num(x, 0), dec1 = num(x, 1), dec2 = num(x, 2), dec3 = num(x, 3),
    pct1 = ifelse(is.na(x), "—", paste0(num(x, 1), "%")),
    pct2 = ifelse(is.na(x), "—", paste0(num(x, 2), "%")),
    brl = escala(x, "R$ "), brl_mil = escala(x * 1000, "R$ "), usd = escala(x, "US$ "),
    num(x, 2))
}
# Valor em escala "natural" (reais, não milhares de reais) e formato correspondente
escala_natural <- function(r) if (r$fmt == "brl_mil") list(f = 1000, fmt = "brl") else list(f = 1, fmt = r$fmt)
# Unidade como aparece na tela: valores "brl_mil" são exibidos em reais (R$ 81,4 mi), não em R$ mil.
# Nos dados e nos downloads a unidade continua a de indicadores.csv.
unid <- function(r) if (identical(r$fmt, "brl_mil")) sub("R$ mil", "R$", r$unidade, fixed = TRUE) else r$unidade

fmt_celula <- function(valor, sinal, fmt) {
  out <- fmt_valor(valor, fmt)
  s <- ifelse(is.na(sinal), "valor", sinal)
  out[s == "X"] <- "X"; out[s == TRACO] <- TRACO; out[s == "..."] <- "..."
  out
}

html_celula <- function(valor, sinal, fmt) {
  txt <- fmt_celula(valor, sinal, fmt)
  s <- ifelse(is.na(sinal), "valor", sinal)
  cls <- c("X" = "sinal sinal-x", "..." = "sinal sinal-nd"); cls[TRACO] <- "sinal sinal-zero"
  ifelse(s == "valor", txt, sprintf('<span class="%s" title="%s">%s</span>', cls[s], SINAL_TXT[s], txt))
}

fmt_eixo <- function(v) {
  a <- max(abs(v), na.rm = TRUE)
  if (a >= 1e9) return(ifelse(v == 0, "0", paste0(num(v / 1e9, 1), " bi")))
  if (a >= 1e6) return(ifelse(v == 0, "0", paste0(num(v / 1e6, 1), " mi")))
  if (a >= 1e4) return(ifelse(v == 0, "0", paste0(num(v / 1e3, 0), " mil")))
  d <- if (all(abs(v - round(v)) < 1e-9)) 0 else if (a >= 10) 1 else 2
  num(v, d)
}

# Número para CSV: ponto decimal, sem separador de milhar, sem zeros à direita
num_csv <- function(x, d) {
  s <- formatC(arred(x, d), format = "f", digits = d)
  s <- ifelse(grepl(".", s, fixed = TRUE), sub("[.]?0+$", "", s), s)
  ifelse(is.na(x), "", s)
}

esc <- function(x) { x <- gsub("&", "&amp;", x, fixed = TRUE); x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE); gsub("\"", "&quot;", x, fixed = TRUE) }

legenda_sinais <- function() div(class = "legenda-sinais",
  "Sinais convencionais do IBGE: ", tags$b("X"), " sigilo (dado omitido para evitar a identificação do informante) · ",
  tags$b(TRACO), " zero absoluto · ", tags$b("..."), " não disponível. Na exibição, nenhum desses sinais é tratado como zero.")

# ---- Consultas -------------------------------------------------------------
info_ind <- function(id) { r <- IND[IND$id == id, ]; if (nrow(r) != 1) stop("indicador desconhecido: ", id); r }
ano_ref  <- function(id) ULT$ano_ref$ano_ref[ULT$ano_ref$indicador == id]
url_ind  <- function(id, prefixo = "../indicadores/") paste0(prefixo, id, ".html")
url_mun  <- function(slug, prefixo = "../municipios/") paste0(prefixo, slug, ".html")
tem_perfil <- function(slug) file.exists(file.path(RAIZ, "municipios", paste0(slug, ".qmd")))
# Ordem alfabética do português ("Água Boa" no início, "Cáceres" antes de "Campinápolis").
# O arrange() do dplyr usa a ordem C (acentos no fim); não use arrange() para ordenar nomes.
ordem_pt <- function(x) if (requireNamespace("stringi", quietly = TRUE)) stringi::stri_order(x, locale = "pt_BR") else order(x)
ordenar_pt <- function(df, col = "municipio") df[ordem_pt(df[[col]]), ]
sort_pt <- function(x) x[ordem_pt(x)]
PERFIS <- ordenar_pt(MUN[vapply(MUN$slug, tem_perfil, logical(1)), ])

ultimo <- function(id, mun_id) {
  u <- ULT$ultimos[ULT$ultimos$indicador == id & ULT$ultimos$id_municipio == mun_id, ]
  if (nrow(u) == 0) list(valor = NA_real_, sinal = "...", valor_calc = NA_real_, ano = NA_integer_)
  else list(valor = u$valor, sinal = u$sinal, valor_calc = u$valor_calc, ano = u$ano)
}

ids_grupo <- function(recorte = c("mt", "bioma", "tipo"), grupo = NULL) {
  recorte <- match.arg(recorte)
  if (recorte == "mt") return(MUN$id_municipio)
  if (is.null(grupo)) stop("informe o grupo (bioma ou tipo)")
  if (recorte == "bioma") MUN$id_municipio[MUN$bioma == grupo] else MUN$id_municipio[MUN$tipo_m1 == grupo]
}

agregado <- function(id, grupo, ano = NULL) {
  a <- if (is.null(ano)) ano_ref(id) else ano
  g <- AGR[AGR$indicador == id & AGR$grupo == grupo & AGR$ano == a, ]
  if (nrow(g) == 0) return(list(valor = NA_real_, mediana = NA_real_, regra = NA_character_, n_mun = 0L,
                                n_usados = 0L, n_x = 0L, n_zero = 0L, n_nd = 0L, ano = a))
  as.list(g[1, c("valor", "mediana", "regra", "n_mun", "n_usados", "n_x", "n_zero", "n_nd", "ano")])
}

resumo_ind <- function(id, mun_id) {
  u  <- ULT$ultimos[ULT$ultimos$indicador == id, ]
  m  <- MUN[MUN$id_municipio == mun_id, ]
  me <- ultimo(id, mun_id)
  ub <- u[u$id_municipio %in% ids_grupo("bioma", m$bioma), ]
  ut <- u[u$id_municipio %in% ids_grupo("tipo", m$tipo_m1), ]
  pos <- function(uu) if (is.na(me$valor_calc)) NA_integer_ else sum(uu$valor_calc > me$valor_calc, na.rm = TRUE) + 1L
  list(valor = me$valor, sinal = me$sinal, valor_calc = me$valor_calc, ano = me$ano,
       bioma = m$bioma, tipo = m$tipo_m1,
       pos_bioma = pos(ub), n_bioma = sum(!is.na(ub$valor_calc)), pos_mt = pos(u), n_mt = sum(!is.na(u$valor_calc)),
       med_bioma = median(ub$valor_calc, na.rm = TRUE), med_tipo = median(ut$valor_calc, na.rm = TRUE),
       med_mt = median(u$valor_calc, na.rm = TRUE),
       agr_bioma = agregado(id, m$bioma)$valor, agr_tipo = agregado(id, m$tipo_m1)$valor, agr_mt = agregado(id, "MT")$valor,
       vals_bioma = setNames(ub$valor_calc, ub$id_municipio), vals_mt = setNames(u$valor_calc, u$id_municipio))
}

# Situação em relação a uma mediana, considerando o sentido do indicador (0 = contexto, sem cor)
situacao <- function(valor, mediana, sentido) {
  if (is.na(valor) || is.na(mediana)) return(list(txt = "—", cls = "sit-neutra"))
  if (isTRUE(all.equal(valor, mediana))) return(list(txt = "= mediana", cls = "sit-neutra"))
  acima <- valor > mediana
  txt <- if (acima) "▲ acima" else "▼ abaixo"
  cls <- if (is.na(sentido) || sentido == 0) "sit-neutra"
         else if ((acima && sentido > 0) || (!acima && sentido < 0)) "sit-boa" else "sit-ruim"
  list(txt = txt, cls = cls)
}

# ---- Elementos de página -------------------------------------------------------
faixa_versao <- function(texto = NULL) div(class = "faixa-versao",
  if (is.null(texto)) "Versão preliminar para a equipe do projeto. Os resultados estão sujeitos a alteração à medida que as etapas do estudo forem concluídas." else texto)

aviso_municipio <- function() div(class = "aviso-municipio",
  tags$b("O município não é a área-piloto. "),
  "Os indicadores descrevem o município inteiro (ou o conjunto de sua agricultura familiar) e, portanto, fornecem o contexto das áreas-piloto, sem medi-las.")

nota_correcao_prodes <- function() div(class = "nota-correcao",
  tags$b("Nota de correção (19/10/2026). "),
  "A série do PRODES utilizada anteriormente nos materiais do projeto continha a Amazônia digitada manualmente, com valores superiores à taxa oficial de MT de 2005 a 2024. ",
  "O site passou a utilizar exclusivamente a série oficial do Instituto Nacional de Pesquisas Espaciais (INPE), disponível na plataforma TerraBrasilis e obtida em 19/10/2026, que compreende a taxa anual de MT na Amazônia Legal e o incremento anual por bioma.")

chip_bioma <- function(b) span(class = paste0("chip chip-", c("Amazônia" = "amazonia", "Cerrado" = "cerrado", "Pantanal" = "pantanal")[[b]]), b)
selo_provisorio <- function() span(class = "rotulo-provisorio", title = "Rótulo pendente de aprovação dos autores do Manuscrito 1", "rótulo provisório")
chip_tipo <- function(t, rotulo = TRUE, provisorio = TRUE)
  tagList(span(class = paste0("chip chip-", tolower(t)), if (rotulo) paste0(t, " · ", TIPOS[[t]]) else t),
          if (rotulo && provisorio) selo_provisorio())
selo_situacao <- function(estado = c("concluido", "andamento", "confirmar", "previsto")) {
  estado <- match.arg(estado)
  span(class = paste0("selo-situacao selo-", estado),
       c(concluido = "concluído", andamento = "em andamento", confirmar = "a confirmar", previsto = "previsto")[[estado]])
}
selo_conciliacao <- function() span(class = "selo-conciliacao", title = "Os números de famílias e de área divergem entre as fontes e serão incluídos após a conciliação", "números em conciliação")

cartao_kpi <- function(rotulo, valor, meta = NULL, comp = NULL)
  div(class = "kpi", div(class = "kpi-rotulo", rotulo), div(class = "kpi-valor", valor),
      if (!is.null(meta)) div(class = "kpi-meta", meta), if (!is.null(comp)) div(class = "kpi-comp", comp))

# Comparação do cartão: parcela no total dos municípios de MT (totais) ou medianas dos municípios
comp_kpi <- function(r, s) {
  if (isTRUE(r$soma == 1) && is.finite(s$agr_mt) && s$agr_mt > 0 && identical(s$sinal, "valor")) {
    pc <- 100 * s$valor / s$agr_mt
    if (pc == 0) "0% do total dos municípios de MT"
    else if (pc < 0.05) "menos de 0,1% do total dos municípios de MT"
    else sprintf("%s%% do total dos municípios de MT", num(pc, 1))
  } else {
    sprintf("Mediana dos municípios: %s %s · MT %s", s$bioma, fmt_valor(s$med_bioma, r$fmt), fmt_valor(s$med_mt, r$fmt))
  }
}

kpi <- function(id, mun_id, prefixo = "../indicadores/") {
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

grade_kpis <- function(mun_id, ids = IND$id[IND$kpi == 1], prefixo = "../indicadores/")
  div(class = "kpi-grade", lapply(ids, kpi, mun_id = mun_id, prefixo = prefixo))

figura_m1 <- function(arquivo, legenda, prefixo = "../")
  tags$figure(class = "figure", tags$img(src = paste0(prefixo, "resultados/figuras/m1/", arquivo), alt = legenda,
                                         class = "img-fluid", loading = "lazy"),
              tags$figcaption(class = "figure-caption", legenda))

fonte_rodape <- function(ids = NULL, prefixo = "../") {
  fontes <- if (is.null(ids)) c("IBGE (Censos Agropecuários 2006 e 2017)", "INCRA/SIPRA",
                                "SEEG 13 (Observatório do Clima)", "INPE/PRODES (TerraBrasilis)")
            else unique(IND$fonte[IND$id %in% ids])
  # Um só nó HTML: com vários filhos, o htmltools quebra a linha entre eles e aparece espaço antes do ponto
  p(class = "nota-fonte", HTML(paste0(
    "Fonte: Elaboração própria com base em ", esc(paste(fontes, collapse = "; ")), ". ",
    "Bioma dominante: IBGE, Biomas 1:250 mil (2019). Tipos municipais: Manuscrito 1 do Projeto RESA (k = 5; rótulos provisórios). ",
    "Medianas e agregados calculados no ano de referência de cada indicador; ", TRACO, " (zero absoluto) é tratado como zero, e X e ... são excluídos. Detalhes metodológicos em ",
    '<a href="', paste0(prefixo, "dados/index.html"), '">Dados</a>.')))
}

# ---- SVG: minissérie, posição no bioma e gráfico de linhas -------------------
svg_sparkline <- function(x, y, w = 110, h = 28, cor = COR[["mun"]]) {
  ok <- is.finite(y); x <- x[ok]; y <- y[ok]
  if (length(y) < 2) return("")
  o <- order(x); x <- x[o]; y <- y[o]
  xr <- range(x); yr <- range(y); if (diff(yr) == 0) yr <- yr + c(-1, 1)
  px <- 3 + (x - xr[1]) / diff(xr) * (w - 6); py <- h - 3 - (y - yr[1]) / diff(yr) * (h - 6)
  sprintf('<svg class="spark" viewBox="0 0 %d %d" width="%d" height="%d" role="img" aria-label="Série %d–%d"><title>Série %d–%d</title><polyline fill="none" stroke="%s" stroke-width="1.6" points="%s"/><circle cx="%.1f" cy="%.1f" r="2.4" fill="%s"/></svg>',
          w, h, w, h, xr[1], xr[2], xr[1], xr[2], cor,
          paste(sprintf("%.1f,%.1f", px, py), collapse = " "), tail(px, 1), tail(py, 1), cor)
}

svg_posicao <- function(vals, destaque, med_ref, fmt, w = 130, h = 26, rotulo = "Posição entre os municípios do bioma") {
  vals <- vals[is.finite(vals)]
  if (length(vals) < 2 || !destaque %in% names(vals)) return("")
  r <- range(c(vals, med_ref), na.rm = TRUE); if (diff(r) == 0) r <- r + c(-1, 1)
  sx <- function(v) 6 + (v - r[1]) / diff(r) * (w - 12)
  nomes <- MUN$municipio[match(as.integer(names(vals)), MUN$id_municipio)]
  outros <- names(vals) != destaque
  pts <- paste(sprintf('<circle cx="%.1f" cy="13" r="3.4" fill="#b9d3c5" stroke="transparent" stroke-width="6" data-tip="%s: %s"/>',
                       sx(vals[outros]), esc(nomes[outros]), fmt_valor(vals[outros], fmt)), collapse = "")
  mt <- if (is.finite(med_ref)) sprintf('<line x1="%.1f" x2="%.1f" y1="4" y2="22" stroke="#6b7280" stroke-dasharray="2,2" data-tip="Mediana de MT: %s"/>',
                                        sx(med_ref), sx(med_ref), fmt_valor(med_ref, fmt)) else ""
  eu <- sprintf('<circle cx="%.1f" cy="13" r="5.5" fill="%s" stroke="#fff" stroke-width="1.5" data-tip="%s: %s"/>',
                sx(vals[[destaque]]), COR[["mun"]], esc(nomes[!outros]), fmt_valor(vals[[destaque]], fmt))
  sprintf('<svg class="strip" viewBox="0 0 %d %d" width="%d" height="%d" role="img" aria-label="%s"><line x1="6" x2="%d" y1="13" y2="13" stroke="#e5e7eb" stroke-width="2"/>%s%s%s</svg>',
          w, h, w, h, esc(rotulo), w - 6, mt, pts, eu)
}

# series: lista de list(nome, cor, larg, dash, x, y[, leg = FALSE]); nome_finas = legenda das linhas finas (leg = FALSE)
svg_linhas <- function(series, fmt, titulo = "", w = 680, h = 260, nome_finas = NULL) {
  ys <- unlist(lapply(series, `[[`, "y")); xs <- unlist(lapply(series, `[[`, "x"))
  ys <- ys[is.finite(ys)]
  if (length(ys) < 2) return("")
  pl <- 62; pr <- 14; pt <- 12; pb <- 26
  xr <- range(xs); if (diff(xr) == 0) xr <- xr + c(-1, 1)
  yt <- pretty(range(ys), n = 5); yr <- range(yt)
  sx <- function(x) pl + (x - xr[1]) / diff(xr) * (w - pl - pr)
  sy <- function(y) h - pb - (y - yr[1]) / diff(yr) * (h - pt - pb)
  grade <- paste(sprintf('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#eef0f4"/><text x="%d" y="%.1f" text-anchor="end" font-size="11" fill="#6b7280">%s</text>',
                         pl, w - pr, sy(yt), sy(yt), pl - 6, sy(yt) + 4, fmt_eixo(yt)), collapse = "")
  xt <- pretty(xr, n = 6); xt <- xt[xt >= xr[1] & xt <= xr[2] & xt == round(xt)]
  eixo_x <- paste(sprintf('<text x="%.1f" y="%d" text-anchor="middle" font-size="11" fill="#6b7280">%d</text>',
                          sx(xt), h - 8, as.integer(xt)), collapse = "")
  zero <- if (yr[1] < 0 && yr[2] > 0) sprintf('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#9ca3af"/>', pl, w - pr, sy(0), sy(0)) else ""
  linhas <- vapply(series, function(s) {
    ok <- is.finite(s$y); o <- order(s$x); x <- s$x[o]; y <- s$y[o]; ok <- ok[o]
    if (sum(ok) == 0) return("")
    seg <- paste0(ifelse(c(TRUE, !ok[-length(ok)]) & ok, "M", "L")[ok], sprintf("%.1f %.1f", sx(x[ok]), sy(y[ok])), collapse = " ")
    pts <- paste(sprintf('<circle class="pt" cx="%.1f" cy="%.1f" r="%s" fill="%s" stroke="transparent" stroke-width="9" data-tip="%s · %d: %s"/>',
                         sx(x[ok]), sy(y[ok]), if (s$larg >= 2.5) "3" else "2.2", s$cor, esc(s$nome), as.integer(x[ok]),
                         fmt_valor(y[ok], fmt)), collapse = "")
    sprintf('<g class="serie"><path class="linha" d="%s" fill="none" stroke="%s" stroke-width="%s" %s data-tip="%s"/>%s</g>', seg, s$cor, s$larg,
            if (nzchar(s$dash)) sprintf('stroke-dasharray="%s"', s$dash) else "", esc(s$nome), pts)
  }, character(1))
  series_leg <- Filter(function(s) !isFALSE(s$leg), series)
  if (length(series_leg) < length(series) && !is.null(nome_finas))
    series_leg <- c(list(list(nome = nome_finas, cor = "#cfd8e6", larg = 1.5, dash = "")), series_leg)
  leg <- paste(vapply(series_leg, function(s) sprintf('<span class="leg-item"><svg width="22" height="8"><line x1="0" x2="22" y1="4" y2="4" stroke="%s" stroke-width="%s" %s/></svg>%s</span>',
                                                  s$cor, s$larg, if (nzchar(s$dash)) sprintf('stroke-dasharray="%s"', s$dash) else "", esc(s$nome)), character(1)), collapse = "")
  sprintf('<figure class="grafico-svg"><svg viewBox="0 0 %d %d" width="100%%" role="img" aria-label="%s">%s%s%s%s</svg><figcaption class="legenda-svg">%s</figcaption></figure>',
          w, h, esc(titulo), grade, zero, eixo_x, paste(linhas, collapse = ""), leg)
}

serie_mun_medianas <- function(id, mun_id, nome_mun) {
  r <- info_ind(id); e <- escala_natural(r)
  s <- SER[SER$indicador == id & !is.na(SER$ano), ]
  me <- s[s$id_municipio == mun_id, c("ano", "valor_calc")]
  if (nrow(me) < 2) return("")
  b <- MUN$bioma[MUN$id_municipio == mun_id]; ib <- ids_grupo("bioma", b)
  meds <- s |> filter(ano >= min(me$ano), ano <= max(me$ano)) |> group_by(ano) |>
    summarise(bi = median(valor_calc[id_municipio %in% ib], na.rm = TRUE), mt = median(valor_calc, na.rm = TRUE), .groups = "drop")
  svg_linhas(list(
    list(nome = nome_mun, cor = COR[["mun"]], larg = 2.8, dash = "", x = me$ano, y = me$valor_calc * e$f),
    list(nome = paste("Mediana", b), cor = COR_BIOMA[[b]], larg = 1.8, dash = "6,4", x = meds$ano, y = meds$bi * e$f),
    list(nome = "Mediana MT", cor = COR[["mt"]], larg = 1.8, dash = "2,3", x = meds$ano, y = meds$mt * e$f)),
    fmt = e$fmt, titulo = paste0(r$rotulo, " — ", nome_mun))
}

series_agregados <- function(id, recorte = c("tipo", "bioma"), campo = c("valor", "mediana"), incluir_mt = FALSE) {
  recorte <- match.arg(recorte); campo <- match.arg(campo)
  r <- info_ind(id); e <- escala_natural(r)
  a <- AGR[AGR$indicador == id & (AGR$recorte == recorte | (incluir_mt & AGR$recorte == "mt")), ]
  if (n_distinct(a$ano) < 2) return("")
  grupos <- if (recorte == "tipo") names(TIPOS) else BIOMAS
  cores <- if (recorte == "tipo") COR_TIPO else COR_BIOMA
  ser <- lapply(grupos, function(g) { x <- a[a$grupo == g, ]
    list(nome = if (recorte == "tipo") paste0(g, " · ", TIPOS[[g]]) else g, cor = cores[[g]], larg = 2.4, dash = "",
         x = x$ano, y = x[[campo]] * e$f) })
  if (incluir_mt) { x <- a[a$grupo == "MT", ]
    ser <- c(ser, list(list(nome = "MT", cor = "#111827", larg = 2, dash = "2,3", x = x$ano, y = x[[campo]] * e$f))) }
  svg_linhas(ser, fmt = e$fmt,
             titulo = paste0(r$rotulo, " — ", if (campo == "valor") "agregado" else "mediana", " por ", recorte))
}

# ---- Ranking (barras horizontais): os n_max maiores mais os destacados ---------
ranking <- function(id, recorte = c("mt", "bioma", "tipo"), grupo = NULL, n_max = 20,
                    destaque = SEDES$id_municipio, prefixo = "../municipios/") {
  recorte <- match.arg(recorte)
  r <- info_ind(id); e <- escala_natural(r)
  ids <- ids_grupo(recorte, grupo)
  u <- ULT$ultimos[ULT$ultimos$indicador == id & ULT$ultimos$id_municipio %in% ids, ] |>
    left_join(select(MUN, id_municipio, municipio, slug), by = "id_municipio")
  com <- u[!is.na(u$valor_calc), ]
  com <- com[order(-com$valor_calc, order(ordem_pt(com$municipio))), ]
  com$pos <- seq_len(nrow(com))
  sem <- u[is.na(u$valor_calc), ]
  if (nrow(com) == 0) return(p(class = "nota-fonte", "Nenhum município apresenta valor publicado neste recorte."))
  mo <- com[com$pos <= n_max | com$id_municipio %in% destaque, ]
  # linhas, com um marcador "⋯" quando há posições puladas
  lin <- list(); prev <- 0
  for (i in seq_len(nrow(mo))) {
    if (mo$pos[i] > prev + 1) lin[[length(lin) + 1]] <- list(gap = TRUE)
    lin[[length(lin) + 1]] <- c(as.list(mo[i, ]), gap = FALSE); prev <- mo$pos[i]
  }
  if (prev < nrow(com)) lin[[length(lin) + 1]] <- list(gap = TRUE)
  med_g <- median(com$valor_calc); med_mt <- median(ULT$ultimos$valor_calc[ULT$ultimos$indicador == id], na.rm = TRUE)
  w <- 680; lh <- 22; pl <- 210; pr <- 100; h <- length(lin) * lh + 44
  vv <- mo$valor_calc * e$f
  lim <- range(c(0, vv, med_g * e$f, med_mt * e$f), na.rm = TRUE); if (diff(lim) == 0) lim <- lim + c(0, 1)
  sx <- function(x) pl + (x - lim[1]) / diff(lim) * (w - pl - pr)
  partes <- vapply(seq_along(lin), function(k) {
    L <- lin[[k]]; y0 <- (k - 1) * lh
    if (isTRUE(L$gap)) return(sprintf('<text x="%d" y="%.1f" text-anchor="end" font-size="12" fill="#9ca3af">⋯</text>', pl - 8, y0 + 15))
    v <- L$valor_calc * e$f; d <- L$id_municipio %in% destaque
    rot <- sprintf("%dº %s", L$pos, esc(L$municipio))
    txt <- sprintf('<text x="%d" y="%.1f" text-anchor="end" font-size="12" fill="#1f2937"%s>%s</text>', pl - 8, y0 + 15,
                   if (d) ' font-weight="700"' else "", rot)
    if (tem_perfil(L$slug)) txt <- sprintf('<a href="%s">%s</a>', url_mun(L$slug, prefixo), txt)
    val <- fmt_celula(L$valor * e$f, L$sinal, e$fmt)
    sprintf('%s<rect x="%.1f" y="%.1f" width="%.1f" height="%d" fill="%s" data-tip="%s: %s (%s)"/><text x="%.1f" y="%.1f" font-size="11" fill="#374151">%s</text>',
            txt, min(sx(0), sx(v)), y0 + 4, abs(sx(v) - sx(0)), lh - 8, if (d) COR[["sede"]] else COR[["barra"]],
            esc(L$municipio), val, L$ano, max(sx(0), sx(v)) + 5, y0 + 15, val)
  }, character(1))
  ref <- function(v, cor, rot, dy) if (is.finite(v)) sprintf('<line x1="%.1f" x2="%.1f" y1="0" y2="%d" stroke="%s" stroke-dasharray="4,3" stroke-width="1.5"/><text x="%.1f" y="%d" font-size="11" fill="%s" text-anchor="middle">%s</text>',
                                                         sx(v), sx(v), h - 26 + dy, cor, sx(v), h - 14 + dy, cor, rot) else ""
  nome_g <- switch(recorte, mt = "MT", bioma = grupo, tipo = grupo)
  svg <- sprintf('<svg viewBox="0 0 %d %d" width="100%%" role="img" aria-label="Ranking: %s">%s%s%s</svg>',
                 w, h, esc(r$rotulo), paste(partes, collapse = ""),
                 if (recorte != "mt") ref(med_g * e$f, "#1F4D3A", paste("mediana", nome_g), 0) else "",
                 ref(med_mt * e$f, "#6b7280", "mediana MT", 13))
  notas <- lapply(c("X", "..."), function(si) { x <- sem$municipio[sem$sinal == si]
    if (length(x)) p(class = "nota-fonte", sprintf("Sem valor em razão de %s: %s.", SINAL_TXT[[si]], paste(sort_pt(x), collapse = ", "))) })
  tagList(HTML(svg),
          p(class = "nota-fonte", sprintf("%d municípios com valor publicado%s.",
                                          nrow(com), if (nrow(com) > n_max) sprintf("; exibem-se os %d maiores valores e os municípios-sede das áreas-piloto", n_max) else "")),
          notas)
}

# ---- Tabelas -------------------------------------------------------------------
tabela_dim <- function(dim, mun_id, nome_mun, prefixo = "../indicadores/") {
  ids <- IND$id[IND$dim == dim]
  d <- bind_rows(lapply(ids, function(id) {
    r <- info_ind(id); s <- resumo_ind(id, mun_id); sit <- situacao(s$valor_calc, s$med_bioma, r$sentido)
    ser <- SER[SER$indicador == id & SER$id_municipio == mun_id, ]
    nota <- if (!is.na(r$nota) && nzchar(r$nota)) sprintf(' <span class="nota-i" title="%s">ⓘ</span>', esc(r$nota)) else ""
    tibble(
      id = id,
      Indicador = sprintf('<a href="%s">%s</a>%s<div class="sub">%s</div>', url_ind(id, prefixo), esc(r$rotulo), nota, esc(unid(r))),
      Valor = sprintf('<b>%s</b><div class="sub">%s</div>', html_celula(s$valor, s$sinal, r$fmt), ifelse(is.na(s$ano), "", s$ano)),
      Posicao = sprintf('%s<div class="sub">%s</div>', svg_posicao(s$vals_bioma, as.character(mun_id), s$med_mt, r$fmt),
                        ifelse(is.na(s$pos_bioma), "", sprintf("%dº maior de %d", s$pos_bioma, s$n_bioma))),
      Serie = if (isTRUE(r$serie == 1)) svg_sparkline(ser$ano, ser$valor_calc) else "",
      Bioma = sprintf('<span class="sit %s">%s</span><div class="sub">mediana %s</div>', sit$cls, sit$txt, fmt_valor(s$med_bioma, r$fmt)),
      MT = fmt_valor(s$med_mt, r$fmt),
      serie_ok = isTRUE(r$serie == 1), ano_txt = as.character(s$ano), nota_txt = ifelse(is.na(r$nota), "", r$nota))
  }))
  b <- MUN$bioma[MUN$id_municipio == mun_id]
  reactable(d, compact = TRUE, highlight = TRUE, sortable = FALSE, pagination = FALSE, wrap = TRUE,
            class = "tabela-dim",
            columns = list(
              id = colDef(show = FALSE), nota_txt = colDef(show = FALSE), serie_ok = colDef(show = FALSE), ano_txt = colDef(show = FALSE),
              Indicador = colDef(html = TRUE, minWidth = 210),
              Valor = colDef(html = TRUE, align = "right", minWidth = 95),
              Posicao = colDef(name = paste("Posição no bioma", b), html = TRUE, align = "center", minWidth = 150),
              Serie = colDef(name = "Série", html = TRUE, align = "center", minWidth = 110),
              Bioma = colDef(name = paste("Frente ao bioma", b), html = TRUE, align = "center", minWidth = 120),
              MT = colDef(name = "Mediana MT", align = "right", minWidth = 90)),
            details = function(i) {
              g <- if (d$serie_ok[i]) serie_mun_medianas(d$id[i], mun_id, nome_mun) else ""
              div(class = "detalhe-ind",
                  if (nzchar(g)) HTML(g) else p(class = "sub", sprintf("Retrato de um único ano (%s); o site não apresenta série histórica para este indicador.", d$ano_txt[i])),
                  if (nzchar(d$nota_txt[i])) p(class = "nota-fonte", strong("Nota: "), d$nota_txt[i]),
                  p(class = "nota-fonte", a(href = url_ind(d$id[i], prefixo), "Este indicador em todos os municípios →")))
            })
}

tabela_indicador <- function(id, prefixo = "../municipios/") {
  r <- info_ind(id)
  u <- ULT$ultimos[ULT$ultimos$indicador == id, ] |>
    left_join(select(MUN, id_municipio, municipio, slug, bioma, tipo_m1), by = "id_municipio")
  u <- u[order(-u$valor_calc, order(ordem_pt(u$municipio)), na.last = TRUE), ]
  d <- transmute(u, Município = municipio, slug, Bioma = bioma, Tipo = tipo_m1, Valor = valor_calc,
                 Exibir = html_celula(valor, sinal, r$fmt), Ano = ano)
  reactable(d, searchable = TRUE, compact = TRUE, striped = TRUE, defaultPageSize = 20,
            showPageSizeOptions = TRUE, pageSizeOptions = c(20, 50, 141),
            columns = list(slug = colDef(show = FALSE), Exibir = colDef(show = FALSE),
              Município = colDef(minWidth = 170, cell = function(v, i)
                if (tem_perfil(d$slug[i])) a(href = url_mun(d$slug[i], prefixo), v) else v),
              Bioma = colDef(minWidth = 90),
              Tipo = colDef(name = "Tipo (M1)", minWidth = 70, align = "center"),
              Valor = colDef(align = "right", html = TRUE, sortNALast = TRUE, cell = function(v, i) d$Exibir[i]),
              Ano = colDef(align = "center", minWidth = 60)))
}

tabela_agregados <- function(id, ano = NULL) {
  r <- info_ind(id); a <- if (is.null(ano)) ano_ref(id) else ano
  g <- AGR[AGR$indicador == id & AGR$ano == a, ]
  g <- g[order(match(g$recorte, c("mt", "bioma", "tipo")), match(g$grupo, c("MT", BIOMAS, names(TIPOS)))), ]
  regra <- c(soma = "soma dos municípios", razao = "razão das somas", variacao = "variação das somas", mediana = "mediana")
  d <- tibble(Recorte = c(mt = "Mato Grosso", bioma = "Bioma", tipo = "Tipo do M1")[g$recorte],
              Grupo = ifelse(g$recorte == "tipo", paste0(g$grupo, " · ", TIPOS[g$grupo]), g$grupo),
              Agregado = fmt_valor(g$valor, r$fmt), Mediana = fmt_valor(g$mediana, r$fmt),
              Municípios = sprintf("%d de %d", g$n_usados, g$n_mun), X = g$n_x)
  tagList(reactable(d, compact = TRUE, sortable = FALSE, pagination = FALSE, wrap = TRUE,
                    columns = list(Grupo = colDef(minWidth = 200), Agregado = colDef(align = "right", name = paste0("Agregado (", regra[[r$agregacao]], ")")),
                                   Mediana = colDef(align = "right", name = "Mediana municipal"),
                                   Municípios = colDef(align = "center", name = "Municípios usados"),
                                   X = colDef(align = "center", name = "Com X (sigilo)"))),
          p(class = "nota-fonte", sprintf("Ano: %s.%s Os rótulos dos tipos do M1 são provisórios.", a,
                                          if (any(g$n_x > 0)) " Nos grupos com X, o agregado considera apenas os municípios com valor publicado." else "")))
}

tabela_por_grupo <- function(ids, recorte = c("tipo", "bioma"), ano = NULL, incluir_mt = TRUE, prefixo = "../indicadores/") {
  recorte <- match.arg(recorte)
  grupos <- c(if (recorte == "tipo") names(TIPOS) else BIOMAS, if (incluir_mt) "MT")
  linhas <- lapply(grupos, function(g) {
    vals <- vapply(ids, function(id) { r <- info_ind(id); a <- agregado(id, g, ano)
      paste0(fmt_valor(a$valor, r$fmt), if (isTRUE(a$n_x > 0)) "*" else "") }, character(1))
    nome <- if (g == "MT") "Mato Grosso" else if (recorte == "tipo") sprintf("%s · %s", g, TIPOS[[g]]) else g
    c(list(Grupo = nome), as.list(setNames(vals, ids)))
  })
  d <- bind_rows(lapply(linhas, tibble::as_tibble))
  cab <- function(id) { r <- info_ind(id)
    sprintf('<a href="%s">%s</a><div class="sub">%s · %s</div>', url_ind(id, prefixo), esc(r$rotulo_curto), esc(unid(r)),
            if (is.null(ano)) ano_ref(id) else ano) }
  cols <- c(list(Grupo = colDef(name = if (recorte == "tipo") "Tipo do M1 (rótulo provisório)" else "Bioma", minWidth = 220,
                                style = list(fontWeight = 600))),
            setNames(lapply(ids, function(id) colDef(header = HTML(cab(id)), html = TRUE, align = "right", minWidth = 120)), ids))
  tagList(reactable(d, compact = TRUE, sortable = FALSE, pagination = FALSE, wrap = TRUE, columns = cols),
          p(class = "nota-fonte", "Agregados: soma dos municípios, para os totais; razão das somas, para as proporções e médias; e variação das somas, para a dinâmica. ",
            "* O grupo contém municípios com X (sigilo); o valor considera apenas os municípios com valor publicado."))
}

resumo_tema <- function(dim, prefixo = "../indicadores/") {
  ids <- IND$id[IND$dim == dim]
  d <- bind_rows(lapply(ids, function(id) {
    r <- info_ind(id); f <- function(g) fmt_valor(agregado(id, g)$valor, r$fmt)
    tibble(Indicador = sprintf('<a href="%s%s.html">%s</a><div class="sub">%s</div>', prefixo, id, esc(r$rotulo), esc(unid(r))),
           Ano = as.character(ano_ref(id)), MT = f("MT"), `Amazônia` = f("Amazônia"), Cerrado = f("Cerrado"), Pantanal = f("Pantanal"),
           X = agregado(id, "MT")$n_x)
  }))
  reactable(d, compact = TRUE, pagination = FALSE, sortable = FALSE, wrap = TRUE,
            columns = list(Indicador = colDef(html = TRUE, minWidth = 240), Ano = colDef(align = "center", minWidth = 60),
                           MT = colDef(align = "right", name = "Mato Grosso"), `Amazônia` = colDef(align = "right"),
                           Cerrado = colDef(align = "right"), Pantanal = colDef(align = "right"),
                           X = colDef(align = "center", name = "Municípios com X")))
}

# ---- Navegação -------------------------------------------------------------------
navegacao_municipio <- function(mun_id) {
  P <- PERFIS
  if (!mun_id %in% P$id_municipio) P <- ordenar_pt(bind_rows(P, MUN[MUN$id_municipio == mun_id, ]))
  i <- match(mun_id, P$id_municipio)
  ant <- P[ifelse(i == 1, nrow(P), i - 1), ]; prox <- P[ifelse(i == nrow(P), 1, i + 1), ]
  div(class = "nav-mun",
      a(class = "btn btn-sm btn-outline-primary", href = paste0(ant$slug, ".html"), paste("←", ant$municipio)),
      tags$select(class = "form-select form-select-sm", `aria-label` = "Ir para outro município",
                  onchange = "if (this.value) window.location = this.value",
                  lapply(seq_len(nrow(P)), function(j) tags$option(value = paste0(P$slug[j], ".html"),
                         selected = if (P$id_municipio[j] == mun_id) NA else NULL, P$municipio[j]))),
      a(class = "btn btn-sm btn-outline-primary", href = paste0(prox$slug, ".html"), paste(prox$municipio, "→")))
}

navegacao_indicador <- function(id) {
  O <- IND[order(IND$ordem), ]; i <- match(id, O$id); prox <- O[ifelse(i == nrow(O), 1, i + 1), ]
  div(class = "nav-mun",
      a(class = "btn btn-sm btn-outline-primary", href = "index.html", "← Todos os indicadores"),
      tags$select(class = "form-select form-select-sm", `aria-label` = "Ir para outro indicador",
                  onchange = "if (this.value) window.location = this.value",
                  lapply(names(TEMAS), function(t) { g <- O[O$dim == t, ]
                    tags$optgroup(label = TEMAS[[t]], lapply(seq_len(nrow(g)), function(j)
                      tags$option(value = paste0(g$id[j], ".html"), selected = if (g$id[j] == id) NA else NULL, g$rotulo_curto[j]))) })),
      a(class = "btn btn-sm btn-outline-primary", href = paste0(prox$id, ".html"), paste(prox$rotulo_curto, "→")))
}

# ---- Mapas (sem camada de fundo externa) --------------------------------------
mapa_vazio <- function(altura) leaflet(height = altura, options = leafletOptions(zoomSnap = 0.25, attributionControl = FALSE))

js_clique <- function(prefixo) sprintf("function(el, x) { var map = this; map.eachLayer(function(l) {
  if (l.options && l.options.layerId) { l.on('click', function() { window.location = '%s' + l.options.layerId + '.html'; });
    l.on('mouseover', function() { l.setStyle({weight: 2.5}); }); l.on('mouseout', function() { l.setStyle({weight: 1}); }); } }); }", prefixo)

nota_sedes_mapa <- function() HTML('<div style="font-size:11px;background:#fff;padding:3px 7px;border-radius:4px;box-shadow:0 1px 3px rgba(0,0,0,.15)"><span style="display:inline-block;width:13px;height:10px;border:2px solid #111827;vertical-align:-1px;margin-right:4px"></span>sede de área-piloto</div>')

# Polígonos com e sem perfil (só os com perfil são clicáveis) e contorno das sedes dos pilotos
camadas_mun <- function(m, g, fill, rot, opac = 1) {
  perfil <- vapply(g$slug, tem_perfil, logical(1))
  if (any(!perfil)) m <- addPolygons(m, data = g[!perfil, ], fillColor = fill[!perfil], fillOpacity = opac, color = "#ffffff",
                                      weight = 0.6, label = lapply(rot[!perfil], HTML))
  if (any(perfil)) m <- addPolygons(m, data = g[perfil, ], layerId = ~slug, fillColor = fill[perfil], fillOpacity = opac,
                                     color = "#ffffff", weight = 1,
                                     label = lapply(paste0(rot[perfil], "<br><i>Clique para abrir o perfil.</i>"), HTML))
  sedes <- g[g$sede_piloto, ]
  addPolygons(m, data = sedes, fill = FALSE, color = "#111827", weight = 2.4, opacity = 1,
              options = pathOptions(interactive = FALSE))
}

mapa_municipio <- function(mun_id = NULL, altura = 360, prefixo = "", cor_por = c("bioma", "tipo")) {
  cor_por <- match.arg(cor_por)
  g <- GEO
  fill <- if (cor_por == "bioma") unname(COR_BIOMA[g$bioma]) else unname(COR_TIPO[g$tipo_m1])
  rot <- sprintf("<b>%s</b><br>%s · %s (%s, rótulo provisório)%s", esc(g$municipio), g$bioma, g$tipo_m1,
                 esc(unname(TIPOS[g$tipo_m1])), ifelse(g$sede_piloto, "<br>Sede de área-piloto", ""))
  m <- camadas_mun(mapa_vazio(altura), g, fill, rot, opac = 0.85)
  if (!is.null(mun_id)) m <- addPolygons(m, data = g[g$id_municipio %in% mun_id, ], fill = FALSE, color = COR[["sede"]],
                                         weight = 3.5, opacity = 1, options = pathOptions(interactive = FALSE))
  leg <- if (cor_por == "bioma") list(cores = unname(COR_BIOMA), rotulos = sprintf("%s (%d)", BIOMAS, as.integer(table(factor(MUN$bioma, BIOMAS)))), titulo = "Bioma (IBGE 1:250 mil)")
         else list(cores = unname(COR_TIPO), rotulos = sprintf("%s · %s (%d)", names(TIPOS), TIPOS, as.integer(table(factor(MUN$tipo_m1, names(TIPOS))))),
                   titulo = "Tipo do M1 (rótulos provisórios)")
  bb <- st_bbox(g)
  m |>
    addLegend("bottomright", colors = leg$cores, labels = leg$rotulos, title = leg$titulo, opacity = 0.9) |>
    addControl(nota_sedes_mapa(), position = "bottomleft") |>
    fitBounds(bb[["xmin"]], bb[["ymin"]], bb[["xmax"]], bb[["ymax"]]) |>
    htmlwidgets::onRender(js_clique(prefixo))
}

mapa_indicador <- function(id, altura = 460, prefixo = "../municipios/") {
  r <- info_ind(id); e <- escala_natural(r)
  u <- ULT$ultimos[ULT$ultimos$indicador == id, c("id_municipio", "valor", "sinal", "valor_calc", "ano")]
  g <- left_join(GEO, u, by = "id_municipio")
  v <- g$valor_calc * e$f
  vv <- v[is.finite(v)]
  pal_nome <- if (identical(r$origem, "seeg")) (if (identical(r$id, "seeg_remocoes")) "Blues" else "Reds")
              else if (isTRUE(r$sentido < 0)) "Reds" else "Greens"
  br <- unique(quantile(vv, probs = seq(0, 1, 0.2), na.rm = TRUE))
  pal <- if (length(br) >= 4) colorBin(pal_nome, domain = vv, bins = br, na.color = COR_ND)
         else if (length(unique(vv)) >= 2) colorNumeric(pal_nome, domain = vv, na.color = COR_ND)
         else function(x) rep("#7fb59a", length(x))
  fill <- ifelse(g$sinal == "X", COR_X, ifelse(g$sinal == "...", COR_ND, pal(v)))
  txt <- ifelse(g$sinal == "valor", paste0(fmt_valor(v, e$fmt), " (", g$ano, ")"), unname(SINAL_TXT[g$sinal]))
  rot <- sprintf("<b>%s</b><br>%s<br><span style='color:#6b7280'>%s · %s%s</span>", esc(g$municipio), esc(txt), g$bioma, g$tipo_m1,
                 ifelse(g$sede_piloto, " · sede de área-piloto", ""))
  m <- camadas_mun(mapa_vazio(altura), g, fill, rot, opac = 0.92)
  if (length(br) >= 4) {
    m <- addLegend(m, "bottomright", pal = pal, values = vv, title = esc(unid(r)), opacity = 0.9,
                   labFormat = function(type, cuts, p) {
                     if (type == "bin") { n <- length(cuts); paste0(fmt_valor(cuts[-n], e$fmt), " – ", fmt_valor(cuts[-1], e$fmt)) }
                     else fmt_valor(cuts, e$fmt) })
  } else if (length(unique(vv)) >= 2) {
    m <- addLegend(m, "bottomright", pal = pal, values = vv, title = esc(unid(r)), opacity = 0.9,
                   labFormat = labelFormat(transform = function(x) x, big.mark = "."))
  }
  sin <- c(if (any(g$sinal == "X")) "X", if (any(g$sinal == "...")) "...")
  if (length(sin)) m <- addLegend(m, "bottomleft", colors = c(X = COR_X, "..." = COR_ND)[sin], labels = unname(SINAL_TXT[sin]),
                                  opacity = 1, title = "Sem valor")
  bb <- st_bbox(g)
  m |> addControl(nota_sedes_mapa(), position = "topright") |>
    fitBounds(bb[["xmin"]], bb[["ymin"]], bb[["xmax"]], bb[["ymax"]]) |>
    htmlwidgets::onRender(js_clique(prefixo))
}
