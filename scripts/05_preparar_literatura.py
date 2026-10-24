# -*- coding: utf-8 -*-
"""
05_preparar_literatura.py - Observatório RESA-MT

Lê as duas buscas de literatura do Projeto RESA e grava, no repositório, só
metadados (autores, ano, título, periódico, tipo, DOI, bloco) e contagens:

  dados_site/literatura/   lidos pelas páginas literatura/*.qmd
    panorama.csv            contagens das bases (id, grupo, rotulo, valor, data, fonte)
    blocos_carbono.csv      os seis blocos A–F: tema e pergunta (sem as frases-título de síntese)
    refs_carbono.csv        as 115 referências com DOI verificado
    estudos_saf_psa.csv     os 38 estudos comparados do OE4
    estudos_todos.csv       as 115 + 38 numa tabela só, com a coluna corpus
  arquivos/literatura/     downloads (CSV com dicionário e BibTeX, sem resumos)

Fontes (dentro da raiz do projeto RESA):
  5_Literatura/_Revisao_Carbono_ESG/_deck_build/achados.json            (blocos)
  5_Literatura/_Revisao_Carbono_ESG/_deck_build/data/referencias_verificadas.json
  5_Literatura/_Revisao_Carbono_ESG/_deck_build/data/scopus_resultados.json
  5_Literatura/_Revisao_Carbono_ESG/_deck_build/data/triagem.json      (só a contagem colhida no OpenAlex)
  5_Literatura/_Busca_Similares_Dominicis/trabalhos_similares.csv     (sep=';')
  5_Literatura/_Busca_Similares_Dominicis/dados/dois_verificados.json
  5_Literatura/_Busca_Similares_Dominicis/dados/openalex_candidatos.json (só contagem)
  5_Literatura/_Busca_Similares_Dominicis/dados/scopus_busca_2026-10-16.json (só a contagem de registros únicos)

Regras: nada de resumo, nota interna, contagem de citações ou texto de
síntese; o método aparece só pelas contagens das bases e pelas listas finais
(sem as etapas de seleção); da tabela dos 38, só Estudo, Local, bioma, Público,
Arranjo e DOI, sem números (o script para se achar algarismo em Público ou Arranjo).

A raiz do projeto vem da variável de ambiente RESA_FONTES ou do arquivo
config.local.toml (fora do controle de versão), com a linha:
  resa_fontes = "<raiz do projeto RESA>"

Rodar a partir da raiz do repositório (Git Bash):
  RESA_FONTES="<raiz do projeto RESA>" python -I scripts/05_preparar_literatura.py

O script para com erro se alguma checagem falhar.
"""

import csv
import json
import os
import re
import sys
import unicodedata
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.stdout.reconfigure(encoding="utf-8", errors="replace")   # python -I ignora PYTHONIOENCODING


# ---------------------------------------------------------------------------
# 0. Caminhos
# ---------------------------------------------------------------------------
def raiz_fontes() -> Path:
    v = os.environ.get("RESA_FONTES", "").strip()
    if not v:
        cfg = REPO / "config.local.toml"
        if cfg.exists():
            import tomllib
            v = str(tomllib.loads(cfg.read_text(encoding="utf-8")).get("resa_fontes", "")).strip()
    if not v:
        sys.exit("ERRO: defina RESA_FONTES (raiz do projeto RESA) ou crie config.local.toml "
                 "com a linha resa_fontes = \"...\".")
    p = Path(v)
    if not (p / "5_Literatura").is_dir():
        sys.exit("ERRO: RESA_FONTES não aponta para a raiz do projeto (falta 5_Literatura).")
    return p


FONTES = raiz_fontes()
CARB = FONTES / "5_Literatura" / "_Revisao_Carbono_ESG" / "_deck_build"
OE4 = FONTES / "5_Literatura" / "_Busca_Similares_Dominicis"

DS = REPO / "dados_site" / "literatura"
ARQ = REPO / "arquivos" / "literatura"
for d in (DS, ARQ / "dicionarios"):
    d.mkdir(parents=True, exist_ok=True)

ERROS: list[str] = []


def checar(cond: bool, msg: str) -> None:
    print(("  ok    " if cond else "  ERRO  ") + msg)
    if not cond:
        ERROS.append(msg)


def ler_json(p: Path):
    return json.loads(p.read_text(encoding="utf-8"))


def gravar(linhas: list[dict], colunas: list[str], p: Path) -> None:
    with open(p, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=colunas, extrasaction="raise")
        w.writeheader()
        for r in linhas:
            w.writerow({c: ("" if r.get(c) is None else r.get(c)) for c in colunas})
    print(f"  gravado {p.relative_to(REPO).as_posix()} ({len(linhas)} linhas)")


def sem_acento(s: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))


def limpa(s) -> str:
    return re.sub(r"\s+", " ", str(s or "")).strip()


# ---------------------------------------------------------------------------
# 1. Revisão carbono, mercados e ESG: blocos e 115 referências
# ---------------------------------------------------------------------------
print("1. Carbono, mercados e ESG")
ach = ler_json(CARB / "achados.json")
nomes_bloco = {k: limpa(v) for k, v in ach["metodo"]["blocos"]}   # A..F -> nome do bloco
refs_raw = ler_json(CARB / "data" / "referencias_verificadas.json")

TIPO_PT = {"journal-article": "artigo", "book": "livro", "monograph": "livro", "report": "relatório",
           "posted-content": "texto para discussão", "proceedings-article": "anais", "book-chapter": "capítulo"}

refs = []
for e in refs_raw:
    ano = e.get("year") or e.get("year_crossref")
    refs.append({
        "bloco": e["block"],
        "nome_bloco": nomes_bloco[e["block"]],
        "autores": limpa(e.get("authors")),
        "ano": int(ano) if ano else "",
        "titulo": limpa(e.get("title")),
        "periodico": limpa(e.get("venue")),
        "tipo": TIPO_PT.get(e.get("type") or "", ""),
        "doi": limpa(e.get("doi")).lower(),
    })
refs.sort(key=lambda r: (r["bloco"], r["autores"].lower(), r["ano"]))

checar(len(refs) == 115, f"115 referências (lidas: {len(refs)})")
checar(all(e.get("doi_ok") is True for e in refs_raw), "todas com DOI verificado (doi_ok)")
checar(len({r["doi"] for r in refs}) == 115, "115 DOIs distintos")
checar(all(r["titulo"] and r["autores"] for r in refs), "todas com título e autoria")
checar(sum(1 for r in refs if r["ano"] == "") == 0, "todas com ano (ano do registro ou do Crossref)")

blocos = []
for b in ach["blocos"]:
    blocos.append({"bloco": b["key"], "nome": nomes_bloco[b["key"]], "tema": limpa(b["kicker"]),
                   "pergunta": limpa(b["pergunta"]),
                   "n_refs": sum(1 for r in refs if r["bloco"] == b["key"])})
checar([b["bloco"] for b in blocos] == list("ABCDEF"), "seis blocos A–F")

# ---------------------------------------------------------------------------
# 2. Busca do OE4: os 38 estudos comparados (trabalhos_similares.csv, sep=';')
# ---------------------------------------------------------------------------
print("2. SAF e PSA em assentamentos (OE4)")
with open(OE4 / "trabalhos_similares.csv", encoding="utf-8-sig", newline="") as f:
    sim = list(csv.DictReader(f, delimiter=";"))
checar(len(sim) == 38, f"38 estudos comparados (lidos: {len(sim)})")

BIOMAS_RE = r"(Amazônia|Cerrado|Pantanal|Mata Atlântica|Caatinga|Pampa)"
PAISES = ("Nicarágua", "Costa Rica", "Panamá", "Índia")
NI = "não informado"


def separa_local(s: str) -> tuple[str, str]:
    """'Bacia do Descoberto, DF (Cerrado)' -> ('Bacia do Descoberto, DF', 'Cerrado')."""
    s = limpa(s)
    if s in ("", "n.i."):
        return NI, NI
    m = re.search(r"\(([^()]*)\)", s)
    if m and re.search(BIOMAS_RE, m.group(1)):
        bioma = m.group(1).split(";")[0].strip()
        local = limpa(s[:m.start()] + s[m.end():]).replace(" ,", ",").strip(" ,;")
        return local, bioma
    if re.search(BIOMAS_RE, s):                       # o bioma está fora do parêntese
        if m:
            return limpa(m.group(1)), limpa(s[:m.start()])
        return s, s
    if any(p in s for p in PAISES):
        return s, "fora do Brasil"
    return s, NI


# Ajustes editoriais: tiram notas de resultado ou de avaliação e todos os números (tamanho de amostra,
# hectares, anos, contagens) das células factuais, como pede a regra "sem números" da tabela dos 38.
AJUSTES = {
    ("Gobbi e Casasola 2003", "Arranjo"): "Silvipastoril",
    ("Cunha et al. 2025", "Arranjo"): "Baru com gado de corte (sem lavoura)",
    ("Silva e Cunha 2013", "Público"): "Agricultura familiar (dados secundários)",
    ("Hespanhol et al. 2026", "Local (bioma)"): "n.i.",   # a célula da fonte descreve os arranjos, não o local
    ("Dominicis et al. 2023", "Público"): "Produtores, maioria assentados do MST",
    ("Dominicis et al. 2023", "Arranjo"): "SAF",
    ("Rodrigues et al. 2007", "Público"): "Famílias assentadas",
    ("Rodrigues et al. 2007", "Arranjo"): "Taungya em reserva legal",
    ("Rodrigues et al. 2008", "Público"): "Famílias assentadas",
    ("Rodrigues et al. 2008", "Arranjo"): "Taungya em reserva legal",
    ("Silva et al. 2018", "Público"): "Famílias interessadas",
    ("Silva et al. 2018", "Arranjo"): "SAFs escolhidos pelas famílias (AmazonSAF)",
    ("Solidaridad 2021", "Público"): "Produtores do assentamento; GEE de um lote típico",
    ("Sousa et al. 2019", "Público"): "Família assentada (estudo de caso)",
    ("Sousa et al. 2019", "Arranjo"): "SAF com várias espécies",
    ("Francez e Rosa 2011", "Público"): "SAFs de agricultores familiares",
    ("Tremblay et al. 2014", "Arranjo"): "SAFs frutíferos contra corte e queima",
    ("Queiroz et al. 2020", "Arranjo"): "SAFs pecuários",
    ("Projeto RECA (Embrapa, painel de 2016)", "Arranjo"): "Cupuaçu, pupunha e castanha",
    ("Palma et al. 2020", "Público"): "Família assentada (estudo de caso)",
    ("Garcia et al. 2021", "Arranjo"): "SAFs biodiversos",
    ("Paulus et al. 2021", "Arranjo"): "SAFs biodiversos",
    ("Agostinho et al. 2022", "Arranjo"): "SAFs biodiversos para reserva legal",
    ("Pagiola et al. 2007; VPL em Pagiola et al. 2004", "Público"): "Domicílios pecuaristas, por ordem de chegada; subgrupos sorteados",
    ("Gobbi e Casasola 2003", "Público"): "Finca hipotética, calibrada com enquete em fincas da região",
    ("Silva e Cunha 2013", "Arranjo"): "Açaí plantado em várzea",
    ("Hespanhol et al. 2026", "Arranjo"): "SAFs de cacau",
    ("Bentes-Gama et al. 2005", "Arranjo"): "SAFs",
    ("Sinacore et al. 2023", "Arranjo"): "Métodos de restauração com madeira",
    ("Vivan et al. 2009 (PNUD BRA/00/G31)", "Público"): "Propriedades familiares em assentamentos",
    ("Vivan et al. 2009 (PNUD BRA/00/G31)", "Arranjo"): "SAFs",
    ("Cunha et al. 2025", "Público"): "Lote de assentamento (estudo de caso)",
    ("Reis et al. 2019; 2025 (Projeto URTE)", "Público"): "Fazendas comerciais",
    ("Garcia et al. 2017", "Público"): "Fazendas-piloto",
    ("Lucchesi et al. 2024", "Público"): "Paisagem em escala regional",
}

# DOI conferido à parte no Crossref (api.crossref.org/works/<doi>, 19/10/2026): o estudo não tinha DOI
# juntado por autor e ano porque o trabalho não estava na lista de DOIs verificados da busca.
DOI_CONFERIDO_SITE = {
    "Lucchesi et al. 2024": {"autor1": "Lucchesi", "ano": 2024, "doi": "10.1016/j.landusepol.2024.107122",
                             "titulo": "Araguaia biodiversity corridor cost benefit analysis: Large scale restoration "
                                       "and sustainable agribusiness in Amazon and Cerrado",
                             "periodico": "Land Use Policy", "tipo": "journal-article"},
}

# DOIs conferidos no Crossref (dois_verificados.json), juntados por autor1 + ano
dv = [d for d in ler_json(OE4 / "dados" / "dois_verificados.json") if d.get("status") == "ok" and d.get("autor1")]
PART = {"de", "da", "do", "dos", "das", "e"}


def chaves_autor(nome: str) -> set[str]:
    t = [w for w in sem_acento(nome).lower().replace(",", " ").split() if w not in PART]
    return {" ".join(t), t[-1]} if t else set()


def autor_estudo(estudo: str) -> str:
    m = re.match(r"^(.+?)(?:\s+et al\.|\s+e\s+[A-ZÁ-Ú]|\s+\d{4})", estudo)
    return m.group(1) if m else estudo


AMBIGUOS: list[str] = []


def junta_doi(estudo: str) -> list[dict]:
    """DOI por primeiro autor + ano; só quando há exatamente um candidato."""
    a = sem_acento(autor_estudo(estudo)).lower()
    anos = [int(x) for x in re.findall(r"\b(19\d{2}|20\d{2})\b", estudo)]
    achados = []
    for ano in dict.fromkeys(anos):
        c = [d for d in dv if d["ano"] == ano and (a in chaves_autor(d["autor1"]) or a.split()[-1] in chaves_autor(d["autor1"]))]
        if len(c) == 1:
            achados.append(c[0])
        elif len(c) > 1 and f"{estudo} ({ano})" not in AMBIGUOS:
            AMBIGUOS.append(f"{estudo} ({ano})")
    return achados


estudos = []
for r in sim:
    est = limpa(r["Estudo"])
    cel = {k: AJUSTES.get((est, k), r[k]) for k in ("Local (bioma)", "Público", "Arranjo")}
    local, bioma = separa_local(cel["Local (bioma)"])
    pub = limpa(cel["Público"]); pub = NI if pub in ("", "n.i.") else pub
    arr = limpa(cel["Arranjo"]); arr = NI if arr in ("", "n.i.") else arr
    ds_ = junta_doi(est)
    if est in DOI_CONFERIDO_SITE:
        checar(not ds_, f"{est}: sem DOI juntado antes do DOI conferido à parte")
        ds_ = [DOI_CONFERIDO_SITE[est]]
    anos = re.findall(r"\b(19\d{2}|20\d{2})\b", est)
    estudos.append({
        "grupo": limpa(r["Bloco"]), "estudo": est, "local": local, "bioma": bioma,
        "publico": pub, "arranjo": arr, "dois": ds_,
        "doi": "; ".join(d["doi"].lower() for d in ds_),
        "ano": int(anos[0]) if anos else "",
        "titulo": limpa(ds_[0]["titulo"]) if ds_ else "",
        "periodico": limpa(ds_[0]["periodico"]) if ds_ else "",
        "tipo": TIPO_PT.get(ds_[0].get("tipo") or "", "") if ds_ else "",
    })

n_doi = sum(1 for e in estudos if e["doi"])
print(f"  {n_doi} dos 38 com DOI juntado; sem DOI por ambiguidade: {AMBIGUOS or 'nenhum'}")
checar(estudos[0]["estudo"].startswith("Dominicis") and estudos[0]["doi"] == "10.3390/f14102110",
       "Dominicis et al. 2023 com DOI 10.3390/f14102110")
checar(all(e["bioma"] for e in estudos), "todo estudo com bioma (ou 'não informado' / 'fora do Brasil')")
checar(not any(re.search(r"\(" + BIOMAS_RE, e["local"]) for e in estudos), "nenhum bioma entre parênteses no local")
com_num = [f"{e['estudo']}: {e['publico']} | {e['arranjo']}" for e in estudos if re.search(r"\d", e["publico"] + e["arranjo"])]
checar(not com_num, "nenhum número em Público ou Arranjo" + (f": {com_num}" if com_num else ""))
checar(all(k[0] in {e["estudo"] for e in estudos} for k in AJUSTES), "todo ajuste editorial corresponde a um estudo")

# ---------------------------------------------------------------------------
# 3. Tabela única (115 + 38) e downloads
# ---------------------------------------------------------------------------
print("3. Tabela única e downloads")
C1 = "Carbono, mercados e ESG"
C2 = "SAF e PSA em assentamentos (OE4)"
todos = [{"corpus": C1, "grupo": f"{r['bloco']} · {r['nome_bloco']}", "autores": r["autores"], "ano": r["ano"],
          "titulo": r["titulo"], "periodico": r["periodico"], "tipo": r["tipo"], "doi": r["doi"]} for r in refs]
todos += [{"corpus": C2, "grupo": e["grupo"], "autores": e["estudo"], "ano": e["ano"], "titulo": e["titulo"],
           "periodico": e["periodico"], "tipo": e["tipo"], "doi": e["doi"]} for e in estudos]
checar(len(todos) == 153, f"153 linhas na tabela única (115 + 38): {len(todos)}")

COL_REFS = ["bloco", "nome_bloco", "autores", "ano", "titulo", "periodico", "tipo", "doi"]
COL_EST = ["estudo", "local", "bioma", "publico", "arranjo", "doi"]
COL_EST_SITE = COL_EST
COL_TODOS = ["corpus", "grupo", "autores", "ano", "titulo", "periodico", "tipo", "doi"]

gravar(blocos, ["bloco", "nome", "tema", "pergunta", "n_refs"], DS / "blocos_carbono.csv")
gravar(refs, COL_REFS, DS / "refs_carbono.csv")
gravar(estudos, COL_EST_SITE, DS / "estudos_saf_psa.csv")
gravar(todos, COL_TODOS, DS / "estudos_todos.csv")

gravar(refs, COL_REFS, ARQ / "resa_refs_carbono_esg.csv")
gravar(estudos, COL_EST, ARQ / "resa_estudos_saf_psa_oe4.csv")
gravar(todos, COL_TODOS, ARQ / "resa_literatura_estudos.csv")

FT1 = "Projeto RESA, revisão de literatura sobre carbono, mercados e ESG (set/2026); metadados conferidos no Crossref"
FT2 = "Projeto RESA, busca de estudos semelhantes ao de Dominicis et al. (2023) (out/2026); DOI conferido no Crossref"
DIC = {
    "resa_refs_carbono_esg.csv": [
        ("bloco", "Bloco temático da revisão (A a F)", "", FT1),
        ("nome_bloco", "Nome do bloco temático", "", FT1),
        ("autores", "Autoria, conforme registrada no Crossref ou na verificação", "", FT1),
        ("ano", "Ano de publicação (o do registro da revisão ou, na ausência deste, o do Crossref)", "ano", FT1),
        ("titulo", "Título", "", FT1),
        ("periodico", "Periódico, editora ou série", "", FT1),
        ("tipo", "Tipo de publicação (artigo, livro, relatório ou texto para discussão); vazio quando o registro não o informa", "", FT1),
        ("doi", "DOI (acessível em https://doi.org/<DOI>)", "", FT1)],
    "resa_estudos_saf_psa_oe4.csv": [
        ("estudo", "Estudo (autoria e ano)", "", FT2),
        ("local", "Local do estudo", "", FT2),
        ("bioma", "Bioma, extraído do parêntese do campo local; 'fora do Brasil' ou 'não informado', quando for o caso", "", FT2),
        ("publico", "Público estudado (sem números)", "", FT2),
        ("arranjo", "Arranjo produtivo avaliado (sem números)", "", FT2),
        ("doi", "DOI associado pelo primeiro autor e pelo ano, apenas quando a correspondência é inequívoca, ou conferido "
                "separadamente no Crossref; vazio quando inexistente; havendo mais de um, separados por ';'", "", FT2)],
    "resa_literatura_estudos.csv": [
        ("corpus", f"Corpus de origem: '{C1}' (115) ou '{C2}' (38)", "", "Projeto RESA"),
        ("grupo", "Bloco (carbono) ou grupo da tabela comparativa (OE4)", "", "Projeto RESA"),
        ("autores", "Autoria (no corpus do OE4, a identificação do estudo)", "", "Projeto RESA"),
        ("ano", "Ano de publicação", "ano", "Projeto RESA"),
        ("titulo", "Título (no corpus do OE4, apenas quando o DOI foi associado)", "", "Crossref"),
        ("periodico", "Periódico, editora ou série", "", "Crossref"),
        ("tipo", "Tipo de publicação", "", "Crossref"),
        ("doi", "DOI; mais de um separado por ';'", "", "Crossref")],
}
for nome, linhas in DIC.items():
    gravar([dict(zip(["coluna", "descricao", "unidade", "fonte"], l)) for l in linhas],
           ["coluna", "descricao", "unidade", "fonte"], ARQ / "dicionarios" / nome)


# BibTeX, sem resumos: as 115 e os estudos do OE4 com DOI
def bib_esc(s: str) -> str:
    s = str(s)
    for a, b in (("\\", ""), ("&", r"\&"), ("%", r"\%"), ("$", r"\$"), ("#", r"\#"), ("_", r"\_")):
        s = s.replace(a, b)
    return s.replace("{", "").replace("}", "")


usadas: set[str] = set()


def chave_bib(autor: str, ano, titulo: str) -> str:
    a = re.sub(r"[^a-z]", "", sem_acento(re.split(r"[,;]", autor)[0].split()[-1] if autor else "anon").lower()) or "anon"
    w = next((re.sub(r"[^a-z]", "", sem_acento(x).lower()) for x in titulo.split() if len(x) > 3), "") or "ref"
    k = base = f"{a}{ano}{w}"
    i = 0
    while k in usadas:
        i += 1
        k = base + "abcdefghij"[i - 1]
    usadas.add(k)
    return k


TIPO_BIB = {"artigo": "article", "livro": "book", "relatório": "techreport", "texto para discussão": "misc", "anais": "inproceedings"}
CAMPO_VEN = {"article": "journal", "book": "publisher", "techreport": "institution", "misc": "howpublished", "inproceedings": "booktitle"}
bib = ["% Observatório RESA-MT - literatura do Projeto RESA (só metadados, sem resumos)",
       f"% {C1}: 115 referências; {C2}: estudos com DOI conferido", ""]
n_bib = 0
for r in refs:
    t = TIPO_BIB.get(r["tipo"], "article" if r["periodico"] else "misc")
    aut = " and ".join(limpa(x) for x in r["autores"].split(";") if limpa(x))
    campos = [("author", aut), ("title", "{" + bib_esc(r["titulo"]) + "}"), ("year", r["ano"]),
              (CAMPO_VEN[t], r["periodico"]), ("doi", r["doi"]), ("keywords", f"RESA carbono bloco {r['bloco']}")]
    bib.append(f"@{t}{{{chave_bib(r['autores'], r['ano'], r['titulo'])},")
    bib += [f"  {k} = {{{v if k == 'title' else bib_esc(v)}}}," for k, v in campos if v not in ("", None)]
    bib.append("}\n"); n_bib += 1
for e in estudos:
    if not e["doi"]:
        continue
    for d in e["dois"]:
        tt = TIPO_PT.get(d.get("tipo") or "", "")
        t = TIPO_BIB.get(tt, "article")
        campos = [("author", f"{d['autor1']} and others"), ("title", "{" + bib_esc(limpa(d["titulo"])) + "}"),
                  ("year", d["ano"]), (CAMPO_VEN[t], limpa(d["periodico"])), ("doi", d["doi"].lower()),
                  ("keywords", "RESA OE4 SAF PSA")]
        bib.append(f"@{t}{{{chave_bib(d['autor1'], d['ano'], d['titulo'])},")
        bib += [f"  {k} = {{{v if k == 'title' else bib_esc(v)}}}," for k, v in campos if v not in ("", None)]
        bib.append("}\n"); n_bib += 1
(ARQ / "resa_literatura_estudos.bib").write_text("\n".join(bib), encoding="utf-8")
print(f"  gravado arquivos/literatura/resa_literatura_estudos.bib ({n_bib} entradas)")

# ---------------------------------------------------------------------------
# 4. Panorama: só contagens das bases, conferidas nos arquivos brutos
# ---------------------------------------------------------------------------
print("4. Panorama (contagens)")
sc = ler_json(CARB / "data" / "scopus_resultados.json")
STR = [("BC_mercados_precos", "Mercados regulados e preços de carbono"), ("D_voluntario", "Mercado voluntário e créditos florestais"),
       ("E_emissoes_brasil", "Emissões no Brasil"), ("F_esg", "ESG, risco climático e finanças")]
tot_sc = sum(sc[k]["total"] for k, _ in STR)
checar(tot_sc == 3777, f"Scopus: 3.777 registros nas 4 strings principais ({tot_sc})")
checar(sc["meta"]["data_consulta"] == "2026-09-06", "Scopus consultado em 06/09/2026")

# Só contagens das bases (registros colhidos em cada consulta) e as listas finais; as etapas de seleção ficam fora
tri = ler_json(CARB / "data" / "triagem.json")
colh = sum(v["n_avaliados"] for v in tri.values())
checar(colh == 1201, f"OpenAlex: 1.201 registros colhidos ({colh})")

oa = ler_json(OE4 / "dados" / "openalex_candidatos.json")
checar(len(oa) == 501, f"OE4, OpenAlex: 501 registros ({len(oa)})")
so = ler_json(OE4 / "dados" / "scopus_busca_2026-10-16.json")
checar(so["registros_unicos"] == 447, f"OE4, Scopus: 447 registros únicos ({so['registros_unicos']})")

F_SC = "Scopus, pelo Portal de Periódicos da CAPES; artigos publicados de 2005 a 2026"
F_CR = "Crossref (conferência de DOI, título, autoria, ano e periódico)"
F_OA = "OpenAlex (API aberta)"
pan = [
    {"id": "scopus_total", "grupo": "carbono", "rotulo": "registros no Scopus nas 4 consultas principais", "valor": tot_sc, "data": "06/09/2026", "fonte": F_SC},
] + [
    {"id": "scopus_" + k.split("_")[0].lower(), "grupo": "carbono_string", "rotulo": n, "valor": sc[k]["total"], "data": "06/09/2026", "fonte": F_SC}
    for k, n in STR
] + [
    {"id": "refs_doi", "grupo": "carbono", "rotulo": "referências com DOI verificado", "valor": len(refs), "data": "set/2026", "fonte": F_CR},
    {"id": "oa_colhidos", "grupo": "carbono_openalex", "rotulo": "registros colhidos no OpenAlex", "valor": colh, "data": "07/09/2026", "fonte": F_OA},
    {"id": "oe4_openalex", "grupo": "oe4", "rotulo": "registros no OpenAlex", "valor": len(oa), "data": "15/10/2026", "fonte": F_OA},
    {"id": "oe4_scopus", "grupo": "oe4", "rotulo": "registros únicos no Scopus", "valor": so["registros_unicos"], "data": "16/10/2026", "fonte": "Scopus, pelo Portal de Periódicos da CAPES"},
    {"id": "oe4_comparados", "grupo": "oe4", "rotulo": "estudos comparados (lista final)", "valor": len(estudos), "data": "16/10/2026", "fonte": F_CR},
    {"id": "oe4_com_doi", "grupo": "oe4", "rotulo": "estudos comparados com DOI conferido", "valor": n_doi, "data": "19/10/2026", "fonte": F_CR},
] + [
    {"id": "refs_bloco_" + b["bloco"], "grupo": "carbono_bloco", "rotulo": f"{b['bloco']} · {b['nome']}", "valor": b["n_refs"], "data": "set/2026", "fonte": F_CR}
    for b in blocos
]
gravar(pan, ["id", "grupo", "rotulo", "valor", "data", "fonte"], DS / "panorama.csv")

# ---------------------------------------------------------------------------
# 5. Varredura final
# ---------------------------------------------------------------------------
print("5. Varredura dos arquivos gravados")
# padrões montados por partes, para que este arquivo não contenha os próprios termos; os demais termos
# vetados são conferidos pelo script 07, em todo o repositório
RUINS = ["C:" + "/Users", "C:" + "\\Users", "Meu " + "Drive", "@" + "unemat", "drive." + "google",
         "LS" + "EG", "Refi" + "nitiv", "Alli" + "ed Off" + "sets"]
achados = []
for p in list(DS.rglob("*.csv")) + list(ARQ.rglob("*.csv")) + list(ARQ.rglob("*.bib")):
    txt = p.read_text(encoding="utf-8")
    for r in RUINS:
        if r.lower() in txt.lower():
            achados.append(f"{p.relative_to(REPO).as_posix()}: {r}")
    cab = txt.splitlines()[0].lower() if p.suffix == ".csv" else ""
    if any(x in cab for x in ("abstract", "resumo", "note", "cites", "citac")):
        achados.append(f"{p.relative_to(REPO).as_posix()}: coluna de resumo, nota ou citações")
    if p.suffix == ".bib" and re.search(r"^\s*(abstract|note)\s*=", txt, re.M):
        achados.append(f"{p.relative_to(REPO).as_posix()}: campo de resumo ou nota no BibTeX")
checar(not achados, "sem caminho local, e-mail, Drive, base comercial, resumo ou menção indevida"
       + (f": {achados}" if achados else ""))

print()
if ERROS:
    print(f"FALHOU: {len(ERROS)} checagem(ns).")
    for e_ in ERROS:
        print("  -", e_)
    sys.exit(1)
print("Concluído sem erros.")
