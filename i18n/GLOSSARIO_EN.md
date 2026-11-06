# Versão em inglês do Observatório RESA-MT: glossário e regras

Fonte única da terminologia e das regras da tradução. Os termos seguem o Abstract e os Highlights do Manuscrito 1 (inglês britânico; "2017 Agricultural Census"; "grantee or settler awaiting a definitive title"; "tenure"; "mechanisation"; "suppressed cells"). A revisão do inglês do M1 ainda está pendente: se os termos do M1 mudarem, muda-se aqui e nas tabelas de `i18n/`.

## 1. Como a versão em inglês está montada

- `en/` é um projeto Quarto próprio, com **os mesmos nomes de arquivo** do site em português. Sai em `_site/en/`, com busca própria.
- O código R e os dados ficam na raiz e servem aos dois projetos. Em `en/`, `EN` é `TRUE`.
- Em `R/*.R`, todo texto visível passa por `tr("português", "English")`. **O texto em português fica idêntico, byte a byte**: o site em português não pode mudar.
- Auxiliares em `R/idioma.R`:
  - `tr(pt, en)`: texto do idioma.
  - `nome_bioma(b)`: bioma na tela ("Amazônia" vira "Amazon"). Comparações e chaves continuam com "Amazônia".
  - `dic(x)`: valor de dado na tela, por `i18n/dic_*.csv` (colunas `pt,en`). Falta de tradução para a renderização com erro, de propósito.
  - `sobrepor_en(df, "arquivo_en.csv", "chave")`: troca colunas de texto por `i18n/arquivo_en.csv`, casando pela chave. A coluna `<chave>__en`, se houver, traduz a própria chave.
  - `conv_num_en(s)`: "1.234,5" vira "1,234.5" em texto já formatado.
  - `ordinal(n)`: 1st, 2nd... (1º, 2º... em português).
  - `data_en(x)`: "2026-10-19" ou "19/10/2026" vira "19 Oct 2026". Usar dentro de `tr()`.
  - `ARQ_REL`: caminho de `arquivos/` visto de uma página em subpasta.
- `num()`, `escala()`, `fmt_valor()` e `fmt_eixo()` já formatam no idioma certo. Ver `R/funcoes.R`, que já está adaptado e serve de exemplo.
- **Dados internos não mudam.** Não renomeie colunas de tabela nem valores usados em comparação, chave, filtro por código ou download: em `reactable`, troque só o título com `colDef(name = tr("Município", "Municipality"))`. Os scripts de conferência leem essas chaves.
- Downloads (`arquivos/`) continuam em português, uma única cópia na raiz do site publicado.

## 2. Regras para as páginas `en/**/*.qmd`

1. **Mesma estrutura do original:** mesma ordem de seções, blocos e parágrafos; mesmos blocos de R, com as mesmas funções e argumentos. Não acrescente, corte, resuma nem reinterprete. Mantenha ressalvas e hipóteses com a mesma força: "não sustentada" é "not supported", nunca "rejected" nem "refuted" se o original não diz isso.
2. **Carregar o código:** o primeiro `source` de cada página passa a ser `source(file.path(Sys.getenv("QUARTO_PROJECT_DIR", "."), "..", "R", "funcoes.R"))`; os demais usam `source(file.path(RAIZ, "R", "pag_xxx.R"))`.
3. **YAML:** traduza `title`, `subtitle` e `description`; o resto fica igual.
4. **Blocos de R na página:** traduza direto os textos passados como argumento (não precisa de `tr()`, a página só existe em inglês). Bioma exibido em código em linha: `` `r nome_bioma(M$bioma)` ``.
5. **Links entre páginas:** caminhos iguais aos do original (`../resultados/posse.qmd`). Âncoras: mantenha a do original com id explícito no título traduzido, por exemplo `## How to cite {#como-citar}`, sempre que a seção for alvo de link em alguma página.
6. **Downloads:** `arquivos/` existe só na raiz do site publicado. Numa página em subpasta de `en/`, o link passa a `../../arquivos/...`; em `en/index.qmd` e `en/sobre.qmd`, `../arquivos/...`.
7. **Figuras e imagens:** caminhos iguais aos do original (`en/resultados/figuras/` terá as versões em inglês, com os mesmos nomes; `en/assets/` tem os logos).
8. **Referências cruzadas** (`@tbl-...`, `#| label:`) ficam iguais.
9. **Citações e títulos de obras** ficam no idioma original. Nomes próprios em português ficam como estão (seção 5).

## 3. Números, datas e sinais

- Formato inglês em todo número escrito no texto: "112.987" vira "112,987"; "48,69" vira "48.69"; "0,292" vira "0.292". **Nunca arredonde nem recalcule.** Sinal de menos, intervalos e parênteses como no original: "[−0,002; 0,335]" vira "[−0.002; 0.335]".
- Não mudam: anos, códigos e identificadores ("Lei 11.326/2006" vira "Law 11.326/2006"; "tabela 6878"; "D-25-02928"; "MT0641000"; "Relatório 0227"; "46504").
- "mil / mi / bi" em valores: thousand / million / billion. Em eixos de gráfico: k / m / bn (já em `fmt_eixo`). "R$ mil" vira "R$ thousand"; "mil tCO2e" vira "thousand tCO2e"; "1:250 mil" vira "1:250,000". R$ e US$ ficam.
- Datas no texto: "03/06/2025" vira "3 June 2025"; "posição de 03/06/2025" vira "as at 3 June 2025". Em tabelas e rótulos curtos: "3 Jun 2025". "ago/2023" vira "Aug 2023". Períodos "2006–2017" ficam.
- Sinais do IBGE: **X** suppressed; **–** true zero; **...** not available. Dica no mapa: "X (IBGE suppression)". Nunca vire um sinal em 0.
- Ordinais: "14º maior de 76" vira "14th of 76" (a página explica que 1st = largest).
- Números pequenos no texto corrido vão por extenso ("3 biomas" vira "three biomes"); tabelas, rótulos, unidades e estatísticas ficam em algarismos.
- Moeda sem espaço depois do símbolo: "R$ 81,4 mi" vira "R$81.4 million". A unidade "R$ thousand" fica como está.

## 4. Estilo: inglês de nativo

**Objetivo:** quem lê em inglês não pode perceber que o texto foi traduzido. A página diz o mesmo que a original, mas não segue a construção da frase em português. O modelo é um artigo bem editado da *Land Use Policy* nos trechos técnicos e um relatório da FAO ou do Banco Mundial nos textos de apresentação.

Inglês britânico (mechanisation, unspecialised, programme, labour, colonisation, licence como substantivo, tonne), sem vírgula de Oxford, registro formal, impessoal e direto: o sujeito é "this page", "the project", "the authors", nunca "we" nem "you" (botões e instruções usam o imperativo). Sem contrações. Palavras estrangeiras ao português em itálico (*ranking*, *payback*) perdem o itálico em inglês; "*k-means*" e termos latinos ficam como no original.

### 4.1. O que pode mudar

A ordem das orações na frase e das frases no parágrafo; dividir ou juntar frases; trocar substantivo por verbo e passiva por ativa; cortar conectivo vazio; reescrever títulos e rótulos; escolher entre "% of" e "share of".

### 4.2. O que não pode mudar

- **O conteúdo:** fatos, números, datas, unidades, ressalvas e a força de cada afirmação ("may" continua "may"; "not detected" não vira "no difference"). Nada de explicação nova, exemplo novo ou informação cortada. Erro do original não se corrige aqui: relata-se.
- **A estrutura:** seções, parágrafos, tabelas, links, referências cruzadas, negritos dos mesmos conceitos, código.
- **Termos do M1:** rótulos T1 a T5 e F1 a F5; "grantee or settler awaiting a definitive title"; "2017 Agricultural Census"; "tenure awaiting title"; "suppressed"; "true zero"; "provisional label"; "not supported"; "decision rule"; "partial independence"; "mandatory reformulation". O texto "X (IBGE suppression)" é lido pelo conferidor de publicação.

### 4.3. Marcas de tradução a eliminar

| Marca | Em vez disso |
|---|---|
| Muletas: *It should be noted that, It is worth noting, In this context, In this sense, In this way, in turn, with regard to, as regards, in relation to, in the case of, in the event of, Thus,* no início da frase | Cortar, ou dizer direto. "It should be noted that all pages ask search engines not to index them" → "All pages ask search engines not to index them" |
| Substantivo no lugar do verbo: *the holding of, the construction of, the gathering of, the preparation of, the implementation of* | "covers the holding of workshops" → "includes workshops"; "The implementation of the project is organised into three phases" → "The project runs in three phases" |
| Verbos de tradução: *presents, consists of, comprises, constitutes, is adopted, is carried out, is verified, is observed, is made available, is accompanied by, can be consulted in, envisaged* | "@tbl-x presents the project members" → "@tbl-x lists the project members"; "can be consulted in Objectives" → "See Objectives for..." |
| *by means of, through* quando basta "by", "with" ou "using"; *according to* em excesso; *namely, that is, respectively* quando a frase se resolve sem eles | "by means of remote sensing" → "using remote sensing" |
| Artigo definido do português: *the number, the area and the mean area of the establishments* | "the number, area and mean area of establishments" |
| "of" em cadeia, onde o inglês usa modificador antes do nome: *the data of IBGE, the map of IBGE, Value of production of family farming* | "IBGE data"; "the IBGE map"; "value of family-farm production". Sem empilhar mais de três nomes seguidos |
| Orações encadeadas por *which, whereas, so that, since*, frases acima de 35 palavras, ponto e vírgula em série | Dividir em duas frases |
| Falsos cognatos e calcos: *elaboration, consult, valorisation, actual, eventual, in the ambit of, capacitation, formation (treinamento), modality, public managers, usual (padrão), base (de dados), the same (pronome), both ... as* | Palavra corrente: "compiled", "see", "actual" só no sentido inglês, "training", "type", "public officials", "standard" ou "conventional", "database", "it" |
| Variar palavra por elegância | Mesmo conceito, mesma palavra, em todo o site |
| Cara de texto de máquina: *delve, crucial, pivotal, leverage, landscape* (figurado), *underscore, comprehensive, seamless, valuable insights*, "not only ... but also", travessão em série, trios de adjetivos | Cortar ou dizer o fato |

Tom: nem burocrático nem de marketing, e sem coloquialismo. Exemplos de antes e depois:

- "The origin of the difference in relation to the state table has not yet been clarified." → "It is not yet clear why these figures differ from the state table."
- "The site is generated with Quarto and R, whereas the data are prepared in Python from the project databases, frozen on 19 October 2026." → "The website is built with Quarto and R. The data are prepared in Python from the project databases, which were frozen on 19 October 2026."
- "Results are subject to change as the stages of the study are completed." → "Results may change as the study progresses."
- "context indicator, with no better or worse direction" → "context indicator: neither higher nor lower values are better"

### 4.4. Termos decididos nesta revisão

Prevalecem sobre as tabelas das seções 5 e 6.

| Português | Antes | Agora |
|---|---|---|
| agricultura familiar, AF | family farming (FF); of FF | "family farming", "family farms", "family-farm" como adjetivo. A sigla FF só onde o rótulo não cabe de outro modo, e definida na própria página |
| % da AF na 46504; área da AF; valor da produção da AF; pessoal ocupado na AF; AF e não AF | % of FF in 46504; Area of FF; Value of production of FF; Persons employed in FF; FF and non-FF | % of family farms in 46504; Family-farm area; Value of family-farm production; Persons employed on family farms; family and non-family farms |
| Elaboração própria com base em | Authors' elaboration based on | "Source: authors' calculations based on" (números calculados); "Source: compiled by the authors from" (listas e quadros) |
| sinal do IBGE; coluna Sinal | sign; Sign | symbol; Symbol. Colunas dos CSV continuam em português (`Sinal`, `sinal_<variável>`) |
| condição de concessionário(a) ou assentado(a) | condition of grantee or settler | status of grantee or settler |
| condição do produtor em relação às terras | the producer's condition in relation to the land | the producer's land tenure status |
| site | site | website |
| MT | MT | "Mato Grosso" no texto corrido; "MT" em tabelas, rótulos e depois do nome do município |
| dinâmica 2006–2017 | dynamics 2006–2017 | 2006–2017 dynamics |
| faixas usuais; teste usual | usual bands; usual test | conventional bands; standard test |
| estudos comparados | compared studies | studies compared |
| gestores públicos | public managers | public officials |
| ponto vazado | hollow point | open circle |
| Malha Municipal | municipal mesh | "municipal boundaries"; "Municipal Mesh" só como nome do produto do IBGE |
| Coordenação geral; de geotecnologias; de economia; de bioeconomia | General coordination; ... coordination | Project coordinator; Geospatial technologies coordinator; Economics coordinator; Bioeconomy coordinator |
| Pesquisa; Pesquisa em TI | Research; Information technology research | Researcher; Information technology researcher |
| Bolsista | Scholarship holder | Research scholarship holder |
| soma dos municípios | sum of municipalities | municipal sum; "sum across the 141 municipalities" |
| números em conciliação | figures under reconciliation | figures being reconciled |
| perímetro | perimeter | boundary |
| diagnóstico | diagnosis | assessment |
| sub-registra a reforma agrária | under-records agrarian reform | understates the extent of agrarian reform |
| plantio direto na palha | no-till on straw | no-till with straw cover |
| valor da produção da AF | family-farm value of production | value of family-farm production |
| Dados e método | Data and method | Data and methods |
| Posse no Censo (Agropecuário) e reforma agrária | Census tenure and agrarian reform | Census tenure data and agrarian reform; no título da página, Agricultural Census tenure data and agrarian reform |
| Estudos do corpus | Corpus studies | Studies in the corpus |

Textos fixos:

- Faixa das páginas: "English translation under review. If the two versions differ, the Portuguese text prevails."
- Rodapé: "RESA Project no. 115 · Supported by Instituto Clima e Sociedade (iCS), Grant D-25-02928 · Implemented by UNEMAT · Preliminary version for the project team · Last updated 5 November 2026" (também em `RODAPE_EN`, no script 07).

## 5. Termos

| Português | English |
|---|---|
| Observatório RESA-MT | RESA-MT Observatory |
| Projeto RESA nº 115 | RESA Project no. 115 |
| *Viabilidade Econômica de Assentamentos Rurais nos Três Biomas de Mato Grosso: Análise Integrada de Sustentabilidade, Carbono e Dinâmica Territorial* | *Economic Viability of Rural Settlements in the Three Biomes of Mato Grosso: An Integrated Analysis of Sustainability, Carbon and Territorial Dynamics* |
| Apoio / Doação / Execução (rodapé; texto fixo na seção 4.4) | Supported by / Grant / Implemented by |
| Versão preliminar para a equipe do projeto | Preliminary version for the project team |
| Coordenação geral (função na equipe; demais funções na seção 4.4) | Project coordinator |
| Universidade do Estado de Mato Grosso (UNEMAT) | Mato Grosso State University (UNEMAT) |
| Instituto Clima e Sociedade (iCS), Observatório do Clima, Banco da Terra, TerraBrasilis, MapBiomas | manter em português |
| agricultura familiar (AF) | family farming; family farms; family-farm como adjetivo. A sigla FF só onde o rótulo não cabe de outro modo, definida na própria página (seção 4.4) |
| estabelecimentos da AF | family farms; área da AF -> Family-farm area; valor da produção da AF -> Value of family-farm production; pessoal ocupado na AF -> Persons employed on family farms |
| estabelecimentos agropecuários | agricultural establishments |
| pessoal ocupado | persons employed (on family farms; on agricultural establishments) |
| valor da produção | value of production |
| lavoura temporária / permanente | temporary crops / permanent crops |
| horticultura; irrigação; plantio direto; trator | horticulture; irrigation; no-till; tractor |
| orientação técnica | technical guidance |
| Censo Agropecuário 2017 | 2017 Agricultural Census |
| Censos Agropecuários 2006 e 2017 | 2006 and 2017 Agricultural Censuses |
| categoria 46504: concessionário(a) ou assentado(a) aguardando titulação definitiva (Censo 2017) | category 46504: grantee or settler awaiting a definitive title (2017 Census). **Nunca só "settlers".** |
| posse (da terra) | (land) tenure |
| posse aguardando titulação | tenure awaiting title |
| sub-registra | understates the extent of |
| reforma agrária | agrarian reform |
| assentamento rural | rural settlement |
| assentado(a) / famílias assentadas | settler / settled families |
| titulado(a) / beneficiário(a) | titled / beneficiary |
| projeto de assentamento (PA) | settlement project (PA) |
| INCRA, Instituto Nacional de Colonização e Reforma Agrária | National Institute for Colonisation and Agrarian Reform (INCRA) |
| SIPRA, Sistema de Informações de Projetos de Reforma Agrária | Agrarian Reform Projects Information System (SIPRA) |
| crédito fundiário (PNCF) | land credit (National Land Credit Programme, PNCF) |
| IBGE | Brazilian Institute of Geography and Statistics (IBGE) |
| INPE, Instituto Nacional de Pesquisas Espaciais | National Institute for Space Research (INPE) |
| SEEG, Sistema de Estimativas de Emissões e Remoções de Gases de Efeito Estufa | Greenhouse Gas Emissions and Removals Estimation System (SEEG) |
| PRONAF | National Programme for Strengthening Family Farming (PRONAF) |
| DAP, Declaração de Aptidão ao Pronaf | PRONAF Eligibility Declaration (DAP) |
| Lei 11.326/2006 | Law 11.326/2006 |
| objetivo específico (OE); OE1 | specific objective (SO; plural SOs); SO1 (arquivos continuam `oe1.qmd`) |
| Pacote Tecnológico | Technology Package |
| área-piloto | pilot area |
| município-sede; sede de área-piloto | host municipality; pilot-area host municipality |
| bioma dominante | dominant biome |
| Amazônia (bioma) | Amazon |
| Amazônia Legal | Legal Amazon |
| Cerrado, Pantanal, Mata Atlântica, Caatinga | Cerrado, Pantanal, Atlantic Forest, Caatinga |
| Mato Grosso (MT) | Mato Grosso no texto corrido; MT em tabelas, rótulos e depois do nome do município (definido como Mato Grosso (MT) na primeira menção da página) |
| Manuscrito 1 (M1); Manuscrito 1 do Projeto RESA; os tipos do Manuscrito 1; Artigo A/B/C | Manuscript 1 (M1); RESA Project Manuscript 1; the types from Manuscript 1 (ou Manuscript 1 types); Article A/B/C |
| tipologia municipal; tipo | municipal typology; type |
| rótulo provisório | provisional label |
| T1 Baixo porte agregado | T1 Low aggregate scale |
| T2 Posse aguardando titulação, sem especialização | T2 Tenure awaiting title, unspecialised |
| T3 Grande porte agregado | T3 High aggregate scale |
| T4 Mecanizado com posse aguardando titulação | T4 Mechanised with tenure awaiting title |
| T5 Hortícola-irrigado | T5 Horticultural-irrigated |
| F1 Lavoura temporária mecanizada | F1 Mechanised temporary crops |
| F2 Porte agregado | F2 Aggregate scale |
| F3 Horticultura e irrigação | F3 Horticulture and irrigation |
| F4 Lavoura permanente | F4 Permanent crops |
| F5 Posse aguardando titulação (46504) | F5 Tenure awaiting title (46504) |
| análise fatorial exploratória (AFE) | exploratory factor analysis (EFA) |
| análise fatorial por eixos principais (PAF) | principal axis factoring (PAF) |
| escores; cargas; comunalidade; rotação oblíqua | scores; loadings; communality; oblique rotation |
| análise paralela; silhueta | parallel analysis; silhouette |
| intervalo de confiança (IC) | confidence interval (CI) |
| regra de decisão; independência parcial; reformulação obrigatória | decision rule; partial independence; mandatory reformulation |
| não sustentada | not supported |
| sigilo; célula com sigilo | suppression; suppressed cell |
| Região Geográfica Imediata (RGI) | Immediate Geographic Region (RGI) |
| mediana; agregado; posição; recorte | median; aggregate; rank; breakdown |
| soma dos municípios; razão das somas; variação das somas | municipal sum; ratio of sums; change in sums |
| dinâmica 2006–2017 | 2006–2017 dynamics |
| emissões brutas; remoções | gross emissions; removals |
| mudança de uso da terra e florestas | land-use change and forestry |
| agropecuária (setor do SEEG) | agriculture and livestock |
| energia; processos industriais; resíduos | energy; industrial processes; waste |
| desmatamento; taxa; incremento | deforestation; rate; increment |
| taxa consolidada / estimada | consolidated / estimated rate |
| proxy (de desmatamento); aderência; viés | (deforestation) proxy; agreement; bias |
| valor presente líquido (VPL) | net present value (NPV) |
| taxa interna de retorno (TIR) | internal rate of return (IRR) |
| pagamento por serviços ambientais (PSA) | payment for environmental services (PES) |
| sistema agroflorestal (SAF) | agroforestry system (AFS) |
| mercados de carbono; ESG | carbon markets; ESG |
| capital social; capacidade de inovação | social capital; innovation capacity |
| uso e cobertura da terra | land use and land cover |
| sensoriamento remoto | remote sensing |
| floresta em pé | standing forest (termo); com a floresta em pé -> keeping the forest standing |
| Fonte: Elaboração própria com base em | Source: authors' calculations based on (números calculados); Source: compiled by the authors from (listas e quadros) |
| Nota de correção | Correction note |
| Novidades | What's new |
| Como citar | How to cite |
| Municípios / Indicadores / Resultados / Objetivos / Literatura / Dados / Biblioteca / Sobre | Municipalities / Indicators / Results / Objectives / Literature / Data / Library / About |
| Tipologia municipal da AF | Municipal typology of family farming |
| Posse no Censo e reforma agrária | Census tenure data and agrarian reform |
| Emissões e desmatamento | Emissions and deforestation |
| Estudos do corpus; Panorama | Studies in the corpus; Overview |
| SAF e PSA em assentamentos | AFS and PES in settlements |
| concluído / em andamento / a confirmar / previsto | completed / in progress / to be confirmed / planned |
| números em conciliação | figures being reconciled |
| dicionário (de dados) | data dictionary |

Termos novos que surgirem: use a forma mais próxima do Abstract do M1 e registre-os no relatório da tarefa, para entrarem nesta tabela.

## 6. Termos acrescentados durante a tradução

Registrados pelos tradutores e pelos editores da revisão do inglês, ainda sem conferência dos autores. A tabela segue a seção 4.4 e o texto em uso no site.

| Português | English |
|---|---|
| % da AF de proprietário(a) | % run by owners |
| % da AF nos estabelecimentos / na área | family-farm share of establishments / of area |
| 5º Relatório de Avaliação do IPCC | IPCC Fifth Assessment Report |
| Acervo Fundiário | mantido em português |
| acesso em; atualização do INPE em | accessed on; updated by INPE on |
| aderência interanual | interannual agreement |
| AF e não AF | family and non-family farms |
| AFOLU | agriculture, forestry and other land use |
| agregados por (soma, razão) | aggregated as the |
| Agricultura familiar (coluna Público) | Family farmers |
| agricultura itinerante (coluna Público) | shifting cultivators |
| agrissilvipastoril | agrosilvopastoral |
| agropecuária de todos os portes | agriculture and livestock operations of all sizes |
| agrupamento; grupos | clustering; groups |
| alocados pela área dos polígonos | allocated by the area of the project polygons |
| ano de referência | reference year |
| ano médio de criação dos projetos | mean year of project creation |
| API de agregados | aggregates API |
| Apresentação do projeto (título de seção) | Project overview |
| área declarada | declared area |
| área média da AF | Mean family-farm area (rótulo longo do indicador: Mean area of family farms) |
| Arquivos para download | Files for download |
| arranjo | arrangement |
| articulação (Fase 3) | engagement |
| artigo / estudo / trabalho de referência (Dominicis et al., 2023) | reference study |
| Artigo A refeito; refeita (tabela de robustez) | Article A recalculated; recalculated |
| Aspectos éticos | Ethical considerations |
| Assent. X | X settlement |
| até a conferência da licença | until the licence has been checked (como em R/pag_municipios.R) |
| Bacia do Descoberto | Descoberto Basin; Distrito Federal -> Federal District |
| bacia do rio Descoberto | Descoberto River basin |
| banking | banking (mantido) |
| base (de dados) | database |
| Base de dados (título de etapa) | Data |
| base municipal (do Artigo C) | municipal database from Article C |
| baseado na ordem dos valores | based on the rank order of the values |
| bases congeladas | databases frozen |
| Biomas do Brasil (IBGE) | Biomes of Brazil |
| bloco temático | thematic block |
| blocos regionais | regional blocks |
| Bolsista | Research scholarship holder |
| bootstrap de pares | pairs bootstrap |
| busca | search |
| cacau | cocoa |
| cadastro ambiental por imóvel | property-level environmental registry data |
| caderno de tabelas estaduais | workbook of state tables |
| cálculo | calculation |
| campo de busca | search box |
| capacitação | training |
| CAR, Cadastro Ambiental Rural | Rural Environmental Registry (CAR) |
| Caracterização dos tipos | Characteristics of each type |
| cartilhas | booklets; dias de campo -> field days |
| cartões; quadro (texto) | cards; box |
| castanha | Brazil nut |
| Censo; Censos (os de 2006 e 2017) | Census; Censuses, com maiúscula |
| cobertura (da categoria; 46504/beneficiários) | coverage |
| cointegração | cointegration |
| coleção (SEEG, MapBiomas) | collection |
| Coleção de cobertura e uso da terra | Land cover and land use collection |
| Colorir o mapa por | Colour the map by |
| com repetições | with repetitions |
| com sede no município | based in the municipality |
| Com X (sigilo), título de coluna | Suppressed (X) |
| Comitê de Ética em Pesquisa | Research Ethics Committee |
| composição setorial | sectoral composition |
| Comunicação de erros e sugestões | Reporting errors and suggestions |
| conciliar; conciliação | reconcile; reconciliation |
| condição de concessionário(a) ou assentado(a) aguardando titulação definitiva | status of grantee or settler awaiting a definitive title |
| condição declarada; categoria censitária | declared tenure status; census category |
| condição do produtor em relação às terras | the producer's land tenure status |
| Condições de uso e atribuição | Terms of use and attribution |
| conferido / verificado no Crossref | checked against / verified against Crossref |
| consentimento livre e esclarecido | free and informed consent |
| Considerações finais | Concluding remarks |
| consulta | query |
| consulta ampliada | broader query |
| Consulta por município/indicador/área-piloto | Browse by municipality/indicator/pilot area (são listas de navegação; search fica para a busca do site) |
| consumo próprio | own consumption |
| contagens das bases | record counts from the databases searched |
| Contextualização e objetivo | Context and objective |
| contorno com halo branco | outline with white halo |
| convenção padrão | standard convention |
| correção espacial | spatial correction |
| corte e queima | slash and burn |
| corte raso | clear-cutting |
| cresceu; diminuiu (variação) | rose by; fell by |
| critério gap | gap criterion |
| cronograma de execução | implementation schedule |
| dado não disponível | value not available |
| dado omitido; informante | value withheld; respondent |
| Dados e método / Dados e fontes | Data and methods / Data and sources |
| dados públicos; citar a fonte | public data; cite the source |
| data de acesso; Acesso (coluna) | access date; Accessed |
| Detalhes da tipologia | Typology details |
| Diagnóstico e evidências | Assessment and evidence |
| difusão | diffusion; plano de disseminação -> dissemination plan |
| digitado(a) manualmente | entered by hand |
| dióxido de carbono equivalente (CO2e) | carbon dioxide equivalent (CO2e) |
| Divergência (título) | Discrepancy |
| do total dos municípios de MT | of the total across MT municipalities |
| DOI conferido | checked DOI |
| DOI verificado | verified DOI |
| eixo de posse | tenure axis |
| eixo socioeconômico | socioeconomic axis |
| Elaboração do site | Website development |
| Elaboração dos autores do Manuscrito 1 com base em | Source: calculations by the authors of Manuscript 1 based on |
| em % da AF; em % da área da AF | as a percentage of family farms; as a percentage of family-farm area |
| em % do território | the percentage of territory deforested (texto corrido); % of territory (rótulos) |
| em revisão (texto ou manuscrito próprio) | being revised |
| empatado com | tied with |
| empate com k = 4 | tie with k = 4 |
| Encontro RESA | RESA Meeting |
| Endereço (coluna) | Web address |
| energia elétrica | electricity |
| entrega principal | main deliverable |
| épsilon ao quadrado | epsilon squared |
| escore de Bartlett | Bartlett score |
| esquema (de bootstrap) | scheme |
| estabelecimentos / projetos da reforma agrária | agrarian-reform establishments / projects |
| Estabelecimentos da AF de concessionário(a) ou assentado(a) aguardando titulação definitiva (Censo 2017) | Family farms run by a grantee or settler awaiting a definitive title (2017 Census) |
| estatística gap | gap statistic |
| Estratégias e modelagem de viabilidade | Strategies and viability modelling |
| estudos comparados; os estudos comparados do OE4 | studies compared; the studies compared for SO4 |
| etapa | stage; Próximas etapas -> Next steps |
| evolução temporal | change over time |
| excedente de reserva legal | legal reserve surplus |
| explorador de indicadores | indicator explorer |
| faixa (da regra de decisão) | band |
| faixa cinza | grey band |
| faixa parcial | partial independence band |
| faixas da regra de decisão | decision rule bands |
| faixas usuais de estabilidade | conventional stability bands |
| Fase | Phase |
| Fases de execução | Implementation phases |
| fatores produtivos; estrutura produtiva | productive factors; productive structure |
| financiamento | financing |
| Floresta em Pé (nome do pacote) | Standing Forest |
| fluxo de caixa | cash flow |
| fontes abertas (preços de) | publicly available prices |
| fora do Brasil | outside Brazil |
| formações florestais | forest formations |
| formato largo | wide format |
| Frente ao bioma X | Relative to the X biome |
| frente de trabalho | workstream |
| Função no projeto (coluna) | Project role |
| GEE, gases de efeito estufa | greenhouse gases (GHGs); como modificador, greenhouse gas (GHG) |
| geotecnologias | geospatial technologies |
| ha por estab. (da AF) | ha per family farm |
| homologados (beneficiários); homologados até | approved; approved up to |
| homônimos | similar names; Atenção aos homônimos -> Beware of similar names |
| horticultura e floricultura | horticulture and floriculture |
| IC 95% bootstrap em blocos | 95% block bootstrap CI |
| IC 95% bootstrap iid | 95% iid bootstrap CI |
| IC percentil | percentile CI |
| Identificação (título das áreas-piloto); apresentadas apenas com a identificação | Key details; with identifying details only |
| ILP e ILPF | ICL and ICLF |
| imputação múltipla | multiple imputation |
| independência (faixa) | independence |
| indicador relativo | relative indicator |
| índice de Rand ajustado (ARI) | adjusted Rand index (ARI) |
| inicializações | initialisations |
| integração lavoura-pecuária-floresta (ILPF) | integrated crop-livestock-forest systems (ICLF) |
| interface de programação (API) | application programming interface (API) |
| k-médias | k-means |
| lacuna | gap |
| leite de vaca | cow's milk |
| Leituras de base | Core readings |
| levantamento de campo | field survey; levantamento de dados em campo -> field data collection |
| licença a conferir; a conferir | licence to be checked; to be checked |
| lideranças | community leaders; gestores públicos -> public officials; poder público -> public authorities; tomadores de decisão -> decision-makers; partes interessadas -> stakeholders |
| limiares | thresholds |
| listas de seleção (filtros de tabela) | drop-down lists |
| local (do estudo) | location |
| lote | plot |
| malha municipal | municipal boundaries |
| Malha Municipal (produto do IBGE) | Municipal Mesh (só como nome do produto; ver malha municipal) |
| Malha Municipal 2022 (IBGE) | IBGE 2022 Municipal Mesh; 2022 Municipal Mesh |
| mandioca | cassava |
| mapa coroplético | choropleth map |
| Marcas (legenda de mapa) | Map symbols |
| marco (cronograma) | milestone; 'Marco ago/2026' -> 'Aug 2026 milestone' |
| máscara (PRODES) | mask |
| máscaras (do PRODES) | masks |
| materiais em linguagem simples | plain-language materials |
| Mato Grosso em números | Mato Grosso in figures |
| Mediana dos municípios de MT; mediana(s) dos municípios do bioma X | Median across MT municipalities; municipal median(s) in the X biome |
| medida combinada | combined measure |
| medida de Kaiser-Meyer-Olkin | Kaiser-Meyer-Olkin measure |
| metadados das referências | reference metadata |
| metas | targets; apropriação (do pacote) -> ownership |
| milhões de toneladas de dióxido de carbono equivalente | million tonnes of carbon dioxide equivalent |
| modalidade (de área-piloto) | project type |
| mogno-africano | African mahogany |
| Movimento dos Trabalhadores Rurais Sem Terra (MST) | Landless Rural Workers' Movement (MST) |
| município-sede (tag curta na tabela do PRODES) | host |
| municípios contornados | outlined municipalities |
| n efetivo | effective n |
| não coincide; não concilia | does not match; does not reconcile |
| não é afirmada | not asserted |
| não informado | not stated |
| obtida em (série oficial do INPE) | retrieved on |
| oficinas (participativas) | (participatory) workshops; oficinas de cocriação -> co-creation workshops |
| ordenamento dos anos | ordering of the years |
| órgão responsável; Órgão (coluna) | responsible organisation; Organisation |
| Os seis objetivos (menu e botão) | All six objectives |
| Pacote Tecnológico e articulação (Fase 3) | Technology Package and engagement (em Sobre: engagement for implementation) |
| PAF iterada | iterated PAF |
| painel (TerraBrasilis); painel versão | TerraBrasilis dashboard; TerraBrasilis dashboard, version X |
| parcela paga pela terra | instalment paid for the land |
| participação (parcela; % da soma; de setor, de grupo) | share |
| passivo de reserva legal | legal reserve deficit |
| pequena produção | small-scale production |
| pequena propriedade | smallholding |
| pequenos produtores | small producers |
| Perfis dos tipos | Type profiles |
| pergunta de pesquisa | research question |
| perímetro | boundary |
| periódico | journal |
| período anual; período plurianual | annual period; multi-year period |
| permissões de emissão | emission allowances |
| plantio direto na palha | no-till with straw cover |
| PNUD | UNDP |
| ponderado | weighted |
| ponto vazado | open circle |
| por par | for each pair |
| Portal de Periódicos da CAPES | mantido em português (nome próprio) |
| potencial de aquecimento global | global warming potential |
| pousio | fallow |
| praticamente estável (entre dois Censos) | almost unchanged |
| preenchida em parte | partly filled |
| premissa (do fator) | assumption |
| Procedimentos (título em linha); procedimentos metodológicos previstos | Methods.; Planned methods |
| PRODES oficial | official PRODES data; official PRODES series (quando se trata da série) |
| produção animal | animal production |
| produto final; resultado final (o Pacote Tecnológico) | end product; planned end product |
| produtor proprietário(a); estabelecimentos da AF de proprietário(a) | owner; Family farms run by their owners |
| produtores familiares; propriedades familiares | family farmers; family farms |
| projeção cônica equivalente de Albers | Albers equal-area conic projection |
| projeto de assentamento da reforma agrária | agrarian-reform settlement project |
| projetos estaduais; projetos de colonização antigos | state projects; old colonisation projects |
| proposta de escala | scaling proposal |
| proprietário(a) | owner |
| proprietários titulados pela reforma agrária; com titulação via reforma agrária | owners titled through agrarian reform |
| público; arranjo (estudos do OE4) | target group; arrangement |
| pupunha | peach palm |
| quintis | quintiles |
| razão das somas dos municípios; variação das somas dos municípios | ratio of municipal sums; change in municipal sums |
| reais de 2017 | 2017 reais |
| reamostra; reamostras; reamostragem | resample; resamples; resampling |
| reconhecimento de campo | field reconnaissance |
| recorte (SIG) | clipping |
| recorte da pesquisa; recorte espacial | research scope; spatial scope (recorte = breakdown vale para os cortes de indicador, não para esta seção) |
| recorte filtrado; CSV do recorte; Baixar o recorte filtrado (CSV) | filtered rows; CSV file of filtered rows; Download filtered rows (CSV) |
| REDD+ | reducing emissions from deforestation and forest degradation |
| reedição | reissued by |
| reformulação (faixa) | reformulation |
| registro (de base) | record |
| registro interno | internal record; coordenação -> the project coordination team |
| registros colhidos | records retrieved |
| registros únicos | unique records |
| regra de 1 EP | 1-SE rule |
| Regras de conteúdo | Content rules |
| relação benefício/custo | benefit/cost ratio |
| relação de beneficiários; relação de beneficiários da SR-13 | list of beneficiaries; SR-13 list of beneficiaries |
| Relatório 0227 | Report 0227 |
| relatório(s) de diagnóstico | assessment report(s); o substantivo continua assessment |
| réplicas | replicates |
| Reprodução da Figura N do Manuscrito 1 | Reproduced from Figure N of Manuscript 1 |
| reserva legal | legal reserve |
| resíduos das cidades | urban waste |
| ressalvas metodológicas | methodological caveats |
| restauração produtiva | productive restoration |
| resultado do projeto; citar o projeto | project result; cite the project |
| resultados definitivos | final results |
| Resultados já publicados | Results published so far |
| resumos de terceiros | third-party abstracts |
| retrato (municipal) | (municipal) snapshot |
| Retrato de um único ano | Single-year snapshot |
| robustez do Artigo B; tabela de robustez | Article B robustness check; Article B robustness table |
| Seções do observatório | Sections of the observatory |
| sede da área-piloto X | host municipality of the X pilot area |
| selo | badge |
| selo chave; indicadores-chave | key; key indicators |
| selo “rótulo provisório” | “provisional label” badge |
| sem posição; sem posição no ranking | not ranked |
| Série (coluna da tabela; dica da minissérie) | Time series |
| série histórica (SEEG, PRODES); série histórica dos Censos | time series; historical Census series |
| silhueta média | mean silhouette |
| silvipastoril | silvopastoral |
| símbolo ⓘ | ⓘ icon (symbol fica para os sinais do IBGE) |
| Sinais convencionais do IBGE | IBGE standard symbols |
| sinal (coluna; sinal do IBGE) | symbol (título da coluna: Symbol). As colunas dos CSV continuam em português |
| sistema de monitoramento do desmatamento por satélite (PRODES) | satellite-based deforestation monitoring system |
| Sistema IBGE de Recuperação Automática (SIDRA) | IBGE Automatic Retrieval System (SIDRA) |
| sistemas de informação geográfica (SIG) | geographic information systems (GIS) |
| sistemas de produção familiares; sistemas familiares | family production systems |
| situação (de execução) | (implementation) status |
| situação Assentado ou Titulado | status Settler or Titled |
| situação da água e do solo | condition of water and soil (status fica para a situação de execução) |
| soma dos 141 municípios; soma municipal | sum across the 141 municipalities; municipal sum |
| spillover | spillover (mantido; definição sem 'transbordamento') |
| subsidiar (objetivos, escolha de métodos) | inform |
| sumários para gestores (policy briefs) | summaries for public officials (policy briefs) |
| Superintendência Regional (SR-13) | Regional Superintendency (SR-13) |
| tabela de confronto dos Censos (do IBGE) | IBGE Census comparison table |
| tabela estadual de comparação 2006–2017 | 2006–2017 state comparison table |
| tabela estadual; tabela de confronto do IBGE | state table; IBGE comparison table |
| tamanho de efeito; graus de liberdade | effect size; degrees of freedom |
| tema | theme |
| tempo de retorno do investimento (payback) | investment payback period |
| teste t modificado de Dutilleul; autocorrelação espacial | Dutilleul's modified t-test; spatial autocorrelation |
| teste usual | standard test |
| testes de diferença | tests for differences |
| texto para discussão | discussion paper |
| titulação ou licença da reforma agrária | agrarian-reform titling or licence |
| toneladas de dióxido de carbono equivalente | tonnes of carbon dioxide equivalent |
| total estadual / emissões estaduais / nível estadual | state total / state emissions / state level |
| total oficial | official total |
| transição (entre biomas) | transition zone |
| truncado em ±3 | truncated at ±3 |
| uso no site | use on the website |
| V de Cramér; qui-quadrado; teste por permutação | Cramér's V; chi-square; permutation test |
| validação externa | external validation |
| valor atípico | outlier |
| valor publicado | published value |
| valores correntes (rótulo de tabela) | at current prices |
| valores correntes de 2006 | 2006 values at current prices |
| variação (percentual, mediana, intercensitária) | change (percentage, median, intercensal); variação mediana -> median change; variação interanual -> interannual variation |
| várzea | floodplain |
| versão anterior (superada) | previous version (superseded) |
| versão atual | current version |
| viáveis (valores de k) | feasible |
| winsorizados | winsorised |
