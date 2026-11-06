# -*- coding: utf-8 -*-
"""
08_checar_ingles.py - Observatório RESA-MT

Compara a versão em inglês (en/, _site/en/) com o site em português. Roda na raiz
do repositório, depois dos dois renders e do script 07:

  python -I scripts/08_checar_ingles.py            # para com código 1 se houver problema
  python -I scripts/08_checar_ingles.py --detalhes # lista todas as divergências de números

São cinco partes.

1. PARES DE ARQUIVOS: cada .qmd em português tem o seu em en/, e vice-versa; as cópias
   de en/ (CSS e logos) continuam iguais às originais.
2. CÓDIGO DAS PÁGINAS: mesma quantidade de blocos de R e as mesmas funções chamadas.
   Nas páginas de en/ só podem sobrar os auxiliares de tradução (AUX_TRADUCAO).
3. ESTRUTURA DAS PÁGINAS PUBLICADAS: mesmo número de seções, tabelas, gráficos, mapas,
   figuras e notas; o seletor de idioma em todas; lang certo.
4. NÚMEROS: de cada par de páginas, tiram-se os números do texto visível e das tabelas e
   mapas interativos. Depois de converter o formato, as duas listas têm de ser iguais.
   Trocas legítimas ficam em EXCECOES_NUMEROS, cada uma com o motivo.
5. SOBRAS DE PORTUGUÊS em _site/en/: texto visível, dicas, rótulos e descrições, por uma
   lista de palavras comuns do português. Títulos de obras e nomes próprios têm de estar
   em PERMITIDOS, cada um com o motivo.
"""

import hashlib
import html
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):
    pass

REPO = Path(__file__).resolve().parents[1]
SITE = REPO / "_site"
EN = REPO / "en"
DETALHES = "--detalhes" in sys.argv
PROBLEMAS: list[str] = []


def problema(msg: str) -> None:
    PROBLEMAS.append(msg)


# ---------------------------------------------------------------------------
# 1. Pares de arquivos
# ---------------------------------------------------------------------------
print("1. Pares de arquivos")
IGNORAR = ("_site", "_freeze", ".quarto", ".git", "en", "scripts", "assets")
pt_qmd = {p.relative_to(REPO).as_posix() for p in REPO.rglob("*.qmd")
          if not set(p.relative_to(REPO).parts) & {"_site", "_freeze", ".quarto", ".git", "en"}}
en_qmd = {p.relative_to(EN).as_posix() for p in EN.rglob("*.qmd")
          if not set(p.relative_to(EN).parts) & {"_freeze", ".quarto"}}
for r in sorted(pt_qmd - en_qmd):
    problema(f"falta en/{r}")
for r in sorted(en_qmd - pt_qmd):
    problema(f"en/{r} não tem original em português")
COPIAS = [("resultados/resultados.css", "en/resultados/resultados.css"), ("assets/favicon.png", "en/assets/favicon.png"),
          ("assets/logo-unemat.png", "en/assets/logo-unemat.png"), ("assets/logo-unemat-branco.png", "en/assets/logo-unemat-branco.png")]
for a, b in COPIAS:
    ha, hb = (hashlib.sha256((REPO / x).read_bytes()).hexdigest() if (REPO / x).exists() else None for x in (a, b))
    if ha != hb:
        problema(f"{b} difere de {a} (ou não existe)")
print(f"  {len(pt_qmd)} páginas em português e {len(en_qmd)} em inglês")

# ---------------------------------------------------------------------------
# 2. Código das páginas
# ---------------------------------------------------------------------------
print("\n2. Código das páginas")
RX_BLOCO = re.compile(r"^```\{r[^}]*\}\s*$(.*?)^```\s*$", re.S | re.M)
RX_EM_LINHA = re.compile(r"`r ([^`]+)`")
RX_FUNCAO = re.compile(r"\b([A-Za-z_][A-Za-z0-9_.]*)\s*\(")
RX_TEXTO_R = re.compile(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'')
# Auxiliares que só existem na página em inglês: não contam como diferença de estrutura
AUX_TRADUCAO = {"sobrepor_en", "dic", "nome_bioma", "oe_tela", "data_en", "conv_num_en", "ordinal", "tr", "ifelse", "unname", "gsub", "sub", "sprintf", "paste", "paste0",
                "as.Date", "format"}


def funcoes_pagina(p: Path):
    t = p.read_text(encoding="utf-8")
    blocos = RX_BLOCO.findall(t)
    cod = "\n".join(blocos + RX_EM_LINHA.findall(t))
    cod = "\n".join(re.sub(r"#.*$", "", l) for l in RX_TEXTO_R.sub('""', cod).split("\n"))
    return len(blocos), Counter(RX_FUNCAO.findall(cod))


n_cod = 0
for r in sorted(pt_qmd & en_qmd):
    na, fa = funcoes_pagina(REPO / r)
    nb, fb = funcoes_pagina(EN / r)
    n_cod += 1
    if na != nb:
        problema(f"{r}: {na} blocos de R em português e {nb} em inglês")
    faltam = {k: v for k, v in fa.items() if k not in fb and k not in AUX_TRADUCAO}
    sobram = {k: v for k, v in fb.items() if k not in fa and k not in AUX_TRADUCAO}
    if faltam or sobram:
        problema(f"{r}: funções diferentes; só em português: {sorted(faltam)}; só em inglês: {sorted(sobram)}")
print(f"  {n_cod} pares conferidos")

# ---------------------------------------------------------------------------
# Leitura das páginas publicadas
# ---------------------------------------------------------------------------
RX_WIDGET = re.compile(r'<script type="application/json" data-for="[^"]*">(.*?)</script>', re.S)
RX_MAIN = re.compile(r"<main[^>]*>(.*?)</main>", re.S)
RX_TIRA = re.compile(r"<(script|style|svg)\b.*?</\1>", re.S)


def visivel(txt: str) -> str:
    m = RX_MAIN.search(txt)
    corpo = m.group(1) if m else ""
    corpo = re.sub(r"<(script|style)\b.*?</\1>", " ", corpo, flags=re.S)
    # textos de SVG ficam (rótulos dos gráficos); os demais marcadores saem
    corpo = re.sub(r"<[^>]+>", " ", corpo)
    return html.unescape(corpo)


def textos_widget(no, saida):
    """Todas as strings de um widget, com o HTML interno reduzido a texto."""
    if isinstance(no, str):
        if no.startswith("function") or no.startswith("#") or len(no) > 4000:
            return
        saida.append(html.unescape(re.sub(r"<[^>]+>", " ", no)))
    elif isinstance(no, dict):
        for k, v in no.items():
            if k in ("style", "class", "className", "dependencies", "elementId", "dataKey", "theme", "language", "meta",
                     "id", "key", "name_", "href", "value", "onchange", "layerId", "fillColor", "color", "colors", "stroke", "method", "evals"):
                continue
            textos_widget(v, saida)
    elif isinstance(no, list):
        for v in no:
            textos_widget(v, saida)


def widgets_txt(txt: str) -> list[str]:
    saida: list[str] = []
    for bloco in RX_WIDGET.findall(txt):
        try:
            textos_widget(json.loads(bloco), saida)
        except json.JSONDecodeError:
            continue
    return saida


def textos_tela_widget(txt: str) -> list[str]:
    """Só o que aparece na tela: em tabelas, títulos e células das colunas visíveis; nos mapas, rótulos e legendas.
    Colunas ocultas e valores internos (chaves em português, usadas em filtro) não contam."""
    saida: list[str] = []
    for bloco in RX_WIDGET.findall(txt):
        try:
            w = json.loads(bloco)
        except json.JSONDecodeError:
            continue
        x = w.get("x", {}) if isinstance(w, dict) else {}
        tag = x.get("tag", {}) if isinstance(x, dict) else {}
        if isinstance(tag, dict) and tag.get("name") == "Reactable":
            at = tag.get("attribs", {})
            dados = at.get("data", {}) if isinstance(at.get("data"), dict) else {}
            for c in at.get("columns", []):
                if not isinstance(c, dict) or c.get("show") is False:
                    continue
                textos_widget(c.get("header") if c.get("header") else c.get("name"), saida)
                textos_widget(c.get("footer"), saida)
                textos_widget(c.get("filterInput"), saida)
                if isinstance(c.get("cell"), (list, dict)):
                    textos_widget(c["cell"], saida)
                elif c.get("id") in dados:
                    textos_widget(dados[c["id"]], saida)
            textos_widget(at.get("details"), saida)
        else:
            textos_widget(w, saida)
    return saida


def conta(rx, txt):
    return len(re.findall(rx, txt))


def rel_paginas():
    if not SITE.exists():
        return []
    return sorted(p.relative_to(SITE / "en").as_posix() for p in (SITE / "en").rglob("*.html") if "site_libs" not in p.parts)


PAGINAS = rel_paginas()
if not PAGINAS:
    problema("_site/en/ sem páginas: rode os dois renders antes")

# ---------------------------------------------------------------------------
# 3. Estrutura
# ---------------------------------------------------------------------------
print("\n3. Estrutura das páginas publicadas")
MEDIDAS = {
    "seções h2": r"<h2\b", "seções h3": r"<h3\b", "tabelas": r"<table\b", "figuras": r"<figure\b", "imagens": r"<img\b",
    "gráficos SVG": r'<figure class="grafico-svg"', "widgets": r'<script type="application/json" data-for=', "notas de fonte": r'class="nota-fonte',
    "abas": r'role="tab"', "links": r"<a\b",
}
n_est = 0
for r in PAGINAS:
    a, b = SITE / r, SITE / "en" / r
    if not a.exists():
        continue
    ta, tb = a.read_text(encoding="utf-8", errors="replace"), b.read_text(encoding="utf-8", errors="replace")
    ma, mb = (RX_MAIN.search(x) for x in (ta, tb))
    ca, cb = (m.group(1) if m else "" for m in (ma, mb))
    dif = [f"{nome}: {conta(rx, ca)} x {conta(rx, cb)}" for nome, rx in MEDIDAS.items() if conta(rx, ca) != conta(rx, cb)]
    if dif:
        problema(f"{r}: estrutura diferente (pt x en): {'; '.join(dif)}")
    n_est += 1
    for t_, cod, lado in ((ta, "pt-BR", "pt"), (tb, "en-GB", "en")):
        if f'lang="{cod}"' not in t_[:400]:
            problema(f"{r} ({lado}): sem lang=\"{cod}\"")
        if "seletor-idioma" not in t_:
            problema(f"{r} ({lado}): sem o seletor de idioma")
print(f"  {n_est} pares conferidos")

# ---------------------------------------------------------------------------
# 4. Números
# ---------------------------------------------------------------------------
print("\n4. Números de cada par de páginas")
MESES_PT = {"jan": 1, "fev": 2, "mar": 3, "abr": 4, "mai": 5, "jun": 6, "jul": 7, "ago": 8, "set": 9, "out": 10, "nov": 11, "dez": 12}
MESES_EN = {"jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6, "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
            "january": 1, "february": 2, "march": 3, "april": 4, "june": 6, "july": 7, "august": 8, "september": 9, "october": 10,
            "november": 11, "december": 12}
ID_FIXOS = re.compile(r"\b(?:Lei|Law)\s+\d+\.\d+/\d{4}|\bD-25-02928\b|\bMT\d{7}\b|\b10\.\d{4,9}/[^\s;,)]+|\barXiv:\S+"
                      r"|\b(?:Vers[aã]o|Version|vers[aã]o|version)\s+\d+(?:\.\d+)+")
MESES_PT_NOME = {"janeiro": 1, "fevereiro": 2, "março": 3, "abril": 4, "maio": 5, "junho": 6, "julho": 7, "agosto": 8, "setembro": 9,
                 "outubro": 10, "novembro": 11, "dezembro": 12}
RX_MES_PT = "|".join(MESES_PT_NOME)
LIMITE = r"(?<![\w.,/-])"


def numeros(txt: str, ingles: bool) -> Counter:
    c = Counter()
    t = ID_FIXOS.sub(" ", txt)
    t = t.replace("−", "-")
    if ingles:
        t = re.sub(r"\b(\d{1,2}) (January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Oct|Nov|Dec) (\d{4})\b",
                   lambda m: f" data{m.group(3)}{MESES_EN[m.group(2).lower()]:02d}{int(m.group(1)):02d} ", t)
        t = re.sub(r"\b(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Oct|Nov|Dec) (\d{4})\b",
                   lambda m: f" mes{m.group(2)}{MESES_EN[m.group(1).lower()]:02d} ", t)
        t = re.sub(r"(\d+)(?:st|nd|rd|th)\b", r"\1", t)
        t = t.replace("1:250,000", "1:250 ")
    else:
        t = re.sub(r"\b(\d{2})/(\d{2})/(\d{4})\b", lambda m: f" data{m.group(3)}{m.group(2)}{m.group(1)} ", t)
        t = re.sub(rf"\b(\d{{1,2}}) de ({RX_MES_PT}) de (\d{{4}})\b",
                   lambda m: f" data{m.group(3)}{MESES_PT_NOME[m.group(2)]:02d}{int(m.group(1)):02d} ", t)
        t = re.sub(rf"\b({RX_MES_PT}) de (\d{{4}})\b", lambda m: f" mes{m.group(2)}{MESES_PT_NOME[m.group(1)]:02d} ", t)
        t = re.sub(r"\b(jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez)/(\d{4})\b", lambda m: f" mes{m.group(2)}{MESES_PT[m.group(1)]:02d} ", t)
        t = re.sub(r"(\d+)[ºª]", r"\1", t)
        t = t.replace("1:250 mil", "1:250 ")
    for d in re.findall(r"\b(?:data|mes)\d+\b", t):
        c[d] += 1
    t = re.sub(r"\b(?:data|mes)\d+\b", " ", t)
    rx = (LIMITE + r"-?\d{1,3}(?:,\d{3})+(?:\.\d+)?(?!\w)|" + LIMITE + r"-?\d+\.\d+(?!\w)|" + LIMITE + r"-?\d+(?!\w)") if ingles \
        else (LIMITE + r"-?\d{1,3}(?:\.\d{3})+(?:,\d+)?(?!\w)|" + LIMITE + r"-?\d+,\d+(?!\w)|" + LIMITE + r"-?\d+(?!\w)")
    for m in re.findall(rx, t):
        v = m.replace(",", "") if ingles else m.replace(".", "").replace(",", ".")
        c[round(float(v), 8)] += 1
    return c


# Trocas legítimas: (página, valor, motivo). Valor = número normalizado que só aparece num dos lados.
EXCECOES_NUMEROS: list[tuple[str, object, str]] = [
    ("indicadores/estab_af_46504.html", 2017.0, "o português repete 'Censo 2017' na mesma frase da nota da categoria 46504; o inglês menciona o ano uma vez"),
    ("indicadores/pct_estab_46504.html", 2017.0, "o português repete 'Censo 2017' na mesma frase da nota da categoria 46504; o inglês menciona o ano uma vez"),
    ("indicadores/pct_area_46504.html", 2017.0, "o português repete 'Censo 2017' na mesma frase da nota da categoria 46504; o inglês menciona o ano uma vez"),
]


def excecao_num(r, v) -> bool:
    return any((p == r or p == "*") and x == v for p, x, _ in EXCECOES_NUMEROS)


# Inglês corrente escreve por extenso os números pequenos: "3 biomas" pode ser "three biomes". Isso só resolve
# diferença em inteiros de 1 a 12, e só quando a palavra existe na página do outro idioma.
PAL_EN = {"one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12}
PAL_PT = {"um": 1, "uma": 1, "dois": 2, "duas": 2, "três": 3, "quatro": 4, "cinco": 5, "seis": 6, "sete": 7, "oito": 8, "nove": 9, "dez": 10, "onze": 11, "doze": 12}


def por_extenso(txt: str, pal: dict) -> Counter:
    return Counter(pal[m.lower()] for m in re.findall(r"\b(" + "|".join(pal) + r")\b", txt, re.I))


def resolver_extenso(so: dict, ext: Counter) -> dict:
    saida = {}
    for k, v in so.items():
        resta = v - ext[k] if isinstance(k, float) else v
        if resta > 0:
            saida[k] = resta
    return saida


total_pag_ok, total_dif = 0, 0
detalhes = {}
for r in PAGINAS:
    a, b = SITE / r, SITE / "en" / r
    if not a.exists():
        continue
    ta, tb = a.read_text(encoding="utf-8", errors="replace"), b.read_text(encoding="utf-8", errors="replace")
    ca, cb = numeros(visivel(ta), False), numeros(visivel(tb), True)
    # Textos iguais nos dois lados (dado bruto da tabela, DOI, título de obra) saem antes da leitura dos números,
    # porque o formato deles não depende do idioma.
    wa, wb = Counter(widgets_txt(ta)), Counter(widgets_txt(tb))
    comum = wa & wb
    for s, n in (wa - comum).items():
        for _ in range(n):
            ca += numeros(s, False)
    for s, n in (wb - comum).items():
        for _ in range(n):
            cb += numeros(s, True)
    so_pt = {k: v - cb[k] for k, v in ca.items() if v > cb[k] and not excecao_num(r, k)}
    so_en = {k: v - ca[k] for k, v in cb.items() if v > ca[k] and not excecao_num(r, k)}
    so_pt = resolver_extenso(so_pt, por_extenso(visivel(tb), PAL_EN))
    so_en = resolver_extenso(so_en, por_extenso(visivel(ta), PAL_PT))
    if so_pt or so_en:
        total_dif += 1
        detalhes[r] = (so_pt, so_en)
        problema(f"{r}: números diferentes; só em português: {list(so_pt.items())[:8]}; só em inglês: {list(so_en.items())[:8]}")
    else:
        total_pag_ok += 1
if DETALHES:
    for r, (x, y) in detalhes.items():
        print(f"  {r}\n    só pt: {sorted(x.items(), key=str)}\n    só en: {sorted(y.items(), key=str)}")
print(f"  {total_pag_ok} pares sem divergência; {total_dif} com divergência")

# ---------------------------------------------------------------------------
# 5. Sobras de português
# ---------------------------------------------------------------------------
print("\n5. Sobras de português em _site/en/")
RX_PT = re.compile(r"\b(não|nao|são|também|através|município|municípios|estabelecimento|estabelecimentos|agricultura|familiar|porém|além|"
                   r"para|pela|pelo|pelos|pelas|uma|umas|com|que|nas|nos|aos|dados|fonte|tabela|mediana|rótulo|rótulos|bioma|biomas|posse|"
                   r"reforma|agrária|assentamento|assentamentos|assentados|desmatamento|emissões|remoções|indicador|indicadores|área|áreas|"
                   r"sede|página|páginas|valor|valores|ano|anos|tipo|tipos|sigilo|disponível|preliminar|versão|equipe|projeto|resultados|"
                   r"até|então|entre|sobre|cada|mais|menos|maior|menor|segundo|conforme|sem|ou)\b", re.I)
# Trechos que podem ficar em português, cada um com o motivo
PERMITIDOS = [
    (r"Instituto Clima e Sociedade", "nome próprio"), (r"Observat[oó]rio do Clima", "nome próprio"),
    (r"UNIVERSIDADE DO ESTADO DE MATO GROSSO", "autoria institucional na citação"), (r"Universidade do Estado de Mato Grosso", "nome próprio no logo"),
    (r"(?:Valor|Sinal|Fonte)\s+column", "nome real da coluna no CSV, em português nos downloads"),
    (r"Banco da Terra", "nome próprio do programa"), (r"Vale do Arinos", "nome próprio"), (r"Nossa Senhora Aparecida|N\. Sra\. Aparecida", "nome próprio"),
]
# Páginas cujas tabelas trazem títulos de obras no idioma original (só metadados bibliográficos)
PAGINAS_BIBLIOGRAFIA = {"literatura/estudos.html", "literatura/carbono.html", "literatura/saf-psa.html", "biblioteca/index.html"}
NOMES_MUN = []
p_mun = REPO / "dados_site" / "municipios.csv"
if p_mun.exists():
    import csv
    with open(p_mun, encoding="utf-8", newline="") as f:
        NOMES_MUN = [r["municipio"] for r in csv.DictReader(f)]
RX_NOMES = re.compile("|".join(re.escape(n) for n in sorted(NOMES_MUN, key=len, reverse=True))) if NOMES_MUN else None
RX_ATRIB = re.compile(r'\b(?:title|aria-label|data-tip|alt|placeholder|label)="([^"]*)"')
RX_META = re.compile(r'<meta name="description" content="([^"]*)"|<title>([^<]*)</title>')
RX_CITACAO = re.compile(r"^[A-ZÀ-Ý][A-ZÀ-Ý-]{2,}, [A-Z]")
sobras = defaultdict(Counter)


def limpar(s: str) -> str:
    if RX_NOMES:
        s = RX_NOMES.sub(" ", s)
    for rx, _ in PERMITIDOS:
        s = re.sub(rx, " ", s)
    return s


def scan(rel, s):
    if not s or not s.strip():
        return
    s_ = limpar(s)
    achou = RX_PT.findall(s_)
    if not achou:
        return
    # Inglês tem "com", "para", "sem" etc. só em contextos raros; exigir um sinal adicional em textos longos
    trecho = re.sub(r"\s+", " ", s).strip()
    if RX_CITACAO.match(trecho):   # referência bibliográfica: título no idioma original
        return
    if len(set(w.lower() for w in achou)) >= 2 or len(trecho) < 120:
        sobras[rel][trecho[:170]] += 1


n_scan = 0
for r in PAGINAS:
    t = (SITE / "en" / r).read_text(encoding="utf-8", errors="replace")
    n_scan += 1
    for m in RX_META.finditer(t):
        scan(r, html.unescape(m.group(1) or m.group(2) or ""))
    for linha in visivel(t).split("\n"):
        scan(r, linha)
    m = RX_MAIN.search(t)
    for a_ in RX_ATRIB.findall(m.group(1) if m else ""):
        scan(r, html.unescape(a_))
    if r not in PAGINAS_BIBLIOGRAFIA:
        for s in textos_tela_widget(t):
            scan(r, s)
for r, c in sorted(sobras.items()):
    problema(f"{r}: {sum(c.values())} trecho(s) que parecem em português; ex.: {' | '.join(list(c)[:4])}")
    if DETALHES:
        for s_ in list(c)[:15]:
            print(f"    {r}: {sorted(set(w.lower() for w in RX_PT.findall(limpar(s_))))} <- {s_}")
print(f"  {n_scan} páginas varridas; {len(sobras)} com possíveis sobras")

# ---------------------------------------------------------------------------
print()
if PROBLEMAS:
    print(f"{len(PROBLEMAS)} problema(s):")
    for p_ in PROBLEMAS[:120]:
        print(f"  - {p_}")
    if len(PROBLEMAS) > 120:
        print(f"  ... e mais {len(PROBLEMAS) - 120}")
    sys.exit(1)
print("Versão em inglês conferida: nenhum problema encontrado.")
