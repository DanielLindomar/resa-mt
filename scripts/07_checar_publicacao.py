# -*- coding: utf-8 -*-
"""
07_checar_publicacao.py - Observatório RESA-MT

Varredura antes de publicar. Roda na raiz do repositório, depois do
"quarto render":

  python -I scripts/07_checar_publicacao.py

Para com código 1 se achar qualquer problema. São cinco partes.

1. TERMOS PROIBIDOS em todo o repositório, inclusive _site/, _freeze/,
   scripts e README (conteúdo e nome de cada arquivo): links e IDs do Google
   Drive, a pasta do Drive, e-mails institucionais e pessoais, caminhos locais,
   CPF e CNPJ, bases comerciais licenciadas, outros termos vetados pelo projeto,
   as marcas de rascunho dos manuscritos e a série manual antiga do PRODES.
   Arquivos .rds (gzip) são lidos já descompactados. Ficam fora da varredura
   só .git/ e as pastas ocultas locais da raiz (como .quarto/), que o
   .gitignore tira do controle de versão e o Quarto não publica; .github/
   entra. Os termos vetados ficam neste arquivo só como hash SHA-256 (lista
   A e lista B), e os demais padrões são montados por partes, para o script
   não acusar a si mesmo. Falsos positivos legítimos só passam se estiverem
   na lista EXCECOES abaixo, cada um com o motivo.

2. SINAIS DO IBGE nos dados publicados. Nenhum X (sigilo), – (zero absoluto)
   ou ... (não disponível) pode virar 0, número ou célula vazia:
   a) dados_site/valores.csv: vocabulário dos sinais; a célula do número traz
      o número ou, sem número, o próprio sinal;
   b) todo CSV do repositório com os pares <coluna> + sinal_<coluna> ou
      valor + sinal (mesma regra);
   c) os downloads de indicadores contra dados_site/valores.csv;
   d) as tabelas interativas (reactable) gravadas nas páginas de _site/;
   e) os mapas (leaflet) de _site/: município com a dica "X (sigilo IBGE)"
      tem de estar pintado com a cor de X de R/funcoes.R (COR_X);
   f) dados_site/serie.rds e ultimos.rds, se o Rscript for encontrado
      (variável RSCRIPT, PATH ou instalação padrão do R);
   g) se a raiz das fontes estiver informada (RESA_FONTES ou config.local.toml),
      toda célula X da fonte do IBGE continua X no download do Censo 2017.

3. ALINHAMENTO LINHA A LINHA. Em toda tabela interativa com municípios e
   indicadores (índice de municípios, páginas de indicador, Posse, Dados e os
   141 perfis) e nos mapas das páginas de indicador, cada linha é casada pelo
   nome ou código do município com dados_site/valores.csv: o número guardado
   e o texto mostrado (valor ou sinal) têm de ser os do mesmo município.

4. LINKS INTERNOS de _site/: todo href/src relativo (inclusive dentro das
   tabelas e mapas) aponta para um arquivo que existe, toda âncora #id existe
   na página de destino, todo clique de mapa abre um perfil que existe e toda
   figura publicada em resultados/figuras/ é usada por alguma página.

5. ELEMENTOS OBRIGATÓRIOS de cada página de _site/: meta robots
   noindex,nofollow, título, rodapé com o texto oficial e só o logo da UNEMAT,
   faixa de versão e nenhum NA/NaN/NULL/Inf no texto visível; robots.txt sem
   indexação e nenhum sitemap.
"""

import csv
import fnmatch
import glob
import gzip
import hashlib
import html
import json
import os
import re
import shutil
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):
    pass

REPO = Path(__file__).resolve().parents[1]
# Fora da varredura: .git/ e as pastas ocultas locais da raiz (fora do controle de versão pelo
# .gitignore e não publicadas); .github/ é versionada e entra.
OCULTAS = sorted(d.name for d in REPO.iterdir() if d.is_dir() and d.name.startswith(".") and d.name != ".github")
TRACO = "–"         # – (zero absoluto)
SINAIS = {"valor", "X", TRACO, "..."}

PROBLEMAS: list[str] = []
AVISOS: list[str] = []


def problema(msg: str) -> None:
    PROBLEMAS.append(msg)


def j(*partes: str) -> str:
    """Junta partes de um termo (assim o termo inteiro não aparece neste arquivo)."""
    return "".join(partes)


# ---------------------------------------------------------------------------
# 1. Termos proibidos
# ---------------------------------------------------------------------------
I = re.IGNORECASE
TERMOS = [
    # (rótulo, expressão regular, flags)
    ("link do Google Drive", re.escape(j("drive", ".", "google")), I),
    ("link do Google Docs", re.escape(j("docs", ".", "google")), I),
    ("atalho do Drive", re.escape(j("shortcut", "-targets")), I),
    ("ID de pasta ou arquivo do Drive", j("/(folders|file/d)", "/[A-Za-z0-9_-]{25,}"), 0),
    ("pasta do Drive", j("Meu", r"(\s|%20|\+|&nbsp;)", "Drive"), I),
    ("e-mail institucional", re.escape(j("@", "unemat")), I),
    ("e-mail pessoal", re.escape(j("@", "gmail")), I),
    ("caminho local (Windows)", j(r"\b[A-Za-z]:(\\\\|\\|/|%5C|%2F)+", "Users", r"\b"), I),
    ("caminho local (Git Bash)", j(r"/[a-z]/", "Users/"), I),
    ("CPF", r"(?<![\d.])\d{3}\.\d{3}\.\d{3}-\d{2}(?![\d-])", 0),
    ("CNPJ", r"(?<![\d.])\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}(?![\d-])", 0),
    ("CPF ou CNPJ sem pontuação", j(r"\b(C", "PF|CN", r"PJ)\b\W{0,5}\d{11,14}\b"), I),
    ("marca de rascunho", j(r"\bPEND", r"ENTE\b"), 0),
    ("marca de rascunho", re.escape(j("(confir", "mar)")), I),
    ("série manual antiga do PRODES", re.escape(j("ANTIGO", "_manual")), I),
]
TERMOS = [(r, re.compile(p, f)) for r, p, f in TERMOS]

# Termos vetados, guardados só como hash (SHA-256 da palavra em minúsculas; 24 primeiros dígitos).
# Uma palavra do texto é: letras (com ou sem acento) e algarismos seguidos.
ROT_A = "base comercial licenciada (lista A)"
ROT_B = "termo vetado (lista B)"
HASH_VETADOS = {
    "9b66ebf8bce2099dfa88d9bf": ROT_A, "64469c596b2d8211edd9bb38": ROT_A, "21bd015e3675d54677332426": ROT_A,
    "c857d09db23e6822e3600bc0": ROT_B, "57de4cf40144bdf7d00010f2": ROT_B, "afb812d3ea7146079bebf27a": ROT_B,
    "82da49ee984b8f3bcee2d0ad": ROT_B,
}
RX_PALAVRA = re.compile(r"[0-9a-zà-ÿ]+")
_hash_cache: dict[str, str] = {}


def vetados(texto: str) -> dict[str, str]:
    """Palavras do texto cujo hash está na lista; devolve {palavra: rótulo}."""
    out = {}
    for w in set(RX_PALAVRA.findall(texto.lower())):
        h = _hash_cache.get(w)
        if h is None:
            h = _hash_cache[w] = hashlib.sha256(w.encode("utf-8")).hexdigest()[:24]
        if h in HASH_VETADOS:
            out[w] = HASH_VETADOS[h]
    return out


# Falsos positivos legítimos: (caminho relativo ou glob, rótulo do termo, motivo).
# Só entram aqui casos conferidos à mão.
EXCECOES = [
    ("*site_libs/bootstrap/bootstrap-icons.css", ROT_B,
     "biblioteca Bootstrap Icons (terceiros): a lista de ícones de marcas inclui uma classe com uma palavra da lista B"),
    ("*site_libs/react-*/AUTHORS", "e-mail pessoal",
     "lista pública de autores da biblioteca React (terceiros), que acompanha a tabela interativa"),
]


def excecao(rel: str, rotulo: str) -> bool:
    return any(rotulo == t and (rel == p or fnmatch.fnmatch(rel, p)) for p, t, _ in EXCECOES)


def ler_texto(p: Path) -> str:
    b = p.read_bytes()
    if p.suffix.lower() in (".rds", ".gz"):
        try:
            b = gzip.decompress(b)
        except OSError:
            pass
    return b.decode("utf-8", errors="replace")


def arquivos_repo():
    for raiz, dirs, nomes in os.walk(REPO):
        if Path(raiz) == REPO:
            dirs[:] = [d for d in dirs if d != ".git" and d not in OCULTAS]
        else:
            dirs[:] = [d for d in dirs if d != ".git"]
        for n in nomes:
            yield Path(raiz) / n


def contexto(txt: str, ini: int, fim: int) -> str:
    t = txt[max(0, ini - 40):fim + 40].replace("\n", " ")
    return re.sub(r"\s+", " ", t)[:140]


print("1. Termos proibidos (todo o repositório, inclusive _site/ e _freeze/)")
if OCULTAS:
    print(f"  fora da varredura: .git/ e as pastas ocultas locais da raiz ({len(OCULTAS)}), "
          "fora do controle de versão e não publicadas")
n_arq, n_bytes = 0, 0
achados = defaultdict(list)
usadas = Counter()
for p in arquivos_repo():
    rel = p.relative_to(REPO).as_posix()
    n_arq += 1
    try:
        txt = ler_texto(p)
    except OSError as e:
        problema(f"não consegui ler {rel}: {e}")
        continue
    n_bytes += len(txt)
    for alvo, texto in (("nome", rel), ("conteúdo", txt)):
        for rotulo, rx in TERMOS:
            for m in rx.finditer(texto):
                if excecao(rel, rotulo):
                    usadas[(rel, rotulo)] += 1
                    continue
                achados[(rotulo, rel)].append(f"{alvo}: ...{contexto(texto, m.start(), m.end())}...")
        for w, rotulo in vetados(texto).items():
            if excecao(rel, rotulo):
                usadas[(rel, rotulo)] += 1
                continue
            m = re.search(r"(?<![0-9a-zà-ÿ])" + re.escape(w) + r"(?![0-9a-zà-ÿ])", texto.lower())
            achados[(rotulo, rel)].append(f"{alvo}: ...{contexto(texto, m.start(), m.end())}..." if m else alvo)
print(f"  {n_arq} arquivos, {n_bytes / 1e6:.1f} milhões de caracteres")
for (rotulo, rel), ocorr in sorted(achados.items()):
    problema(f"{rotulo} em {rel} ({len(ocorr)}x): {ocorr[0]}")
    print(f"  ERRO  {rotulo} em {rel} ({len(ocorr)}x): {ocorr[0]}")
for p_, t_, motivo in EXCECOES:
    n = sum(v for (r, t), v in usadas.items() if t == t_ and (r == p_ or fnmatch.fnmatch(r, p_)))
    print(f"  exceção  {p_} · {t_} · {n} arquivo(s) ou ocorrência(s) · {motivo}")
if not achados:
    print("  ok  nenhum termo proibido fora das exceções")

# ---------------------------------------------------------------------------
# 2. Sinais do IBGE nos dados publicados
# ---------------------------------------------------------------------------
print("\n2. Sinais do IBGE (X, – e ... nunca viram 0, número ou célula vazia)")


def ler_csv(p: Path):
    with open(p, encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def eh_numero(s) -> bool:
    if s is None:
        return False
    s = str(s).strip()
    if s == "":
        return False
    try:
        float(s.replace(",", "."))
        return True
    except ValueError:
        return False


# a) valores.csv
VAL = ler_csv(REPO / "dados_site" / "valores.csv")
cont = Counter(r["sinal"] for r in VAL)
fora = set(cont) - SINAIS
if fora:
    problema(f"valores.csv: sinal fora do vocabulário: {sorted(fora)}")
sinal_errado = [r for r in VAL if r["sinal"] in ("X", TRACO, "...") and r["valor"].strip() != r["sinal"]]
valor_vazio = [r for r in VAL if r["sinal"] == "valor" and not eh_numero(r["valor"])]
sem_sinal = [r for r in VAL if r["sinal"].strip() == ""]
for nome, lst in [("X, – ou ... sem o próprio sinal na célula do número (número, 0 ou vazio)", sinal_errado),
                  ("'valor' sem número", valor_vazio), ("célula sem sinal", sem_sinal)]:
    if lst:
        problema(f"valores.csv: {len(lst)} células {nome}; ex.: {lst[0]}")
print(f"  a) valores.csv: {len(VAL)} células; X = {cont['X']}, – = {cont[TRACO]}, ... = {cont['...']}; "
      f"{'ok' if not (sinal_errado or valor_vazio or sem_sinal or fora) else 'ERRO'}")

# b) todo CSV com pares valor/sinal
n_csv, n_pares, n_x = 0, 0, 0
for p in sorted(arquivos_repo()):
    if p.suffix.lower() != ".csv":
        continue
    rel = p.relative_to(REPO).as_posix()
    try:
        linhas = ler_csv(p)
    except (UnicodeDecodeError, csv.Error) as e:
        problema(f"{rel}: CSV ilegível ({e})")
        continue
    if not linhas:
        continue
    n_csv += 1
    cols = list(linhas[0].keys())
    pares = []
    for c in cols:
        if c is None:
            continue
        cl = c.lower()
        if cl.startswith("sinal_") and c[6:] in cols:
            pares.append((c[6:], c))
        elif cl == "sinal":
            for v in ("valor", "Valor"):
                if v in cols:
                    pares.append((v, c))
    for vcol, scol in pares:
        n_pares += 1
        for i, r in enumerate(linhas, start=2):
            s = (r.get(scol) or "").strip()
            v = (r.get(vcol) or "").strip()
            if s == "":
                problema(f"{rel}, linha {i}: {scol} vazio (todo valor precisa de sinal)")
            elif s in ("X", TRACO, "..."):
                n_x += s == "X"
                if v != s:
                    problema(f"{rel}, linha {i}: {vcol} = '{v}' com sinal {s} (a célula tem de trazer o próprio sinal)")
            elif s == "valor":
                if not eh_numero(v):
                    problema(f"{rel}, linha {i}: {vcol} sem número com sinal 'valor'")
            else:
                problema(f"{rel}, linha {i}: sinal desconhecido '{s}' em {scol}")
print(f"  b) {n_csv} CSV lidos; {n_pares} pares valor/sinal; {n_x} células X conferidas")

# c) downloads de indicadores contra valores.csv
IND = {r["id"]: r for r in ler_csv(REPO / "dados_site" / "indicadores.csv")}
ULT = {}
for r in VAL:
    i = IND.get(r["indicador"])
    if i and str(r["ano"]) == str(i["ano_ref"]):
        ULT[(int(r["id_municipio"]), r["indicador"])] = r
n_c = 0
for p in [REPO / "arquivos" / "dados" / "resa_indicadores_municipios.csv",
          REPO / "_site" / "arquivos" / "dados" / "resa_indicadores_municipios.csv"]:
    if not p.exists():
        if "_site" in p.parts:
            AVISOS.append("_site/ ainda sem os downloads: rode quarto render antes")
        else:
            problema(f"falta {p.relative_to(REPO).as_posix()}")
        continue
    for r in ler_csv(p):
        for c in r:
            if c and c.startswith("sinal_"):
                ind = c[6:]
                u = ULT.get((int(r["id_municipio"]), ind))
                if u is None:
                    continue
                n_c += 1
                if u["sinal"] != r[c] or (u["sinal"] != "valor" and r[ind] != u["sinal"]) or \
                        (u["sinal"] == "valor" and abs(float(r[ind]) - float(u["valor"])) > 1e-6 * max(1.0, abs(float(u["valor"])))):
                    problema(f"{p.relative_to(REPO).as_posix()}: {ind} em {r['id_municipio']} = '{r[ind]}' / '{r[c]}' no "
                             f"download e '{u['valor']}' / '{u['sinal']}' em valores.csv")
print(f"  c) downloads de indicadores: {n_c} células conferidas com valores.csv (valor e sinal)")

# d) e e) tabelas e mapas gravados nas páginas
COR_X = None
m = re.search(r'^COR_X\s*<-\s*"(#[0-9a-fA-F]{6})"', (REPO / "R" / "funcoes.R").read_text(encoding="utf-8"), re.M)
if m:
    COR_X = m.group(1).lower()
else:
    problema("não achei COR_X em R/funcoes.R")
RX_WIDGET = re.compile(r'<script type="application/json" data-for="[^"]*">(.*?)</script>', re.S)
n_pag, n_tab, n_tab_sinal, n_mapas, n_pol_x = 0, 0, 0, 0, 0
paginas = (sorted(p for p in (REPO / "_site").rglob("*.html") if "site_libs" not in p.parts)
           if (REPO / "_site").exists() else [])
if not paginas:
    AVISOS.append("_site/ sem páginas: as checagens d), e) e 3 não rodaram")
WIDGETS: dict[Path, list] = {}


def widgets(pg: Path) -> list:
    if pg not in WIDGETS:
        out = []
        for bloco in RX_WIDGET.findall(pg.read_text(encoding="utf-8", errors="replace")):
            try:
                out.append(json.loads(bloco))
            except json.JSONDecodeError:
                continue
        WIDGETS[pg] = out
    return WIDGETS[pg]


def sinal_de(v) -> str:
    """Texto de uma célula de tabela (texto puro ou HTML com span.sinal)."""
    if v is None:
        return ""
    t = html.unescape(re.sub(r"<[^>]+>", "", str(v))).strip()
    return t


for pg in paginas:
    rel = pg.relative_to(REPO).as_posix()
    n_pag += 1
    for w in widgets(pg):
        x = w.get("x", {}) if isinstance(w, dict) else {}
        tag = x.get("tag", {}) if isinstance(x, dict) else {}
        # reactable
        if isinstance(tag, dict) and tag.get("name") == "Reactable":
            n_tab += 1
            dados = tag.get("attribs", {}).get("data", {})
            if not isinstance(dados, dict):
                continue
            cols = list(dados)
            pares = []
            for c in cols:
                cl = c.lower()
                if cl.startswith("sinal_") and c[6:] in cols:
                    pares.append((c[6:], c))
                elif cl == "sinal":
                    pares += [(v, c) for v in cols if v.lower() == "valor"]
            if pares:
                n_tab_sinal += 1
            for vcol, scol in pares:
                for k, (v, s) in enumerate(zip(dados[vcol], dados[scol])):
                    s = sinal_de(s)
                    if s not in ("X", TRACO, "..."):
                        continue
                    vt = sinal_de(v)   # texto da célula, sem HTML
                    if vt != s:
                        problema(f"{rel}: tabela com {vcol} = {vt!r} e sinal {s} (linha {k + 1})")
        # leaflet
        calls = x.get("calls", []) if isinstance(x, dict) else []
        if isinstance(calls, list) and any(isinstance(c, dict) and c.get("method") == "addPolygons" for c in calls):
            n_mapas += 1
            for c in calls:
                if not (isinstance(c, dict) and c.get("method") == "addPolygons"):
                    continue
                args = c.get("args", [])
                opc = next((a for a in args if isinstance(a, dict) and "fillColor" in a), None)
                rot = next((a for a in args if isinstance(a, list) and a and all(isinstance(t, str) for t in a)
                            and any("<b>" in t or "<br>" in t for t in a)), None)
                if opc is None or rot is None:
                    continue
                cores = opc["fillColor"]
                if isinstance(cores, str):
                    cores = [cores] * len(rot)
                if len(cores) != len(rot):
                    continue
                for t, cor in zip(rot, cores):
                    tem_x = "X (sigilo IBGE)" in html.unescape(t)
                    if tem_x:
                        n_pol_x += 1
                        if COR_X and str(cor).lower()[:7] != COR_X:
                            problema(f"{rel}: município com 'X (sigilo IBGE)' pintado com {cor} (esperado {COR_X})")
print(f"  d) {n_pag} páginas; {n_tab} tabelas interativas, {n_tab_sinal} com coluna de sinal")
print(f"  e) {n_mapas} mapas com municípios; {n_pol_x} municípios com X conferidos (cor {COR_X})")

# f) .rds, pelo R
rscript = os.environ.get("RSCRIPT") or shutil.which("Rscript")
if not rscript:
    cand = sorted(glob.glob(j("C:", "/Program Files/R/R-*/bin/Rscript.exe")))
    rscript = cand[-1] if cand else None
if rscript:
    codigo = (
        'tr <- "\\u2013"; s <- readRDS("dados_site/serie.rds"); u <- readRDS("dados_site/ultimos.rds")$ultimos;'
        'f <- function(d) sum(d$sinal == "X" & (!is.na(d$valor) | !is.na(d$valor_calc)));'
        'g <- function(d) sum(d$sinal == "..." & (!is.na(d$valor) | !is.na(d$valor_calc)));'
        'h <- function(d) sum(d$sinal == tr & (!is.na(d$valor) | is.na(d$valor_calc) | d$valor_calc != 0));'
        'cat(f(s), g(s), h(s), f(u), g(u), h(u), sum(s$sinal == "X"), "\\n")')
    try:
        r = subprocess.run([rscript, "--vanilla", "-e", codigo], cwd=REPO, capture_output=True, text=True,
                           encoding="utf-8", timeout=300)
        nums = r.stdout.strip().split()
        if r.returncode != 0 or len(nums) != 7:
            problema(f"leitura dos .rds falhou: {r.stderr.strip()[-300:]}")
        else:
            a, b, c, d, e, f_, nx = map(int, nums)
            if a or d:
                problema(f".rds: {a + d} células X com valor ou valor_calc (deveriam ser NA)")
            if b or e:
                problema(f".rds: {b + e} células ... com valor ou valor_calc")
            if c or f_:
                problema(f".rds: {c + f_} células – sem valor_calc = 0")
            print(f"  f) serie.rds e ultimos.rds: {nx} células X; "
                  f"{'ok' if not (a or b or c or d or e or f_) else 'ERRO'}")
    except (OSError, subprocess.SubprocessError) as e:
        AVISOS.append(f"não consegui rodar o R para conferir os .rds ({e})")
else:
    AVISOS.append("Rscript não encontrado: a checagem f) dos .rds não rodou (defina RSCRIPT)")


# g) fonte do IBGE -> download do Censo 2017
def raiz_fontes():
    v = os.environ.get("RESA_FONTES")
    if v:
        return Path(v)
    cfg = REPO / "config.local.toml"
    if cfg.exists():
        m_ = re.search(r'^\s*resa_fontes\s*=\s*"([^"]+)"', cfg.read_text(encoding="utf-8"), re.M)
        if m_:
            return Path(m_.group(1))
    return None


# Nome da coluna no download quando difere do nome da variável na fonte (categoria 46504 pelo código)
NOME_DL = {"n_estab_AF_assent": "n_estab_AF_46504", "area_AF_assent": "area_AF_46504", "pocup_assent": "pocup_46504"}
F = raiz_fontes()
fonte_x = None
if F is not None:
    fonte_x = F / "4_Outputs" / "artigos" / "01_Manuscrito_1_LUP_Corrigido" / "02_Dados_extraidos" / "sidra_raw_status_long.csv"
if fonte_x is not None and fonte_x.exists():
    dl = {r["id_municipio"]: r for r in ler_csv(REPO / "arquivos" / "dados" / "resa_censo2017_af_municipios.csv")}
    n_g, n_fora = 0, Counter()
    for r in ler_csv(fonte_x):
        if not r["status"].startswith("X"):
            continue
        d = dl.get(str(int(r["cod_ibge"])))
        var = NOME_DL.get(r["variavel"], r["variavel"])
        col = "sinal_" + var
        if d is None or col not in d:
            n_fora[r["variavel"]] += 1
            continue
        n_g += 1
        if d[col] != "X" or (d.get(var) or "").strip() != "X":
            problema(f"download do Censo 2017: {var} em {r['cod_ibge']} é X na fonte e "
                     f"'{d[col]}' / '{d.get(var)}' no download")
    print(f"  g) fonte do IBGE: {n_g} células X conferidas no download do Censo 2017 "
          f"({sum(n_fora.values())} células X de variáveis que não estão no download)")
else:
    AVISOS.append("raiz das fontes não informada (RESA_FONTES ou config.local.toml): a checagem g) não rodou")

# ---------------------------------------------------------------------------
# 3. Alinhamento linha a linha: tabelas e mapas contra valores.csv
# ---------------------------------------------------------------------------
print("\n3. Alinhamento linha a linha (cada linha com os números do próprio município)")
MUNS = ler_csv(REPO / "dados_site" / "municipios.csv")
NOME_ID = {r["municipio"]: int(r["id_municipio"]) for r in MUNS}
SLUG_ID = {r["slug"]: int(r["id_municipio"]) for r in MUNS}
ROT_IND = {r["rotulo"]: k for k, r in IND.items()}
# colunas da tabela municipal da página Posse (R/pag_resultados.R, tabela_posse_municipal)
COL_POSSE = {"e_v": "estab_af_46504", "p_v": "pct_estab_46504", "a_v": "pct_area_46504", "n_v": "n_pa", "f_v": "fam_pa"}
MULT = {"mil": 1e3, "mi": 1e6, "bi": 1e9}


def sem_numero(d) -> bool:
    """Célula numérica sem número no JSON da tabela: null ou o texto "NA" (como o reactable grava o NA do R)."""
    return d is None or d == "NA"
# casas decimais do número no CSV das tabelas de indicador (R/pag_municipios.R, DEC_CSV) e do explorador (dados/index.qmd)
DEC_RECORTE = {"int": 0, "dec1": 3, "dec2": 4, "dec3": 5, "pct1": 4, "pct2": 5, "brl": 2, "brl_mil": 3, "usd": 2}
DEC_EXPLORADOR = {"int": 0, "dec1": 1, "dec2": 2, "dec3": 3, "pct1": 1, "pct2": 2, "brl": 0, "brl_mil": 0, "usd": 0}


def confere_csv(vt, mid: int, ind: str, dec: dict):
    """Célula do número no CSV de uma tabela: o próprio sinal, ou o número arredondado."""
    e = esperado(mid, ind)
    if e is None:
        return None
    vt = "" if vt is None else str(vt)
    if e[0] != "valor":
        return None if vt == e[0] else f"CSV com {vt!r}, esperado {e[0]}"
    if not eh_numero(vt):
        return f"CSV com {vt!r}, esperado um número"
    tol = 0.5 * 10 ** (-dec[IND[ind]["fmt"]]) * 1.001 + 1e-9
    return None if abs(float(vt) - e[1]) <= tol else f"CSV com {vt!r}, esperado {e[1]:g}"


def confere_arredondado(d, mid: int, ind: str, dec: dict):
    """Número guardado já arredondado (ordenação do explorador): None quando há sinal."""
    e = esperado(mid, ind)
    if e is None:
        return None
    if e[0] != "valor":
        return None if sem_numero(d) else f"guarda {d!r}, esperado sem número ({e[0]})"
    if sem_numero(d) or isinstance(d, str):
        return f"guarda {d!r}, esperado {e[1]:g}"
    tol = 0.5 * 10 ** (-dec[IND[ind]["fmt"]]) * 1.001 + 1e-9
    return None if abs(float(d) - e[1]) <= tol else f"guarda {d!r}, esperado {e[1]:g}"


def esperado(mid: int, ind: str):
    """(sinal, valor como número ou None, valor_calc) em valores.csv, no ano de referência."""
    u = ULT.get((mid, ind))
    if u is None:
        return None
    if u["sinal"] == "valor":
        v = float(u["valor"])
        return "valor", v, v
    return u["sinal"], None, (0.0 if u["sinal"] == TRACO else None)


def texto_celula(h) -> str:
    """Texto visível da célula, sem a linha de apoio (div.sub) e sem HTML."""
    if h is None:
        return ""
    t = re.sub(r'<div class="sub">.*?</div>', "", str(h), flags=re.S)
    return html.unescape(re.sub(r"<[^>]+>", "", t)).replace(" ", " ").strip()


def confere_texto(t: str, mid: int, ind: str, em_reais: bool = True):
    """Erro (texto) se o texto mostrado não for o valor ou o sinal do município; None se confere.
    em_reais: o valor em R$ mil aparece em reais (R$ 3,8 mi), como em fmt_valor(); no explorador
    da página Dados, aparece na unidade do dado (R$ mil), indicada na coluna Unidade."""
    e = esperado(mid, ind)
    if e is None:
        return None
    s, v, _ = e
    if s != "valor":
        return None if t == s else f"mostra {t!r}, esperado {s}"
    m_ = re.fullmatch(r"(?:R\$|US\$)?\s*(-?[\d.]+(?:,(\d+))?)\s*(mil|mi|bi)?\s*%?", t)
    if not m_:
        return f"mostra {t!r}, esperado um número"
    num_ = float(m_.group(1).replace(".", "").replace(",", "."))
    dec = len(m_.group(2) or "")
    mult = MULT.get(m_.group(3), 1.0)
    alvo = v * (1000 if IND[ind]["fmt"] == "brl_mil" and em_reais else 1)
    tol = 0.5 * 10 ** (-dec) * mult * 1.001 + 1e-6 * abs(alvo) + 1e-9
    return None if abs(num_ * mult - alvo) <= tol else f"mostra {t!r}, esperado {alvo:g}"


def confere_numero(d, mid: int, ind: str):
    e = esperado(mid, ind)
    if e is None:
        return None
    s, _, vc = e
    if vc is None:
        return None if sem_numero(d) else f"guarda {d!r}, esperado sem número ({s})"
    if sem_numero(d) or isinstance(d, str):
        return f"guarda {d!r}, esperado {vc:g}"
    return None if abs(float(d) - vc) <= 1e-6 * max(1.0, abs(vc)) else f"guarda {d!r}, esperado {vc:g}"


def nome_mun(h) -> str:
    t = re.sub(r'<div class="sub">.*?</div>', "", str(h), flags=re.S)
    t = re.sub(r'<span class="(tag-sede|sub)"[^>]*>.*?</span>', "", t, flags=re.S)
    return html.unescape(re.sub(r"<[^>]+>", "", t)).strip()


n_lin, n_cel, n_tab3, n_rot = 0, 0, 0, 0
erros_al = defaultdict(list)
for pg in paginas:
    rel = pg.relative_to(REPO).as_posix()
    rel_site = pg.relative_to(REPO / "_site").as_posix()
    m_pf = re.fullmatch(r"municipios/([a-z0-9-]+)\.html", rel_site)
    mid_pagina = SLUG_ID.get(m_pf.group(1)) if m_pf else None
    m_ind = re.fullmatch(r"indicadores/([a-z0-9_]+)\.html", rel_site)
    ind_pagina = m_ind.group(1) if m_ind and m_ind.group(1) in IND else None
    for w in widgets(pg):
        x = w.get("x", {}) if isinstance(w, dict) else {}
        tag = x.get("tag", {}) if isinstance(x, dict) else {}
        if isinstance(tag, dict) and tag.get("name") == "Reactable":
            at = tag.get("attribs", {})
            dados = at.get("data", {})
            if not isinstance(dados, dict) or not dados:
                continue
            cdef = {c.get("id"): c for c in at.get("columns", []) if isinstance(c, dict)}
            nl = len(next(iter(dados.values())))

            def textos(col):
                cel = cdef.get(col, {}).get("cell")
                return cel if isinstance(cel, list) and len(cel) == nl else dados.get(col)

            # linhas: código IBGE ou nome do município
            ids = None
            for ccod in ("id_municipio", "Código IBGE"):
                if ccod in dados:
                    ids = [int(v) for v in dados[ccod]]
                    break
            if ids is None:
                for cnome in ("Município", "municipio", "Municipio"):
                    if cnome in dados:
                        nomes = [nome_mun(v) for v in dados[cnome]]
                        if sum(n in NOME_ID for n in nomes) >= 0.9 * nl:
                            ids = [NOME_ID.get(n) for n in nomes]
                        break
            checou = False
            if ids is not None:
                # colunas com o id do indicador (índice de municípios) ou da página Posse
                for col in dados:
                    ind = col if col in IND else COL_POSSE.get(col)
                    if ind is None:
                        continue
                    tx = textos(col)
                    for k in range(nl):
                        if ids[k] is None:
                            continue
                        n_cel += 1
                        for err in (confere_numero(dados[col][k], ids[k], ind),
                                    confere_texto(texto_celula(tx[k]), ids[k], ind) if tx is not dados[col] else None):
                            if err:
                                erros_al[rel].append(f"linha {k + 1} ({ids[k]}), {ind}: {err}")
                    checou = True
                # tabelas de indicador (uma linha por município): indicador, sinal, valor (CSV), ordem e texto
                if "indicador" in dados and "sinal" in dados:
                    tx = textos("ordem") if "ordem" in dados else None
                    for k in range(nl):
                        ind = dados["indicador"][k]
                        e = esperado(ids[k], ind)
                        if e is None:
                            continue
                        n_cel += 1
                        errs = [None if dados["sinal"][k] == e[0] else f"sinal {dados['sinal'][k]!r}, esperado {e[0]}"]
                        if "valor" in dados:
                            errs.append(confere_csv(dados["valor"][k], ids[k], ind, DEC_RECORTE))
                        if "ordem" in dados:
                            errs.append(confere_numero(dados["ordem"][k], ids[k], ind))
                        if tx is not None and tx is not dados.get("ordem"):
                            errs.append(confere_texto(texto_celula(tx[k]), ids[k], ind))
                        for err in errs:
                            if err:
                                erros_al[rel].append(f"linha {k + 1} ({ids[k]}), {ind}: {err}")
                    checou = True
                # explorador da página Dados: rótulo do indicador, Sinal, Valor (CSV), Ordem e texto
                if "Indicador" in dados and "Sinal" in dados and "Valor" in dados:
                    tx = textos("Ordem") if "Ordem" in dados else None
                    for k in range(nl):
                        ind = ROT_IND.get(dados["Indicador"][k])
                        e = esperado(ids[k], ind) if ind else None
                        if e is None:
                            continue
                        n_cel += 1
                        errs = [None if dados["Sinal"][k] == e[0] else f"sinal {dados['Sinal'][k]!r}, esperado {e[0]}",
                                confere_csv(dados["Valor"][k], ids[k], ind, DEC_EXPLORADOR)]
                        if "Ordem" in dados:
                            errs.append(confere_arredondado(dados["Ordem"][k], ids[k], ind, DEC_EXPLORADOR))
                        if tx is not None and tx is not dados.get("Ordem"):
                            errs.append(confere_texto(texto_celula(tx[k]), ids[k], ind, em_reais=False))
                        for err in errs:
                            if err:
                                erros_al[rel].append(f"linha {k + 1} ({ids[k]}), {ind}: {err}")
                    checou = True
            # perfis: linhas = indicadores do município da página
            if mid_pagina and "Indicador" in dados and "Valor" in dados and ids is None:
                tx = textos("Valor")
                for k in range(nl):
                    m_h = re.search(r"indicadores/([a-z0-9_]+)\.html", str(dados["Indicador"][k]))
                    if not m_h or m_h.group(1) not in IND:
                        continue
                    n_cel += 1
                    err = confere_texto(texto_celula(tx[k]), mid_pagina, m_h.group(1))
                    if err:
                        erros_al[rel].append(f"linha {k + 1}, {m_h.group(1)}: {err}")
                checou = True
            if checou:
                n_tab3 += 1
                n_lin += nl
        # mapas das páginas de indicador: a dica de cada município traz o valor ou o sinal dele
        calls = x.get("calls", []) if isinstance(x, dict) else []
        if ind_pagina and isinstance(calls, list):
            for c in calls:
                if not (isinstance(c, dict) and c.get("method") == "addPolygons"):
                    continue
                rot = next((a for a in c.get("args", []) if isinstance(a, list) and a and all(isinstance(t, str) for t in a)
                            and any("<b>" in t for t in a)), None)
                for t in rot or []:
                    m_r = re.match(r"<b>(.*?)</b><br>(.*?)<br>", t)
                    mid = NOME_ID.get(html.unescape(m_r.group(1))) if m_r else None
                    if mid is None:
                        continue
                    n_rot += 1
                    txt = html.unescape(m_r.group(2)).strip()
                    e = esperado(mid, ind_pagina)
                    if e is None:
                        continue
                    if e[0] != "valor":
                        err = None if txt.startswith(e[0] + " (") else f"dica {txt!r}, esperado {e[0]}"
                    else:
                        err = confere_texto(re.sub(r"\s*\(\d{4}\)$", "", txt), mid, ind_pagina)
                    if err:
                        erros_al[rel].append(f"mapa, {html.unescape(m_r.group(1))}: {err}")
for rel, lst in sorted(erros_al.items()):
    problema(f"{rel}: {len(lst)} célula(s) fora do lugar ou com valor errado; ex.: {'; '.join(lst[:3])}")
print(f"  {n_tab3} tabelas ({n_lin} linhas, {n_cel} células) e {n_rot} dicas de mapa conferidas com valores.csv; "
      f"{sum(len(v) for v in erros_al.values())} divergências")

# ---------------------------------------------------------------------------
# 4. Links internos de _site/ (páginas, arquivos, âncoras, cliques dos mapas e figuras)
# ---------------------------------------------------------------------------
print("\n4. Links internos de _site/")
SITE = REPO / "_site"
RX_LINK = re.compile(r'''(?:href|src)\s*=\s*\\?["']([^"'\\<>]+)\\?["']''')
RX_ID = re.compile(r'''\bid\s*=\s*\\?["']([^"'\\]+)\\?["']''')
RX_CLIQUE = re.compile(r"window\.location\s*=\s*'([^']*)'\s*\+\s*l\.options\.layerId")
EXTERNO = ("http:", "https:", "mailto:", "tel:", "javascript:", "data:", "//", "#", "{", "$")
ids_cache: dict[Path, set] = {}


def ids_de(p: Path) -> set:
    if p not in ids_cache:
        ids_cache[p] = set(RX_ID.findall(p.read_text(encoding="utf-8", errors="replace")))
    return ids_cache[p]


quebrados = defaultdict(set)
usados_site: set[Path] = set()
n_links, n_ancoras, n_cliques = 0, 0, 0
for pg in paginas:
    rel = pg.relative_to(REPO).as_posix()
    txt = pg.read_text(encoding="utf-8", errors="replace")
    for alvo in set(RX_LINK.findall(txt)):
        alvo = html.unescape(alvo.strip())
        if not alvo or alvo.startswith(EXTERNO):
            continue
        caminho, _, frag = alvo.partition("#")
        caminho = caminho.split("?")[0]
        n_links += 1
        dest = (pg.parent / caminho).resolve() if caminho else pg
        if caminho.endswith("/") or (dest.exists() and dest.is_dir()):
            dest = dest / "index.html"
        try:
            dest.relative_to(SITE.resolve())
        except ValueError:
            quebrados[rel].add(f"{alvo} (fora de _site/)")
            continue
        usados_site.add(dest)
        if not dest.exists():
            quebrados[rel].add(alvo)
        elif frag and "=" not in frag and dest.suffix == ".html":
            # "#chave=valor" não é âncora: é o filtro que a página lê da URL (ex.: estudos.html#bloco=A)
            n_ancoras += 1
            if frag not in ids_de(dest):
                quebrados[rel].add(f"{alvo} (âncora inexistente)")
    # cliques dos mapas leaflet: prefixo + layerId + ".html"
    for bloco in RX_WIDGET.findall(txt):
        pref = RX_CLIQUE.search(bloco)
        if not pref:
            continue
        try:
            w = json.loads(bloco)
        except json.JSONDecodeError:
            continue
        for c in w.get("x", {}).get("calls", []):
            if isinstance(c, dict) and c.get("method") == "addPolygons":
                args = c.get("args", [])
                lids = args[1] if len(args) > 1 else None
                if isinstance(lids, str):
                    lids = [lids]
                for lid in lids or []:
                    if not isinstance(lid, str):
                        continue
                    n_cliques += 1
                    if not (pg.parent / f"{pref.group(1)}{lid}.html").resolve().exists():
                        quebrados[rel].add(f"clique no mapa: {pref.group(1)}{lid}.html")
for rel, alvos in sorted(quebrados.items()):
    problema(f"{rel}: {len(alvos)} link(s) quebrado(s): {', '.join(sorted(alvos)[:5])}")
FIG_SITE = SITE / "resultados" / "figuras"
sem_uso = sorted(p.relative_to(SITE).as_posix() for p in FIG_SITE.rglob("*") if p.is_file() and p.resolve() not in usados_site) \
    if FIG_SITE.exists() else []
if sem_uso:
    problema(f"figuras publicadas sem uso em nenhuma página ({len(sem_uso)}): {', '.join(sem_uso[:6])}")
print(f"  {n_links} links, {n_ancoras} âncoras e {n_cliques} cliques de mapa conferidos; "
      f"{sum(len(v) for v in quebrados.values())} quebrados em {len(quebrados)} páginas; "
      f"{len(sem_uso)} figura(s) publicada(s) sem uso")

# ---------------------------------------------------------------------------
# 5. Elementos obrigatórios de cada página de _site/
# ---------------------------------------------------------------------------
print("\n5. Elementos obrigatórios das páginas")
RODAPE = ("Projeto RESA nº 115 · Apoio: Instituto Clima e Sociedade (iCS), Doação D-25-02928 · Execução: UNEMAT · "
          "Versão preliminar para a equipe do projeto · Atualizado em 19/10/2026")
SEM_FAIXA = set()   # páginas que não são principais (nenhuma hoje)
RX_ROBOTS = re.compile(r'<meta\s+name="robots"\s+content="([^"]*)"', re.I)
RX_RODAPE = re.compile(r'<footer class="footer">(.*?)</footer>', re.S)
RX_VISIVEL_RUIM = re.compile(r"(?<![\w.-])(NA|NaN|NULL|Inf|-Inf|undefined)(?![\w.-])")
falhas = defaultdict(list)
for pg in paginas:
    rel = pg.relative_to(REPO).as_posix()
    txt = pg.read_text(encoding="utf-8", errors="replace")
    r_ = RX_ROBOTS.search(txt)
    if not r_ or "noindex" not in r_.group(1) or "nofollow" not in r_.group(1):
        falhas["sem meta robots noindex,nofollow"].append(rel)
    if not re.search(r"<title>[^<]+</title>", txt):
        falhas["sem título"].append(rel)
    rod = RX_RODAPE.search(txt)
    if not rod:
        falhas["sem rodapé"].append(rel)
    else:
        t_rod = re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", rod.group(1)))).strip()
        if RODAPE not in t_rod:
            falhas["rodapé diferente do texto oficial"].append(rel)
        imgs = re.findall(r'<img[^>]+src="([^"]+)"', rod.group(1))
        if [i for i in imgs if not re.search(r"logo-unemat\.png$", i)] or not imgs:
            falhas["rodapé sem o logo da UNEMAT ou com outro logo"].append(rel)
    rel_site = pg.relative_to(SITE).as_posix()
    if rel_site not in SEM_FAIXA and 'class="faixa-versao' not in txt:
        falhas["sem a faixa de versão"].append(rel)
    corpo = re.search(r"<main[^>]*>(.*?)</main>", txt, re.S)
    if corpo:
        vis = re.sub(r"<(script|style)\b.*?</\1>", " ", corpo.group(1), flags=re.S)
        vis = html.unescape(re.sub(r"<[^>]+>", " ", vis))
        ruins = RX_VISIVEL_RUIM.findall(vis)
        if ruins:
            falhas["texto visível com NA/NaN/NULL/Inf"].append(f"{rel} ({', '.join(sorted(set(ruins)))})")
for k, lst in sorted(falhas.items()):
    problema(f"{k}: {len(lst)} página(s), ex.: {', '.join(lst[:4])}")
if paginas:
    rb = SITE / "robots.txt"
    if not rb.exists() or not re.search(r"^Disallow:\s*/\s*$", rb.read_text(encoding="utf-8"), re.M):
        problema("_site/robots.txt ausente ou sem 'Disallow: /'")
    if (SITE / "sitemap.xml").exists():
        problema("_site/sitemap.xml existe (o site não deve oferecer mapa de páginas aos buscadores)")
print(f"  {len(paginas)} páginas: meta robots, título, rodapé oficial com só o logo da UNEMAT, faixa de versão, "
      f"texto sem NA/NaN; robots.txt e sitemap; {'ok' if not falhas else 'ERRO em ' + str(sum(len(v) for v in falhas.values())) + ' casos'}")

# ---------------------------------------------------------------------------
print()
for a in AVISOS:
    print(f"  aviso  {a}")
if PROBLEMAS:
    print(f"\n{len(PROBLEMAS)} problema(s). Não publique antes de corrigir:")
    for p_ in PROBLEMAS[:60]:
        print(f"  - {p_}")
    if len(PROBLEMAS) > 60:
        print(f"  ... e mais {len(PROBLEMAS) - 60}")
    sys.exit(1)
print("Pronto para publicar: nenhum problema encontrado.")
