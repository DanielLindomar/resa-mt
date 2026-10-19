# =============================================================================
# 09_testar_funcoes.R - Observatório RESA-MT
# Chama cada função de R/funcoes.R com um município-sede e alguns indicadores e
# para com erro se alguma falhar ou se algum X, – ou ... aparecer como número.
# Não grava nada. Rodar a partir da raiz do repositório, depois dos scripts 01 e 02:
#   "${RSCRIPT:-Rscript}" scripts/09_testar_funcoes.R
# =============================================================================

args <- commandArgs(trailingOnly = FALSE)
arq <- sub("^--file=", "", args[grep("^--file=", args)])
raiz <- if (length(arq)) normalizePath(file.path(dirname(arq), ".."), winslash = "/") else normalizePath(".", winslash = "/")
Sys.setenv(QUARTO_PROJECT_DIR = raiz)
source(file.path(raiz, "R", "funcoes.R"))

html_de <- function(x) as.character(htmltools::renderTags(x)$html)
ok <- function(rotulo, expr) {
  r <- tryCatch({ force(expr); TRUE }, error = function(e) { message("ERRO em ", rotulo, ": ", conditionMessage(e)); FALSE })
  cat(if (r) "  ok  " else "  ERRO ", rotulo, "\n", sep = "")
  invisible(r)
}

JUARA <- 5105101L
res <- c(
  ok("formatação pt-BR", stopifnot(num(1234567.891, 1) == "1.234.567,9", fmt_valor(12.345, "pct1") == "12,3%",
                                    num(1164.5) == "1.165", num(964.5) == "965", num(-2.5) == "-3", num(0.125, 2) == "0,13",
                                    identical(sort_pt(c("Vila Rica", "Água Boa", "Cáceres", "Cuiabá")), c("Água Boa", "Cáceres", "Cuiabá", "Vila Rica")),
                                    fmt_celula(NA, "X", "int") == "X", fmt_celula(NA, TRACO, "int") == TRACO,
                                    fmt_celula(NA, "...", "pct1") == "...")),
  ok("html_celula com dica", stopifnot(grepl("X (sigilo IBGE)", html_celula(NA, "X", "int"), fixed = TRUE))),
  ok("consultas", { stopifnot(nrow(info_ind("estab_af")) == 1, ano_ref("seeg_mut") == 2024,
                              length(ids_grupo("bioma", "Pantanal")) == 4, length(ids_grupo("tipo", "T1")) == 74,
                              agregado("estab_af", "MT")$valor == 81635, nrow(SEDES) == 3)
                    s <- resumo_ind("pct_estab_46504", JUARA); stopifnot(!is.null(s$pos_bioma)) }),
  ok("elementos de página", html_de(tagList(faixa_versao(), aviso_municipio(), nota_correcao_prodes(), chip_bioma("Amazônia"),
                                              chip_tipo("T3"), selo_situacao("andamento"), selo_conciliacao(), legenda_sinais(),
                                              cartao_kpi("a", "1", "b"), fonte_rodape(), fonte_rodape(c("estab_af", "n_pa")),
                                              figura_m1("fig6_censo_incra_final.png", "Censo e INCRA")))),
  ok("kpi e grade_kpis", html_de(grade_kpis(JUARA))),
  ok("kpi com X", { u <- ULT$ultimos[ULT$ultimos$sinal == "X", ][1, ]
                    h <- html_de(kpi(u$indicador, u$id_municipio)); stopifnot(grepl("sinal-x", h)) }),
  ok("svg_sparkline / svg_posicao / serie_mun_medianas", { s <- SER[SER$indicador == "seeg_mut" & SER$id_municipio == JUARA, ]
     stopifnot(nzchar(svg_sparkline(s$ano, s$valor_calc)), nzchar(serie_mun_medianas("seeg_mut", JUARA, "Juara")))
     r <- resumo_ind("area_media_af", JUARA); stopifnot(nzchar(svg_posicao(r$vals_bioma, as.character(JUARA), r$med_mt, "dec1"))) }),
  ok("series_agregados (tipo e bioma)", stopifnot(nzchar(series_agregados("seeg_emissao_bruta", "tipo")),
                                                  nzchar(series_agregados("seeg_mut", "bioma", incluir_mt = TRUE)))),
  ok("ranking MT, bioma e tipo", html_de(tagList(ranking("pct_area_46504"), ranking("estab_af", "bioma", "Pantanal"),
                                                 ranking("var_estab_0617", "tipo", "T4")))),
  ok("tabela_dim (todos os temas)", for (t in names(TEMAS)) html_de(tabela_dim(t, JUARA, "Juara"))),
  ok("tabela_indicador", html_de(tabela_indicador("pct_area_46504"))),
  ok("tabela_agregados", html_de(tabela_agregados("pct_area_46504"))),
  ok("tabela_por_grupo", html_de(tabela_por_grupo(c("pct_estab_46504", "pct_area_46504", "var_estab_0617")))),
  ok("resumo_tema", for (t in names(TEMAS)) html_de(resumo_tema(t))),
  ok("navegação", html_de(tagList(navegacao_municipio(JUARA), navegacao_indicador("n_pa")))),
  ok("perfis em ordem alfabética do português", stopifnot(PERFIS$municipio[1] == "Acorizal", PERFIS$municipio[2] == "Água Boa")),
  ok("mapa_municipio (bioma e tipo)", { mapa_municipio(JUARA); mapa_municipio(NULL, cor_por = "tipo") }),
  ok("mapa_indicador (com X e com ...)", { mapa_indicador("pct_area_46504"); mapa_indicador("pct_irrigacao_af"); mapa_indicador("seeg_remocoes") }),
  ok("nenhum X, – ou ... com número em ULT", stopifnot(all(is.na(ULT$ultimos$valor[ULT$ultimos$sinal != "valor"])),
                                                     all(ULT$ultimos$valor_calc[ULT$ultimos$sinal == TRACO] == 0)))
)
cat(sprintf("\n%d de %d testes passaram.\n", sum(res), length(res)))
if (!all(res)) quit(status = 1)
