# -*- coding: utf-8 -*-
"""
06_preparar_oe1.py - Observatório RESA-MT

Desmatamento por município de MT, pelo PRODES oficial do INPE (painel
TerraBrasilis, cópia baixada em 19/10/2026), para a página do OE1.

Lê, na raiz do projeto RESA (2_Dados/Brutos/PRODES_TerraBrasilis/2026-10-19/):
  data_prodes_{amazon,cerrado,pantanal}.json      incremento por período e recorte
  loinames_prodes_{amazon,cerrado,pantanal}.json  nomes e códigos IBGE dos recortes
  metadados.json, last_update_date.json           URL, data de acesso, versão, sha256

Grava, no repositório (objetivos/dados/):
  prodes_mt_municipios.csv         formato longo: um município x bioma do PRODES x período
  prodes_mt_municipios_resumo.csv  janelas 2017–2025 e 2025, por bioma e no total
  prodes_mt_municipios_fonte.csv   arquivo de origem, URL, versão, datas e sha256

Regras:
  - Só períodos consolidados de 2001 a 2025. O acumulado inicial (até 2000 ou
    2007) e o período 2026, ainda parcial, ficam fora.
  - Um município só tem linha nos biomas cuja máscara do PRODES o inclui. Dentro
    da máscara, período sem registro = 0 km² (nenhum incremento mapeado), com
    sem_registro = 1.
  - Ano do PRODES = ano em que o período termina (ex.: 2025 = ago/2024 a jul/2025).

A raiz do projeto vem de RESA_FONTES ou de config.local.toml (linha
resa_fontes = "..."), como no script 01. Rodar na raiz do repositório:
  RESA_FONTES="<raiz do projeto RESA>" python -I scripts/06_preparar_oe1.py
O script para com erro se alguma checagem falhar.
"""

import csv
import hashlib
import json
import os
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SAIDA = REPO / "objetivos" / "dados"
BIOMAS = {"amazon": "Amazônia", "cerrado": "Cerrado", "pantanal": "Pantanal"}
JANELA = (2017, 2025)   # anos do PRODES; todos anuais e consolidados nos três biomas
ULTIMO = 2025
ERROS: list[str] = []


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
    if not (p / "2_Dados" / "Brutos").is_dir():
        sys.exit("ERRO: RESA_FONTES não aponta para a raiz do projeto (falta 2_Dados/Brutos).")
    return p


def checar(cond: bool, msg: str) -> None:
    print(("  ok  " if cond else "  ERRO ") + msg)
    if not cond:
        ERROS.append(msg)


def num(x: float) -> str:
    s = f"{x:.6f}".rstrip("0").rstrip(".")
    return "0" if s in ("", "-0") else s


def gravar(nome: str, campos: list[str], linhas: list[dict]) -> None:
    with open(SAIDA / nome, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=campos, lineterminator="\n")
        w.writeheader()
        w.writerows(linhas)
    print(f"  gravado objetivos/dados/{nome} ({len(linhas)} linhas)")


sys.stdout.reconfigure(encoding="utf-8")
BRUTO = raiz_fontes() / "2_Dados" / "Brutos" / "PRODES_TerraBrasilis" / "2026-10-19"
SAIDA.mkdir(parents=True, exist_ok=True)

meta = json.loads((BRUTO / "metadados.json").read_text(encoding="utf-8"))
atualizacao = json.loads((BRUTO / "last_update_date.json").read_text(encoding="utf-8"))["last_date"]
data_acesso = meta["data_acesso"][:10]
versao = meta["versao_painel"]

with open(REPO / "dados_site" / "municipios.csv", encoding="utf-8", newline="") as f:
    MUN = {int(r["id_municipio"]): r for r in csv.DictReader(f)}
with open(REPO / "dados_site" / "prodes_mt_bioma.csv", encoding="utf-8", newline="") as f:
    ESTADO = {(r["bioma"], int(r["ano"])): float(r["desmat_km2"]) for r in csv.DictReader(f)}

print("1. Integridade dos arquivos brutos")
fonte = []
for chave, bioma in BIOMAS.items():
    for tipo in ("data", "loinames"):
        arq = f"{tipo}_prodes_{chave}.json"
        m = meta["arquivos"][arq]
        sha = hashlib.sha256((BRUTO / arq).read_bytes()).hexdigest()
        checar(sha == m["sha256"], f"{arq}: sha256 igual ao registrado no download")
        fonte.append({"bioma_prodes": bioma, "arquivo": arq, "url": m["url"], "last_modified": m["last_modified"],
                      "data_acesso": data_acesso, "atualizacao_inpe": atualizacao, "versao_painel": versao,
                      "sha256": sha})

print("2. Incremento por município")
longo = []
mascara = defaultdict(set)          # id_municipio -> biomas do PRODES
soma_mun = defaultdict(float)       # (bioma, ano) -> soma dos municípios de MT
for chave, bioma in BIOMAS.items():
    L = json.loads((BRUTO / f"loinames_prodes_{chave}.json").read_text(encoding="utf-8"))
    lois = {l["name"]: l for l in L["lois"]}
    gid_mun = {x["gid"]: int(x["codibge"]) for x in lois["mun"]["loinames"] if str(x["codibge"]).startswith("51")}
    gid_uf = [x["gid"] for x in lois["uf"]["loinames"] if x["loiname"] == "Mato Grosso"]
    checar(len(gid_uf) == 1, f"{bioma}: Mato Grosso aparece uma vez entre as UFs")
    gid_uf = gid_uf[0]
    for cod in gid_mun.values():
        mascara[cod].add(bioma)
    D = json.loads((BRUTO / f"data_prodes_{chave}.json").read_text(encoding="utf-8"))
    n_per = 0
    for p in D["periods"]:
        ini, fim = p["startDate"], p["endDate"]
        if ini["year"] < 2000 or fim["year"] > ULTIMO:
            continue                                   # acumulado inicial e período parcial
        n_per += 1
        tipos = {a["type"] for f in p["features"] for a in f["areas"]}
        checar(tipos == {1}, f"{bioma} {fim['year']}: só áreas do tipo 1 (incremento)")
        area = defaultdict(float)
        uf = 0.0
        for f in p["features"]:
            a = sum(x["area"] for x in f["areas"])
            if f["loi"] == 2 and f["loiname"] in gid_mun:
                area[gid_mun[f["loiname"]]] += a
            elif f["loi"] == 1 and f["loiname"] == gid_uf:
                uf += a
        checar(min(area.values(), default=0) >= 0, f"{bioma} {fim['year']}: nenhuma área negativa")
        n_anos = fim["year"] - ini["year"]
        for cod in sorted(gid_mun.values()):
            v = area.get(cod, 0.0)
            longo.append({"id_municipio": cod, "municipio": MUN.get(cod, {}).get("municipio", ""),
                          "bioma_prodes": bioma, "ano": fim["year"],
                          "periodo_inicio": f"{ini['year']}-{ini['month']:02d}-{ini['day']:02d}",
                          "periodo_fim": f"{fim['year']}-{fim['month']:02d}-{fim['day']:02d}",
                          "n_anos": n_anos, "tipo_periodo": "anual" if n_anos == 1 else "plurianual",
                          "desmat_km2": num(v), "sem_registro": 0 if cod in area else 1})
        s = sum(area.values())
        soma_mun[(bioma, fim["year"])] = s
        checar(abs(s - uf) < 0.01, f"{bioma} {fim['year']}: soma dos municípios = MT ({s:,.3f} km²)")
        e = ESTADO.get((bioma, fim["year"]))
        checar(e is not None and abs(e - s) < 0.001,
               f"{bioma} {fim['year']}: igual a dados_site/prodes_mt_bioma.csv")
    print(f"  {bioma}: {len(gid_mun)} municípios de MT na máscara; {n_per} períodos")

print("3. Cobertura dos 141 municípios")
checar(set(mascara) == set(MUN), "os 141 municípios do site e só eles estão nas máscaras do PRODES")
checar(all(MUN[c]["bioma"] in mascara[c] for c in MUN),
       "o bioma dominante (IBGE 1:250 mil) de cada município está entre as suas máscaras do PRODES")
checar(all(r["municipio"] for r in longo), "toda linha tem o nome do município")
anos_janela = range(JANELA[0], JANELA[1] + 1)
checar(all(r["tipo_periodo"] == "anual" for r in longo if r["ano"] in anos_janela),
       f"janela {JANELA[0]}–{JANELA[1]}: só períodos anuais nos três biomas")

print("4. Resumo (janelas)")
resumo = []
for cod in sorted(MUN):
    tot = {"2017–2025": 0.0, "2025": 0.0}
    for bioma in BIOMAS.values():
        if bioma not in mascara[cod]:
            continue
        rr = [r for r in longo if r["id_municipio"] == cod and r["bioma_prodes"] == bioma]
        j = sum(float(r["desmat_km2"]) for r in rr if r["ano"] in anos_janela)
        u = sum(float(r["desmat_km2"]) for r in rr if r["ano"] == ULTIMO)
        for jan, v in (("2017–2025", j), ("2025", u)):
            resumo.append({"id_municipio": cod, "municipio": MUN[cod]["municipio"], "bioma_prodes": bioma,
                           "janela": jan, "desmat_km2": num(v)})
            tot[jan] += v
    for jan, v in tot.items():
        resumo.append({"id_municipio": cod, "municipio": MUN[cod]["municipio"], "bioma_prodes": "Total",
                       "janela": jan, "desmat_km2": num(v)})
for jan, anos in (("2017–2025", anos_janela), ("2025", [ULTIMO])):
    for bioma in BIOMAS.values():
        s = sum(float(r["desmat_km2"]) for r in resumo if r["janela"] == jan and r["bioma_prodes"] == bioma)
        e = sum(ESTADO[(bioma, a)] for a in anos)
        checar(abs(s - e) < 0.01, f"resumo {jan}, {bioma}: {s:,.1f} km² = MT")

print("5. Varredura de conteúdo")
# padrões montados por partes, para que este arquivo não contenha os próprios termos
RUINS = ["C:" + "/Users", "C:" + "\\Users", "Meu " + "Drive", "@" + "unemat", "drive." + "google",
         "LS" + "EG", "Refi" + "nitiv", "Alli" + "ed Off" + "sets"]
texto = json.dumps([longo, resumo, fonte], ensure_ascii=False)
checar(not [r for r in RUINS if r in texto], "sem caminho local, e-mail, link do Drive ou base comercial")

if ERROS:
    sys.exit(f"ERRO: {len(ERROS)} checagem(ns) falharam; nada foi gravado.")
gravar("prodes_mt_municipios.csv", list(longo[0].keys()), longo)
gravar("prodes_mt_municipios_resumo.csv", list(resumo[0].keys()), resumo)
gravar("prodes_mt_municipios_fonte.csv", list(fonte[0].keys()), fonte)
print("Concluído.")
