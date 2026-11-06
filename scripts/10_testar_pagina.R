# =============================================================================
# scripts/10_testar_pagina.R - executa os blocos de R de uma página, sem o Quarto
# =============================================================================
# Serve para conferir uma página (ou a versão em inglês dela) sem renderizar o site.
# Os renders em paralelo na mesma pasta dão erro; este script pode rodar ao mesmo tempo.
#
#   Rscript --vanilla scripts/10_testar_pagina.R en/resultados/posse.qmd [saida.md]
#
# Expande {{< include ... >}}, define QUARTO_PROJECT_DIR como o Quarto faria, executa
# blocos e código em linha e para com erro no primeiro problema. Sem erro, grava o
# resultado em [saida.md] (se informado) e, nas páginas de en/, lista as linhas que ainda
# parecem estar em português (é só uma pista; a conferência final é a do script 08).
# =============================================================================
args <- commandArgs(TRUE)
if (!length(args)) stop("informe a página: Rscript scripts/10_testar_pagina.R en/resultados/posse.qmd [saida.md]")
arq <- normalizePath(args[1], winslash = "/", mustWork = TRUE)

proj <- dirname(arq)
while (!file.exists(file.path(proj, "_quarto.yml"))) {
  if (dirname(proj) == proj) stop("_quarto.yml não encontrado acima de ", arq)
  proj <- dirname(proj)
}
Sys.setenv(QUARTO_PROJECT_DIR = proj)
setwd(dirname(arq))

expandir <- function(linhas) {
  saida <- character()
  for (l in linhas) {
    m <- regmatches(l, regexec("^\\{\\{< include (\\S+) >\\}\\}\\s*$", l))[[1]]
    saida <- c(saida, if (length(m) == 2) expandir(readLines(m[2], encoding = "UTF-8", warn = FALSE)) else l)
  }
  saida
}
texto <- enc2utf8(expandir(readLines(arq, encoding = "UTF-8", warn = FALSE)))

# Sem o cabeçalho YAML e com os blocos sem saída de código, como no site
fim_yaml <- which(texto == "---")
if (length(fim_yaml) >= 2 && fim_yaml[1] == 1) texto <- texto[-seq_len(fim_yaml[2])]
suppressPackageStartupMessages(library(knitr))
knitr::opts_knit$set(rmarkdown.pandoc.to = "html", progress = FALSE, verbose = FALSE)
knitr::opts_chunk$set(echo = FALSE, warning = FALSE, message = FALSE, error = FALSE)
saida <- knitr::knit(text = texto, quiet = TRUE, envir = new.env(parent = globalenv()))

if (length(args) >= 2) writeLines(saida, args[2], useBytes = TRUE)

if (basename(proj) == "en") {
  linhas <- strsplit(saida, "\n", fixed = TRUE)[[1]]
  linhas <- gsub("<script\\b.*?</script>|<style\\b.*?</style>|<[^>]+>", " ", linhas, perl = TRUE)
  suspeitas <- grep("\\b(não|são|também|através|município|municípios|estabelecimentos|agricultura|porém|além|segundo|para os|para as|dos|das|uma|com o|com a|pelo|pela)\\b",
                    linhas, value = TRUE, ignore.case = TRUE, perl = TRUE)
  suspeitas <- substr(trimws(suspeitas), 1, 200)
  cat(sprintf("%s: ok; %d linha(s) ainda parecem em português\n", args[1], length(suspeitas)))
  if (length(suspeitas)) cat(paste0("  ", utils::head(suspeitas, 40)), sep = "\n")
} else cat(args[1], ": ok\n", sep = "")
