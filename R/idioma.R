# =============================================================================
# R/idioma.R - idioma da renderização (português por padrão; inglês na árvore en/)
# =============================================================================
# A versão em inglês é um projeto Quarto próprio em en/, com os mesmos nomes de
# arquivo do site em português. As funções de R/ servem aos dois projetos: EN
# (definido em R/funcoes.R) é TRUE quando o projeto em renderização é en/.
#
# Os dados internos continuam em português ("Amazônia", T1, "valor"...): comparações,
# chaves e nomes de coluna não mudam; só o que aparece na tela é traduzido.
#
#   tr(pt, en)                texto do idioma da renderização
#   nome_bioma(b)             nome do bioma na tela ("Amazônia" vira "Amazon" em inglês)
#   dic(x)                    valor de dado na tela, por i18n/dic_*.csv (colunas pt, en);
#                             em inglês, para com erro se faltar a tradução
#   sobrepor_en(df, arq, ch)  troca as colunas de texto de df pelas de i18n/<arq>, casando
#                             pela coluna-chave ch; a coluna <ch>__en, se houver, traduz a
#                             própria chave; em português, devolve df sem mudança
#   conv_num_en(s)            "1.234,5" vira "1,234.5" em texto já formatado
#   ordinal(n)                1º, 2º... ou 1st, 2nd...
#   data_en(x)                "2026-10-19" ou "19/10/2026" vira "19 Oct 2026" (só para o inglês)
#   ARQ_REL                   caminho de arquivos/ visto de uma página em subpasta
#                             (arquivos/ existe só uma vez, na raiz do site publicado)
# =============================================================================

tr <- function(pt, en) if (EN) en else pt

# Textos das tabelas interativas (reactable): em inglês, os padrões do pacote.
options(reactable.language = if (EN) reactable::reactableLang() else reactable::reactableLang(
  sortLabel = "Ordenar por {name}", filterPlaceholder = "Filtrar", filterLabel = "Filtrar {name}",
  searchPlaceholder = "Buscar", searchLabel = "Buscar na tabela", noData = "Nenhum registro encontrado",
  pageNext = "Próxima", pagePrevious = "Anterior", pageNumbers = "{page} de {pages}",
  pageInfo = "{rowStart}–{rowEnd} de {rows} linhas", pageSizeOptions = "Mostrar {rows}",
  pageNextLabel = "Próxima página", pagePreviousLabel = "Página anterior",
  pageNumberLabel = "Página {page}", pageJumpLabel = "Ir para a página",
  pageSizeOptionsLabel = "Linhas por página", groupExpandLabel = "Expandir grupo",
  detailsExpandLabel = "Mostrar detalhes", selectAllRowsLabel = "Selecionar todas as linhas",
  selectAllSubRowsLabel = "Selecionar todas as linhas do grupo", selectRowLabel = "Selecionar linha"))

ARQ_REL <- tr("../arquivos/", "../../arquivos/")

nome_bioma <- function(b) if (EN) ifelse(b == "Amazônia", "Amazon", b) else b

ler_i18n <- function(arq) tibble::as_tibble(data.table::fread(file.path(RAIZ, "i18n", arq), encoding = "UTF-8",
                                                              colClasses = "character", na.strings = NULL))

DIC_EN <- if (EN) local({
  arqs <- list.files(file.path(RAIZ, "i18n"), pattern = "^dic_.*[.]csv$")
  d <- do.call(rbind, lapply(arqs, ler_i18n))
  d <- unique(d[, c("pt", "en")])
  if (anyDuplicated(d$pt)) stop("i18n/dic_*.csv: mais de uma tradução para: ", paste(d$pt[duplicated(d$pt)], collapse = " | "))
  stats::setNames(d$en, d$pt)
})

dic <- function(x) {
  if (!EN) return(x)
  x <- as.character(x)
  com_valor <- !is.na(x) & nzchar(x)
  falta <- setdiff(unique(x[com_valor]), names(DIC_EN))
  if (length(falta)) stop("sem tradução em i18n/dic_*.csv: ", paste(falta, collapse = " | "))
  x[com_valor] <- unname(DIC_EN[x[com_valor]])
  x
}

sobrepor_en <- function(df, arq, chave) {
  if (!EN) return(df)
  en <- ler_i18n(arq)
  if (anyDuplicated(en[[chave]])) stop("i18n/", arq, ": chave repetida")
  i <- match(as.character(df[[chave]]), en[[chave]])
  if (anyNA(i)) stop("i18n/", arq, ": sem tradução para: ", paste(unique(df[[chave]][is.na(i)]), collapse = " | "))
  for (col in setdiff(names(en), c(chave, paste0(chave, "__en")))) {
    if (!col %in% names(df)) stop("i18n/", arq, ": coluna desconhecida: ", col)
    novo <- en[[col]][i]
    com_texto <- !is.na(df[[col]]) & nzchar(as.character(df[[col]]))
    if (any(com_texto & !nzchar(novo))) stop("i18n/", arq, ": tradução vazia na coluna ", col, " para: ",
                                             paste(df[[chave]][com_texto & !nzchar(novo)], collapse = " | "))
    df[[col]] <- ifelse(com_texto, novo, df[[col]])
  }
  if (paste0(chave, "__en") %in% names(en)) df[[chave]] <- en[[paste0(chave, "__en")]][i]
  df
}

# Troca os separadores só entre algarismos: não mexe em pontuação de frase nem em "[a; b]".
conv_num_en <- function(s) {
  s <- gsub("(?<=\\d)\\.(?=\\d)", "\u0001", s, perl = TRUE)
  s <- gsub("(?<=\\d),(?=\\d)", ".", s, perl = TRUE)
  gsub("\u0001", ",", s, fixed = TRUE)
}

# Posição no ranking: "14th of 76". A ordem (1st = largest) vem explicada na página.
posicao_en <- function(p, n) sprintf("%s of %d", ordinal(p), n)
# Sinal "–" no meio da frase: "none (–, true zero) received technical guidance". Em português, o texto fica como está.
nenhum_en <- function(x) if (EN && startsWith(x, paste0(TRACO, " ("))) sub(paste0(TRACO, " \\((.*)\\)$"), paste0("none (", TRACO, ", \\1)"), x) else x
ordinal <- function(n) {
  if (!EN) return(paste0(n, "º"))
  d2 <- n %% 100L; d1 <- n %% 10L
  suf <- ifelse(d2 %in% 11:13, "th", ifelse(d1 == 1L, "st", ifelse(d1 == 2L, "nd", ifelse(d1 == 3L, "rd", "th"))))
  paste0(n, suf)
}

MESES_EN <- c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
data_en <- function(x) {
  x <- as.character(x)
  iso <- grepl("^\\d{4}-\\d{2}-\\d{2}$", x); br <- grepl("^\\d{2}/\\d{2}/\\d{4}$", x)
  ano <- ifelse(iso, substr(x, 1, 4), substr(x, 7, 10))
  mes <- as.integer(ifelse(iso, substr(x, 6, 7), substr(x, 4, 5)))
  dia <- as.integer(ifelse(iso, substr(x, 9, 10), substr(x, 1, 2)))
  ifelse(iso | br, paste(dia, MESES_EN[mes], ano), x)
}
