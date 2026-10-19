# =============================================================================
# 02_converter_rds.R - Observatório RESA-MT
# Converte as saídas do script 01 (CSV e GeoJSON) nos .rds que R/funcoes.R lê.
# Não lê nada fora do repositório.
#
# Rodar a partir da raiz do repositório, depois do script 01 (Rscript no PATH ou na variável RSCRIPT):
#   "${RSCRIPT:-Rscript}" scripts/02_converter_rds.R
#
# Em valores.csv, a coluna valor traz o número (ponto decimal) ou, quando não há número, o próprio
# sinal (X, – ou ...), como nas tabelas do IBGE. Aqui ela vira número (NA quando há sinal).
#
# Grava em dados_site/:
#   serie.rds     tibble: id_municipio, indicador, ano, valor, sinal, valor_calc
#                 (valor_calc = valor; 0 quando o sinal é "–"; NA para X e ...)
#   ultimos.rds   list(ano_ref = tibble(indicador, ano_ref),
#                      ultimos = serie no ano de referência de cada indicador)
#   geo_mt.rds    sf (EPSG:4326): id_municipio, municipio, slug, bioma, tipo_m1, rotulo_m1, sede_piloto
#   agregados.rds tibble: agregados.csv (MT, biomas e tipos do M1)
# Para com erro se alguma checagem falhar.
# =============================================================================

suppressPackageStartupMessages({ library(dplyr); library(sf); library(data.table) })

args <- commandArgs(trailingOnly = FALSE)
arq <- sub("^--file=", "", args[grep("^--file=", args)])
RAIZ <- if (length(arq)) normalizePath(file.path(dirname(arq), ".."), winslash = "/") else normalizePath(".", winslash = "/")
ds  <- function(...) file.path(RAIZ, "dados_site", ...)
ler <- function(f, ...) tibble::as_tibble(data.table::fread(f, encoding = "UTF-8", ...))
TRACO <- "\u2013"
erro <- function(...) stop(sprintf(...), call. = FALSE)

IND <- ler(ds("indicadores.csv"), na.strings = "")
MUN <- ler(ds("municipios.csv"))
SER <- ler(ds("valores.csv"), na.strings = NULL, colClasses = list(character = c("indicador", "sinal", "valor")))
if (any(SER$valor[SER$sinal != "valor"] != SER$sinal[SER$sinal != "valor"])) erro("célula X, – ou ... sem o próprio sinal na coluna valor")
if (any(SER$valor == "")) erro("célula vazia na coluna valor")
SER <- SER |>
  mutate(id_municipio = as.integer(id_municipio), ano = as.integer(ano),
         valor = ifelse(sinal == "valor", suppressWarnings(as.numeric(valor)), NA_real_),
         valor_calc = ifelse(sinal == "valor", valor, ifelse(sinal == TRACO, 0, NA_real_)))

# Checagens
if (nrow(MUN) != 141) erro("municipios.csv deveria ter 141 linhas (tem %d)", nrow(MUN))
if (nrow(IND) != 34) erro("indicadores.csv deveria ter 34 linhas (tem %d)", nrow(IND))
if (!all(SER$sinal %in% c("valor", "X", TRACO, "..."))) erro("sinal fora do vocabulário")
if (any(!is.na(SER$valor[SER$sinal != "valor"]))) erro("célula X, – ou ... com número")
if (any(is.na(SER$valor[SER$sinal == "valor"]))) erro("célula 'valor' sem número")
if (!setequal(unique(SER$indicador), IND$id)) erro("indicadores de valores.csv diferentes de indicadores.csv")
saveRDS(SER, ds("serie.rds"))

ano_ref <- transmute(IND, indicador = id, ano_ref = as.integer(ano_ref))
ultimos <- SER |> inner_join(ano_ref, by = "indicador") |> filter(ano == ano_ref) |> select(-ano_ref)
cont <- count(ultimos, indicador)
if (any(cont$n != 141)) erro("ultimos: algum indicador sem 141 municípios")
saveRDS(list(ano_ref = ano_ref, ultimos = ultimos), ds("ultimos.rds"))

geo <- st_read(file.path(RAIZ, "arquivos", "geo", "mt_municipios.geojson"), quiet = TRUE) |>
  mutate(id_municipio = as.integer(id_municipio), sede_piloto = as.logical(sede_piloto)) |>
  select(id_municipio, municipio, slug, bioma, tipo_m1, rotulo_m1, sede_piloto)
geo <- st_make_valid(geo)
if (nrow(geo) != 141 || !setequal(geo$id_municipio, MUN$id_municipio)) erro("malha sem os 141 municípios")
saveRDS(geo, ds("geo_mt.rds"))

agr <- ler(ds("agregados.csv"), na.strings = "")
saveRDS(agr, ds("agregados.rds"))

cat(sprintf("serie.rds: %d linhas | ultimos.rds: %d linhas | geo_mt.rds: %d polígonos | agregados.rds: %d linhas\n",
            nrow(SER), nrow(ultimos), nrow(geo), nrow(agr)))
cat(sprintf("Sinais em serie.rds: %s\n", paste(names(table(SER$sinal)), table(SER$sinal), sep = " = ", collapse = "; ")))
