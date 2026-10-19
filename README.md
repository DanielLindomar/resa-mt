# Observatório RESA-MT

Site de resultados do Projeto RESA nº 115, *Viabilidade Econômica de Assentamentos Rurais nos Três Biomas de Mato Grosso: Análise Integrada de Sustentabilidade, Carbono e Dinâmica Territorial*. Execução: UNEMAT. Apoio: Instituto Clima e Sociedade (iCS), Doação D-25-02928.

Endereço previsto: https://daniellindomar.github.io/resa-mt/ (versão preliminar para a equipe; todas as páginas levam `noindex, nofollow`, o `robots.txt` pede `Disallow: /` e o site não gera `sitemap.xml`).

## Como atualizar

Tudo roda na raiz do repositório, no Git Bash, **nesta ordem**. Cada script para com erro se uma checagem falhar; nesse caso, corrija antes de seguir.

### 0. Informar onde estão as fontes

Os scripts que leem as bases do projeto (01, 04, 05 e 06) usam a variável de ambiente `RESA_FONTES` ou o arquivo `config.local.toml` (fora do controle de versão), com uma linha:

```toml
resa_fontes = "<raiz do projeto RESA>"
```

O caminho nunca vai escrito em código nem em arquivo versionado. Os demais scripts só leem o próprio repositório.

### 1. Preparar os dados e as páginas

```bash
export RESA_FONTES="<raiz do projeto RESA>"      # ou config.local.toml
R="${RSCRIPT:-Rscript}"                          # Rscript no PATH, ou o caminho dele na variável RSCRIPT

python -I scripts/01_preparar_dados.py          # dados_site/*.csv, downloads em arquivos/dados e arquivos/geo, figuras PNG do M1
"$R" scripts/02_converter_rds.R                 # dados_site/*.rds lidos por R/funcoes.R
python -I scripts/03_gerar_stubs.py             # municipios/<slug>.qmd (141) e indicadores/<id>.qmd (34)
python -I scripts/04_preparar_resultados.py     # dados_site/resultados/ e resultados/figuras/*.svg (M1, artigos B e C)
python -I scripts/05_preparar_literatura.py     # dados_site/literatura/ e arquivos/literatura/
python -I scripts/06_preparar_oe1.py            # objetivos/dados/ (PRODES municipal do OE1)
"$R" scripts/09_testar_funcoes.R                # testa as funções de R/funcoes.R
```

| Passo | Lê | Grava |
|---|---|---|
| 01 | fontes do projeto (M1, Censo 2017, SIPRA, SEEG, PRODES) | `dados_site/*.csv`, `arquivos/dados/`, `arquivos/geo/`, `resultados/figuras/m1/` |
| 02 | saídas do 01 | `dados_site/serie.rds`, `ultimos.rds`, `geo_mt.rds`, `agregados.rds` |
| 03 | `dados_site/municipios.csv` e `indicadores.csv` | stubs de `municipios/` e `indicadores/` (só arquivos com a marca de stub) |
| 04 | fontes do projeto e saídas do 01 | `dados_site/resultados/`, `resultados/figuras/*.svg` |
| 05 | fontes do projeto (só metadados da literatura) | `dados_site/literatura/`, `arquivos/literatura/` |
| 06 | PRODES municipal baixado do TerraBrasilis e saídas do 01 | `objetivos/dados/` |
| 09 | `dados_site/` | nada (só testa) |

`scripts/03_gerar_paginas.py` é só um atalho para o `03_gerar_stubs.py`. Por padrão saem os 141 perfis; `--municipios sedes` gera só os das 3 sedes. As páginas das áreas-piloto são escritas à mão a partir de `pilotos/_modelo_piloto.qmd`.

### 2. Renderizar

```bash
rm -rf _freeze _site
quarto render          # se o quarto não estiver no PATH, use o caminho completo do quarto.exe
```

O render completo, sem `_freeze/`, leva cerca de 20 minutos (141 perfis e 34 páginas de indicador); com `_freeze/` em dia, cerca de 6 minutos. O site tem 200 páginas. Rode **um render por vez**: renders em paralelo na mesma pasta dão erros transitórios (`municipios/*_files`, `site_libs`).

O `execute: freeze: auto` guarda os resultados em `_freeze/` e só executa de novo a página cujo `.qmd` mudou. **Depois de mudar `dados_site/`, `R/*.R` ou um modelo (`_perfil.qmd`, `_indicador.qmd`, `_modelo_piloto.qmd`)**, apague `_freeze/` (ou a subpasta da seção) antes do render, ou renderize as páginas afetadas uma a uma com `quarto render pasta/pagina.qmd`, que sempre executa o código. Páginas que montam links a partir dos arquivos existentes (`index.qmd`, `dados/index.qmd`, `pilotos/`, `objetivos/`) também precisam de render novo quando surgem páginas ou downloads.

### 3. Conferir antes de publicar

```bash
python -I scripts/07_checar_publicacao.py
```

Varre **todo** o repositório, inclusive `_site/` e `_freeze/` (conteúdo e nome dos arquivos). Só ficam fora `.git/` e as pastas ocultas locais da raiz (como `.quarto/`), que o `.gitignore` tira do controle de versão e o Quarto não publica. São cinco partes:

1. **Termos proibidos:** link ou ID do Google Drive, a pasta do Drive, e-mail institucional ou pessoal, caminho local, CPF ou CNPJ, bases comerciais licenciadas e outros termos vetados pelo projeto (estes ficam no script só como hash), marcas de rascunho dos manuscritos e a série manual antiga do PRODES.
2. **Sinais do IBGE:** nenhum X, – ou ... vira 0, número ou célula vazia em `dados_site/`, nos downloads, nas tabelas e nos mapas das páginas e nos `.rds`; com `RESA_FONTES`, toda célula X da fonte do IBGE continua X no download.
3. **Alinhamento linha a linha:** em cada tabela com municípios e indicadores (índice de municípios, páginas de indicador, Posse, Dados e os 141 perfis) e nos mapas das páginas de indicador, o número guardado e o texto mostrado são os do próprio município em `valores.csv`.
4. **Links internos** de `_site/` (páginas, arquivos, âncoras e cliques dos mapas) e nenhuma figura publicada sem uso.
5. **Elementos obrigatórios** de cada página (meta `noindex, nofollow`, título, rodapé oficial com só o logo da UNEMAT, faixa de versão, nenhum NA ou NaN no texto), `robots.txt` com `Disallow: /` e nenhum `sitemap.xml`.

Os falsos positivos legítimos ficam na lista `EXCECOES` do script, cada um com o motivo. Rode com `RESA_FONTES` definido para incluir a conferência contra a fonte do IBGE. Só publique com a saída "Pronto para publicar".

### 4. Publicar (só com o aval da coordenação)

`quarto publish gh-pages`. Registre a mudança em "Novidades" (`index.qmd`) e faça commit no ramo `main`.

O `.gitignore` deixa fora do controle de versão, por padrão, os dados com licença de redistribuição em conferência: `dados_site/valores.csv`, `dados_site/serie.rds`, `dados_site/ultimos.rds` (têm a série municipal do SEEG) e `objetivos/dados/` (PRODES por município). Eles são gerados pelos passos 01, 02 e 06; por isso, quem clonar o repositório precisa rodar o passo 1 antes do render. Se o repositório for privado, a coordenação pode tirar essas linhas do `.gitignore`.

## Estrutura

| Pasta/arquivo | Conteúdo |
|---|---|
| `scripts/01` a `06`, `07`, `09` | Preparo dos dados, stubs, conferência de publicação e testes (ver a tabela acima) |
| `R/funcoes.R` | Funções comuns (formatação pt-BR, sinais, KPIs, tabelas, mapas, gráficos SVG); o cabeçalho documenta cada uma |
| `R/pag_municipios.R` | Perfis, índice de municípios e páginas de indicador |
| `R/pag_resultados.R` | Páginas de Resultados (tipologia, posse, emissões, dinâmica) |
| `R/pag_objetivos.R` | Objetivos (OE1 a OE6) e áreas-piloto |
| `R/pag_inicio.R` | Página inicial, Literatura, Dados e Biblioteca |
| `R/idioma.R` | Textos em português das tabelas interativas |
| `municipios/_perfil.qmd`, `indicadores/_indicador.qmd` | Modelos dos 141 perfis e das 34 páginas de indicador (os stubs só incluem o modelo) |
| `pilotos/_modelo_piloto.qmd` | Modelo comum das 3 páginas de áreas-piloto |
| `dados_site/` | Dados lidos na renderização (não são publicados como arquivos) |
| `dados_site/resultados/` | Números do M1 (subconjunto de `NUMEROS_FINAIS`, copiado sem recálculo), emissões, validação contra o PRODES, dinâmica 2006–2017 |
| `dados_site/literatura/` | Metadados das referências e dos estudos do OE4 |
| `objetivos/dados/` | PRODES municipal usado no OE1 e no desmatamento por tipo (não é download do site; fora do controle de versão) |
| `arquivos/` | Downloads publicados: CSV com dicionário (`dados/`, `literatura/`) e malha GeoJSON (`geo/`) |
| `resultados/figuras/` | Figuras finais do Manuscrito 1 usadas nas páginas (PNG em `m1/`; SVG); as demais não são copiadas |
| `assets/` | Logo da UNEMAT, favicon, meta `noindex` e glossário |
| `robots.txt` | Pede aos buscadores que não percorram o site (`Disallow: /`) |

### Dados do site (`dados_site/`)

| Arquivo | Conteúdo |
|---|---|
| `municipios.csv` | 141 municípios: código, nome, slug, bioma (IBGE 1:250 mil, 2019), % de cada bioma, tipo do M1 e rótulo provisório, sede de piloto |
| `indicadores.csv` | 34 indicadores: tema, rótulos, unidade, formato, ano, fonte, regra de agregação, cálculo em palavras, notas |
| `valores.csv` | Formato longo: `id_municipio, indicador, ano, valor, sinal`. A coluna `valor` traz o número ou, sem número, o próprio sinal. Mudança de uso da terra e remoções do SEEG de 1970 a 1989 levam `...` (o SEEG só estima esses setores a partir de 1990) |
| `agregados.csv` | MT, biomas e tipos do M1, por indicador e ano (sem as linhas em que todos os municípios têm `...`) |
| `totais_mt.csv` | Totais estaduais oficiais (Censo 2017, SIPRA, SEEG, PRODES) |
| `seeg_mt_setor.csv`, `prodes_mt_taxa.csv`, `prodes_mt_bioma.csv` | Séries estaduais (SEEG por setor, com `...` na mudança de uso da terra antes de 1990; PRODES oficial, TerraBrasilis) |
| `dinamica_2006_2017.csv` | Estabelecimentos e área (todos) em 2006 e 2017, por município |
| `m1_tipos_perfis.csv`, `m1_fatores.csv` | Perfis dos cinco tipos e nomes dos fatores do Manuscrito 1 |
| `pilotos.csv` | As três áreas-piloto, só com identificação |
| `fontes_licencas.csv` | Fontes, uso no site e licença |
| `*.rds` | Gerados pelo script 02 a partir dos CSV |

## Regras de conteúdo

Valem para todo arquivo do repositório, inclusive scripts e este README.

- **Sinais do IBGE.** X (sigilo), – (zero absoluto) e ... (não disponível) nunca viram 0 nem célula vazia. Nos dados e nos downloads, a célula do número traz o próprio sinal, como nas tabelas do IBGE, e a coluna `sinal` (ou `sinal_<variável>`) repete o sinal. No mapa, X aparece em cinza com a dica "X (sigilo IBGE)". Em Araguainha, a irrigação não tem registro na API do SIDRA e vai como `...`, com nota.
- **Rótulos de variável** pelo significado conferido: `estagrorechidri` é energia elétrica; `estagroveic` e `vecestagro` são semeadeiras.
- **Categoria 46504 do Censo 2017:** sempre "concessionário(a) ou assentado(a) aguardando titulação definitiva (Censo 2017)", nunca só "assentados". Nos downloads, as colunas da categoria levam o código (`*_46504`).
- **Tipologia:** só a do Manuscrito 1 (k = 5), com a indicação "rótulo provisório" até a aprovação dos autores (nos downloads, a coluna `rotulo_status`). A tipologia anterior (k = 6) aparece só em nota de método, como versão superada. Os Artigos A, B e C entram refeitos pelos tipos do M1; no Artigo A, o desmatamento vem do PRODES municipal oficial.
- **Bioma:** IBGE 1:250 mil (2019) no site inteiro (76 Amazônia, 61 Cerrado, 4 Pantanal).
- **PRODES:** só a série oficial do TerraBrasilis (baixada em 19/10/2026), com a nota de correção.
- **Áreas-piloto:** só identificação, sem número de famílias ou área, sem polígonos; selo "números em conciliação".
- **Fora do site:** dados pessoais (nomes, CPF/CNPJ, CAR por imóvel, fotos de pessoas, relações nominais, camadas estaduais com dados de proprietários); bases comerciais licenciadas de mercado financeiro e de créditos de carbono; textos integrais de manuscritos e artigos; orçamento, documentos da bolsa, questionários em rascunho, fotos de campo, drone e LiDAR; IDs do Google Drive, e-mails e caminhos locais.
- **Números:** sempre com fonte, unidade e ano, em formato pt-BR (vírgula decimal, ponto de milhar), arredondados com meio para cima (como no M1). Nomes de municípios em ordem alfabética do português (`ordem_pt()` em `R/funcoes.R`).
- **Literatura:** só metadados; o método aparece só pelas contagens das bases e pelas listas finais. A tabela dos 38 estudos do OE4 traz só Estudo, Local (bioma), Público, Arranjo e DOI, sem números.
- **SEEG municipal:** aparece nas páginas, mas fica fora dos downloads até a conferência da licença.

## Observação técnica

A política de Controle de Aplicativos do Windows bloqueia as DLLs de alguns pacotes R (`tzdb`/`readr`, `S7`, `ggplot2`). Por isso o site usa `data.table::fread` para CSV, `sf`, `leaflet`, `reactable` e `htmltools`, e desenha os gráficos em SVG. O Python roda com `python -I`.
