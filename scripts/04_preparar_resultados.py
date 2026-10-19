# -*- coding: utf-8 -*-
"""
04_preparar_resultados.py - Observatório RESA-MT: dados das páginas de Resultados

Grava em dados_site/resultados/ o que as quatro páginas de resultados/ leem:
  tipologia.qmd  Manuscrito 1 (M1): números de NUMEROS_FINAIS.csv, municípios
                 mais próximos do centroide, tipo x bioma
  posse.qmd      M1: categoria 46504 x INCRA (números de NUMEROS_FINAIS.csv)
  emissoes.qmd   Artigo B recalculado pelos tipos do M1 (SEEG 13) e validação
                 da proxy de desmatamento contra o PRODES oficial
  dinamica.qmd   Artigo C recalculado pelos tipos do M1 (Censos 2006 e 2017)
e copia para resultados/figuras/ as figuras finais do M1 usadas nas páginas.

A raiz do projeto vem da variável de ambiente RESA_FONTES ou do arquivo
config.local.toml (fora do controle de versão), com a linha:
  resa_fontes = "<raiz do projeto RESA>"

Rodar a partir da raiz do repositório (Git Bash), depois do script 01:
  RESA_FONTES="<raiz do projeto RESA>" python -I scripts/04_preparar_resultados.py

Regras aplicadas aqui (ver README):
  - Números do M1 só de NUMEROS_FINAIS.csv (fonte única), copiados como texto
    pt-BR, sem recálculo; o script confere alguns contra os arquivos de origem.
  - Tipologia só a do M1 (k = 5). Bioma IBGE 1:250 mil (2019), de municipios.csv.
  - PRODES só a série oficial do TerraBrasilis; nunca a série antiga digitada.
  - X, – e ... nunca viram 0: o SEEG e as variáveis usadas aqui não têm sinal;
    o script confere isso e para se aparecer célula sem valor.
  - Sem colunas __compl, chk_ nem arquivos de espelhos de sigilo.
O script para com erro se alguma checagem falhar.
"""

import csv
import os
import re
import shutil
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import kruskal, pearsonr, spearmanr

REPO = Path(__file__).resolve().parents[1]
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


# ---------------------------------------------------------------------------
# 0. Caminhos e utilitários
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
    if not (p / "2_Dados" / "Processados").is_dir():
        sys.exit("ERRO: RESA_FONTES não aponta para a raiz do projeto (falta 2_Dados/Processados).")
    return p


FONTES = raiz_fontes()
M1 = FONTES / "4_Outputs" / "artigos" / "01_Manuscrito_1_LUP_Corrigido"
RES = M1 / "03_Resultados"
FIG = M1 / "04_Figuras" / "final_v5"
PROC = FONTES / "2_Dados" / "Processados"

DS = REPO / "dados_site"
OUT = DS / "resultados"
FIG_SITE = REPO / "resultados" / "figuras"
OUT.mkdir(parents=True, exist_ok=True)
FIG_SITE.mkdir(parents=True, exist_ok=True)

PROIBIDOS = ("sigilo_espelhos_", "dataset_AF_MT_sigilo_R1_final.csv", "sigilo_E2_R3_",
             "prodes_mt_serie_bioma_" + "ANTI" + "GO_manual.csv", "mapeamento_vars_cabral_sidra.json")  # o nome da série manual vai em partes
TIPOS = ["T1", "T2", "T3", "T4", "T5"]
BIOMAS = ["Amazônia", "Cerrado", "Pantanal"]
ERROS: list[str] = []


def checar(cond, msg: str) -> None:
    print(("  ok  " if cond else "  ERRO ") + msg)
    if not cond:
        ERROS.append(msg)


def proibido(p: Path) -> None:
    if any(p.name.startswith(x) or p.name == x for x in PROIBIDOS):
        sys.exit(f"ERRO: arquivo proibido: {p.name}")


def ler_csv(p: Path, **kw) -> pd.DataFrame:
    proibido(p)
    df = pd.read_csv(p, encoding="utf-8", **kw)
    ruins = [c for c in df.columns if "__compl" in str(c) or str(c).startswith("chk_")]
    if ruins:
        sys.exit(f"ERRO: colunas proibidas em {p.name}: {ruins}")
    return df


def fmt_num(x) -> str:
    """Número para CSV: vazio se NaN; inteiro sem casas; senão até 6 casas, ponto decimal."""
    if x is None or (isinstance(x, float) and np.isnan(x)):
        return ""
    if isinstance(x, (str, bool, np.bool_)):
        return str(x)
    x = float(x)
    if abs(x - round(x)) < 1e-9 and abs(x) < 1e15:
        return str(int(round(x)))
    return f"{x:.6f}".rstrip("0").rstrip(".")


def gravar(df: pd.DataFrame, nome: str) -> None:
    df = df.copy()
    for c in df.columns:
        if pd.api.types.is_float_dtype(df[c]):
            df[c] = df[c].map(fmt_num)
    df.to_csv(OUT / nome, index=False, encoding="utf-8", lineterminator="\n")
    print(f"  gravado dados_site/resultados/{nome} ({len(df)} linhas)")


def br(x: float, d: int) -> str:
    """Formato pt-BR (só para checagens e mensagens)."""
    s = f"{x:,.{d}f}"
    return s.replace(",", "§").replace(".", ",").replace("§", ".")


def epsilon2(h: float, n: int) -> float:
    """Tamanho de efeito do Kruskal-Wallis (mesma fórmula da robustez do Artigo B)."""
    return h / (n - 1)


def kw(df: pd.DataFrame, col: str, grupo: str, ordem: list[str]):
    gs = [df.loc[df[grupo] == g, col].dropna().to_numpy() for g in ordem]
    gs = [g for g in gs if len(g) > 0]
    h, p = kruskal(*gs)
    n = sum(len(g) for g in gs)
    return h, p, n, len(gs) - 1, epsilon2(h, n)


# ---------------------------------------------------------------------------
# 1. Base do site: municípios (bioma 1:250 mil, tipo do M1) e Censo 2017 da AF
# ---------------------------------------------------------------------------
print("1. Base do site")
MUN = ler_csv(DS / "municipios.csv")
checar(len(MUN) == 141, "municipios.csv: 141 municípios")
checar(MUN["bioma"].value_counts().to_dict() == {"Amazônia": 76, "Cerrado": 61, "Pantanal": 4},
       "bioma IBGE 1:250 mil: 76 / 61 / 4")
checar(MUN["tipo_m1"].value_counts().reindex(TIPOS).tolist() == [74, 25, 20, 10, 12],
       "tipos do M1: 74 / 25 / 20 / 10 / 12")
VAL = pd.read_csv(DS / "valores.csv", encoding="utf-8", keep_default_na=False)
af = {}
for ind in ("estab_af", "area_af"):
    s = VAL[(VAL["indicador"] == ind) & (VAL["ano"] == 2017)]
    checar(len(s) == 141 and (s["sinal"] == "valor").all(), f"{ind}: 141 municípios, todos com valor (sem X, – ou ...)")
    af[ind] = s.set_index("id_municipio")["valor"].astype(float)
MUN = MUN.set_index("id_municipio")
MUN["estab_af"] = af["estab_af"]
MUN["area_af"] = af["area_af"]
checar(int(MUN["estab_af"].sum()) == 81635, "estabelecimentos da AF: 81.635")


# ---------------------------------------------------------------------------
# 2. Manuscrito 1: números de NUMEROS_FINAIS.csv (fonte única)
# ---------------------------------------------------------------------------
print("2. Manuscrito 1 (NUMEROS_FINAIS.csv)")
NF = ler_csv(RES / "NUMEROS_FINAIS.csv", dtype=str, keep_default_na=False)
checar(NF["id"].is_unique, "NUMEROS_FINAIS: ids únicos")

GRUPOS_T3 = TIPOS + ["MT"]
T3_CAMPOS = ["N", "F1_MEDIA_WINSOR", "F1_MEDIANA", "F2_MEDIA_WINSOR", "F2_MEDIANA", "F3_MEDIA_WINSOR",
             "F3_MEDIANA", "F4_MEDIA_WINSOR", "F4_MEDIANA", "F5_MEDIA_WINSOR", "F5_MEDIANA",
             "PCT_ESTAB_46504_PONDERADA", "PCT_ESTAB_46504_MEDIA_MUNICIPAL_TODOS",
             "PCT_ESTAB_46504_MEDIANA_MUNICIPAL", "N_MUNIS_COM_ESTAB_46504",
             "PCT_AREA_46504_PONDERADA_SEM_SIGILO", "N_MUNIS_SIGILO_AREA_46504",
             "AREA_MEDIA_AF_HA_POR_ESTAB_PONDERADA", "AREA_MEDIA_AF_HA_POR_ESTAB_MEDIANA_MUNICIPAL",
             "ESTAB_AF_POR_MUNICIPIO_MEDIA", "ESTAB_AF_POR_MUNICIPIO_MEDIANA", "SOMA_ESTAB_AF",
             "SOMA_ESTAB_AF_46504", "SOMA_AREA_AF_HA", "BIOMA250_AMAZONIA", "BIOMA250_CERRADO",
             "BIOMA250_PANTANAL"]
INCRA_CAMPOS = ["REF", "PCT_REF_DO_MT", "REF_POR100AF_PONDERADO", "COBERTURA_46504AF_SOBRE_REF",
                "COBERTURA_46504AF_MAIS_PROPRA_SOBRE_REF", "PCT_ALT_S4_AF_PONDERADO",
                "PCT_TITULADO_BENEF_SIPRA", "ANO_CRIACAO_MEDIO_POND_FAMILIAS",
                "PCT_FAMILIAS_PROJETOS_ATE1995", "PCT_FAMILIAS_COLONIZACAO_ANTIGA",
                "PCT_FAMILIAS_PE_ESTADUAL"]

IDS = (
    [f"T3_{g}_{c}" for g in GRUPOS_T3 for c in T3_CAMPOS]
    + [f"T3_{t}_JACCARD_BOOTSTRAP_REPETICOES" for t in TIPOS]
    + [f"T3_{t}_JACCARD_BOOTSTRAP_CLUSTERBOOT_PADRAO" for t in TIPOS]
    + [f"INCRA_{g}_{c}" for g in GRUPOS_T3 for c in INCRA_CAMPOS]
    + [
        # área de estudo e totais
        "AE_N_MUNICIPIOS", "TOT_AF_ESTAB", "TOT_TODOS_ESTAB", "TOT_46504_ESTAB", "PCT_46504_ESTAB_MT",
        "TOT_46504_AREA", "PCT_46504_AREA_MT", "TOT_TODOS_46504_ESTAB", "TOT_46504_PESSOAL",
        "PCT_46504_PESSOAL_MT",
        # análise fatorial
        "AFE_N_CANDIDATAS", "AFE_N_VARIAVEIS", "AFE_KMO", "AFE_VARIANCIA_COMUM", "AFE_H2_MEDIA",
        "AFE_RETENCAO_HORN_R", "AFE_N_CARGAS05_TOTAL", "CARGA_POSSE_PCT_ESTAB", "CARGA_POSSE_PCT_PESSOAL",
        # tipologia
        "TIPO_WINSORIZADOS", "K_REGRA", "K5_SILHUETA", "K4_SILHUETA", "K6_SILHUETA", "K_EMPATE_DIF",
        "K_GAP_1EP", "K5_JACCARD_MEDIO_REP", "K5_JACCARD_MEDIO_PADRAO", "TIPO_ARI_WARD", "K5_TAMANHOS",
        "K4_COMPOSICAO", "TIPO_ARI_ESCORES_REGRESSAO", "RAZAO_T2_46504_VS_MT", "RAZAO_T4_46504_VS_MT",
        "PREV_SEM_ITANHANGA_T4", "RAZAO_T4_46504_VS_MT_SEM_ITANHANGA", "INVERSAO_T4", "OUT_T5_F4_SEM_COLNIZA",
        # tipo x bioma
        "BIOMA_K5_250MIL_CHI2", "BIOMA_K5_250MIL_V",
        # Phi e regra de decisão
        "PHI_POSSE_MEC", "PHI_POSSE_MEC_IC_IID", "PHI_POSSE_MEC_IC_BLOCOS", "PHI_POSSE_ESC",
        "PHI_POSSE_ESC_IC_IID", "PHI_POSSE_HORT", "PHI_POSSE_HORT_IC_IID", "PHI_POSSE_PER",
        "PHI_POSSE_PER_IC_IID", "REGRA_M", "REGRA_VEREDITO_CANONICO", "REGRA_M_IC_BOOT_IID",
        "REGRA_FAIXAS_CANONICAS_BOOT_IID", "REGRA_M_IC_BOOT_BLOCOS", "REGRA_FAIXAS_CANONICAS_BOOT_BLOCOS",
        "PHI_POSSE_MEC_PROMAX", "REGRA_M_PROMAX", "REGRA_VEREDITO_CANONICO_PROMAX",
        "REGRA_FAIXAS_CANONICAS_BOOT_IID_PROMAX", "REGRA_M_IC_BOOT_IID_PROMAX", "REGRA_M_OBLIMIN_KAISER", "H2_VEREDITO",
        "SENS_K6_PHI_POSSE_MEC",
        # sigilo
        "SIG_46504_ESTAB_STATUS", "SIG_46504_AREA_STATUS", "SIG_46504_POCUP_STATUS", "SIG_21VARS_CELULAS_X",
        "SIG_X_PCT_PESSOAL_ASSENTADOS", "SIG_X_ESTAGROLAVPERM_AREA", "SOMA_PUBLICADA_AREA_46504",
        "AREA_46504_SOB_SIGILO", "PCT_AREA_46504_SOB_SIGILO", "S3C_FILTRAGEM", "S3_REGRA", "E2_R1",
        "E2_R2A", "E2_R3", "E2_R3_TIPOLOGIA", "S4_H2_DWYER_PCTESTAB", "S4_PCTESTAB_X_F1",
        "S4_PCTESTAB_X_F2", "S4_PCTESTAB_X_F3",
        # versão anterior (k = 6)
        "TIPO_ARI_ORIGINAL", "TIPO_MUDANCAS_VS_ORIGINAL",
        # INCRA e reforma agrária
        "INCRA_PROJETOS_2025", "INCRA_FAMILIAS_2025", "INCRA_AREA_2025", "INCRA_MUN_SEDE_2025",
        "INCRA_REF_BENEFICIARIOS", "MARQUES2021_ESTAB_RA_MT", "MARQUES2021_AREA_RA_MT",
        "COBERTURA_MAX_46504_MARQUES", "INCRA_LIM_INF_RA_FORA_46504", "INCRA_LIM_INF_RA_FORA_46504_PCT",
        "COBERTURA_46504AF_REF_MT", "INCRA_PROP_TITRA_AF", "S4_PCT_MT",
        "INCRA_RHO_PCT_ESTAB_141", "INCRA_RHO_F5_141", "INCRA_RHO_S4_141",
        "INCRA_RHO_PCT_ESTAB_REFGT0", "INCRA_RHO_F5_REFGT0", "INCRA_RHO_S4_REFGT0",
        "INCRA_RHO_PCT_ESTAB_REFGE100", "INCRA_RHO_F5_REFGE100", "INCRA_RHO_S4_REFGE100",
        "INCRA_DISCORDANTES_A", "INCRA_DISCORDANTES_B",
    ]
)
# A Tabela A.15 não tem a soma REF de MT por tipo como linha; ela entra para a nota.
faltam = [i for i in IDS if i not in set(NF["id"])]
checar(not faltam, f"NUMEROS_FINAIS: os {len(IDS)} ids usados existem" + (f" (faltam: {faltam})" if faltam else ""))
if faltam:
    sys.exit("ERRO: ids ausentes em NUMEROS_FINAIS.csv")

IDS = list(dict.fromkeys(IDS))
NOTA_A15 = ("MARQUES2021_", "COBERTURA_", "INCRA_LIM_INF", "INCRA_PROP_TITRA", "S4_PCT_MT", "INCRA_REF_BENEF")


def tabela_de(i: str) -> str:
    """Tabela de TABELAS_FINAIS.md em que o número aparece (para citar na página)."""
    if i.startswith("T3_"):
        return "Tabela 3"
    if i.startswith(("INCRA_T", "INCRA_MT_", "INCRA_RHO", "INCRA_DISC")):
        return "Tabela A.15"
    if i.startswith(NOTA_A15):
        return "Tabela A.15 (nota)"
    if i.startswith(("PHI_", "REGRA_", "SENS_K6", "H2_")):
        return "Tabelas A.2 e A.3"
    if i.startswith(("K3", "K4", "K5", "K6", "K_", "TIPO_ARI_WARD", "TIPO_WINS", "TIPO_ARI_ESCORES")):
        return "Tabela A.5"
    if i.startswith("BIOMA_"):
        return "Tabela A.9"
    if i.startswith(("S1_", "S3", "E2_", "S4_H2", "S4_PCTESTAB", "SIG_21", "SIG_X")):
        return "Tabela A.10"
    if i.startswith(("TIPO_ARI_ORIGINAL", "TIPO_MUDANCAS")):
        return "Tabela A.6"
    if i.startswith(("RAZAO_T", "PREV_SEM", "INVERSAO", "OUT_T5")):
        return "Tabela A.8"
    if i.startswith(("AFE_", "CARGA_")):
        return "Tabelas 2 e A.1"
    if i.startswith(("SIG_46504", "SOMA_PUBLICADA", "AREA_46504", "PCT_AREA_46504")):
        return "Tabela 1 (sigilo)"
    if i.startswith("INCRA_"):
        return "área de estudo (INCRA/SIPRA)"
    return "Tabela 1 e totais estaduais"


TABELA = {i: tabela_de(i) for i in IDS}

nf = NF.set_index("id").loc[IDS].reset_index()
nf_out = pd.DataFrame({
    "id": nf["id"], "valor": nf["valor"], "valor_bruto": nf["valor_bruto"], "unidade": nf["unidade"],
    "ano": nf["ano_referencia"], "status_m1": nf["status"], "arquivo_m1": nf["arquivo"],
    "tabela_m1": [TABELA[i] for i in nf["id"]],
})
checar(not nf_out["valor"].eq("").any(), "NUMEROS_FINAIS: nenhum valor vazio entre os ids usados")
V = dict(zip(nf_out["id"], nf_out["valor"]))
VB = dict(zip(nf_out["id"], nf_out["valor_bruto"]))

# Conferências contra os arquivos de origem e a base do site
t3 = ler_csv(RES / "tipologia_k5_tabela3_final.csv")
print("  colunas da Tabela 3 de origem:", ", ".join(map(str, t3.columns[:6])), "...")
for t, n in zip(TIPOS, [74, 25, 20, 10, 12]):
    checar(V[f"T3_{t}_N"] == str(n), f"Tabela 3: {t} com {n} municípios")
    cont = MUN[MUN["tipo_m1"] == t]["bioma"].value_counts()
    ok = all(V[f"T3_{t}_BIOMA250_{b.upper().replace('Ô', 'O')}"] == str(int(cont.get(b, 0))) for b in BIOMAS)
    checar(ok, f"Tabela 3: tipo x bioma do {t} igual a municipios.csv (1:250 mil)")
    soma = int(MUN.loc[MUN["tipo_m1"] == t, "estab_af"].sum())
    checar(V[f"T3_{t}_SOMA_ESTAB_AF"] == br(soma, 0), f"Tabela 3: soma de estab. AF do {t} = {br(soma, 0)}")
checar(V["K5_SILHUETA"] == "0,4165", "silhueta k = 5 = 0,4165")
checar(V["PHI_POSSE_MEC"] == "0,292" and V["PHI_POSSE_MEC_PROMAX"] == "0,367", "Phi posse x mecanização: 0,292 (oblimin) e 0,367 (promax)")
checar(V["COBERTURA_MAX_46504_MARQUES"] == "26,8" and V["MARQUES2021_ESTAB_RA_MT"] == "42.014",
       "cobertura máxima da categoria 46504: 26,8% dos 42.014")
checar(V["SIG_46504_AREA_STATUS"].startswith("54 / 52 / 35"), "área 46504: 52 municípios com X")

# Municípios mais próximos do centroide (nota da Tabela 3 de TABELAS_FINAIS.md)
rep = ler_csv(RES / "tipologia_k5_representativos_final.csv")
md = (RES / "TABELAS_FINAIS.md").read_text(encoding="utf-8")
m = re.search(r"centroide: (T1: .*?)\. Fontes:", md)
checar(m is not None, "TABELAS_FINAIS.md: nota com os municípios mais próximos do centroide")
nota = {}
for parte in m.group(1).split("; T"):
    parte = parte if parte.startswith("T") else "T" + parte
    t, nomes = parte.split(": ", 1)
    nota[t] = [x.strip() for x in nomes.split(", ")]
rep["tipo"] = "T" + rep["tipo"].astype(str)
nome_id = {v: k for k, v in MUN["municipio"].items()}
linhas = []
for t in TIPOS:
    r = rep[rep["tipo"] == t].sort_values("posicao")
    checar(r["municipio"].tolist() == nota[t], f"representativos do {t} iguais à nota da Tabela 3: {', '.join(nota[t])}")
    for _, x in r.iterrows():
        mid = nome_id.get(x["municipio"])
        checar(mid is not None and MUN.loc[mid, "tipo_m1"] == t, f"  {x['municipio']} está em municipios.csv como {t}")
        linhas.append({"tipo": t, "posicao": int(x["posicao"]), "id_municipio": mid, "municipio": x["municipio"],
                       "slug": MUN.loc[mid, "slug"], "bioma": MUN.loc[mid, "bioma"]})
REP = pd.DataFrame(linhas)

# Lista de municípios por tipo (A.19) igual à base do site
lista = ler_csv(RES / "tipologia_k5_lista_municipios_final.csv")
for _, x in lista.iterrows():
    t = f"T{x['tipo']}"
    nomes = sorted(s.strip() for s in str(x["municipios"]).split(";"))
    checar(nomes == sorted(MUN.loc[MUN["tipo_m1"] == t, "municipio"]), f"lista do {t} (Tabela A.19) igual a municipios.csv")

gravar(nf_out, "m1_numeros.csv")
gravar(REP, "m1_representativos.csv")


# ---------------------------------------------------------------------------
# 3. Emissões (Artigo B recalculado pelos tipos do M1): SEEG 13, média 2010-2020
# ---------------------------------------------------------------------------
print("3. Emissões (SEEG 13)")
ANO_INI, ANO_FIM = 2010, 2020
SET = {"emissao_agropecuaria": "agro", "emissao_energia": "energia",
       "emissao_mudanca_de_uso_da_terra_e_floresta": "mut", "emissao_processos_industriais": "proc",
       "emissao_resíduos": "resid"}
w0 = pd.read_parquet(PROC / "seeg_mt_municipal_wide.parquet")
w = w0[w0["cod_ibge"] != 5100000]          # "NA (MT)": emissões não alocadas a município
cols = list(SET) + ["remocao_mudanca_de_uso_da_terra_e_floresta"]
g = w.groupby(["cod_ibge", "ano"])[cols].sum(min_count=1).reset_index()   # junta as duas grafias de S. A. de Leverger
g = g[(g["ano"] >= ANO_INI) & (g["ano"] <= ANO_FIM)]
checar(g["cod_ibge"].nunique() == 141 and len(g) == 141 * 11, "SEEG 2010-2020: 141 municípios x 11 anos")
checar(g[cols].notna().all().all(), "SEEG 2010-2020: nenhuma célula vazia")
e = g.groupby("cod_ibge")[cols].mean().rename(columns=SET)
e = e.rename(columns={"remocao_mudanca_de_uso_da_terra_e_floresta": "remocao"})
e["bruta"] = e[list(SET.values())].sum(axis=1)            # MtCO2e por ano (média 2010-2020)
e = e.join(MUN[["municipio", "bioma", "tipo_m1", "estab_af", "area_af"]], how="inner")
checar(len(e) == 141, "emissões: 141 municípios com tipo e bioma")
e["t_por_estab_af"] = e["bruta"] * 1e6 / e["estab_af"]
e["t_por_ha_af"] = e["bruta"] * 1e6 / e["area_af"]

# Total estadual (SEEG por setor) no mesmo período, para a cobertura dos municípios
st = ler_csv(PROC / "seeg_mt_setor_serie.csv")
st = st[(st["year"] >= ANO_INI) & (st["year"] <= ANO_FIM)]
tot_estado = st.groupby("year")["emissao_MtCO2e"].sum().mean()
tot_mun = e["bruta"].sum()
checar(tot_mun <= tot_estado + 1e-9, f"média 2010-2020: municípios ({br(tot_mun, 2)}) <= estado ({br(tot_estado, 2)}) MtCO2e/ano")

linhas = []
grupos = [("mt", "MT", e)] + [("bioma", b, e[e["bioma"] == b]) for b in BIOMAS] + \
         [("tipo", t, e[e["tipo_m1"] == t]) for t in TIPOS]
for rec, gr, d in grupos:
    s = d["bruta"].sum()
    linhas.append({
        "recorte": rec, "grupo": gr, "n_mun": len(d),
        "bruta_soma": s, "pct_do_total_municipal": 100 * s / tot_mun,
        "bruta_mediana_municipal": d["bruta"].median(),
        "agro_soma": d["agro"].sum(), "energia_soma": d["energia"].sum(), "mut_soma": d["mut"].sum(),
        "proc_soma": d["proc"].sum(), "resid_soma": d["resid"].sum(), "remocao_soma": d["remocao"].sum(),
        "pct_agro": 100 * d["agro"].sum() / s, "pct_energia": 100 * d["energia"].sum() / s,
        "pct_mut": 100 * d["mut"].sum() / s, "pct_proc": 100 * d["proc"].sum() / s,
        "pct_resid": 100 * d["resid"].sum() / s,
        "estab_af": d["estab_af"].sum(), "area_af": d["area_af"].sum(),
        "t_por_estab_af": s * 1e6 / d["estab_af"].sum(), "t_por_ha_af": s * 1e6 / d["area_af"].sum(),
        "t_por_estab_af_mediana": d["t_por_estab_af"].median(), "t_por_ha_af_mediana": d["t_por_ha_af"].median(),
    })
EMI = pd.DataFrame(linhas)
EMI.insert(3, "periodo", f"{ANO_INI}-{ANO_FIM}")
checar(np.allclose(EMI[["pct_agro", "pct_energia", "pct_mut", "pct_proc", "pct_resid"]].sum(axis=1), 100),
       "composição setorial soma 100% em cada grupo")
checar(abs(EMI.loc[EMI["recorte"] == "tipo", "bruta_soma"].sum() - tot_mun) < 1e-9, "soma dos tipos = soma dos 141 municípios")

MET = {"bruta": "Emissões brutas (média anual 2010–2020)", "mut": "Mudança de uso da terra e florestas",
       "agro": "Agropecuária", "energia": "Energia",
       "t_por_estab_af": "Emissões brutas por estabelecimento da AF", "t_por_ha_af": "Emissões brutas por hectare da AF"}
tes = []
for rec, gcol, ordem in (("tipo", "tipo_m1", TIPOS), ("bioma", "bioma", BIOMAS)):
    for col, rot in MET.items():
        h, p, n, gl, eps = kw(e, col, gcol, ordem)
        tes.append({"recorte": rec, "metrica": col, "rotulo": rot, "n": n, "gl": gl, "H": h, "p": p, "epsilon2": eps})
TES = pd.DataFrame(tes)
TES["p"] = TES["p"].map(lambda x: f"{x:.6g}")          # p em notação científica quando pequeno
nao_aloc = w0[(w0["cod_ibge"] == 5100000) & (w0["ano"] >= ANO_INI) & (w0["ano"] <= ANO_FIM)]
nao_aloc = nao_aloc.groupby("ano")[list(SET)].sum(min_count=1).sum(axis=1).mean()
checar(abs(tot_mun + nao_aloc - tot_estado) < 0.01,
       f"média 2010-2020: municípios + não alocado ({br(nao_aloc, 3)}) = total estadual do SEEG")
EMI_RES = pd.DataFrame([
    {"id": "ano_ini", "valor": ANO_INI, "unidade": "ano"},
    {"id": "ano_fim", "valor": ANO_FIM, "unidade": "ano"},
    {"id": "total_estadual_media", "valor": tot_estado, "unidade": "MtCO2e/ano"},
    {"id": "total_municipios_media", "valor": tot_mun, "unidade": "MtCO2e/ano"},
    {"id": "nao_alocado_media", "valor": nao_aloc, "unidade": "MtCO2e/ano"},
])
gravar(EMI_RES, "emissoes_resumo.csv")
gravar(EMI, "emissoes_grupos.csv")
gravar(TES, "emissoes_testes.csv")
print("  Kruskal-Wallis por tipo:", "; ".join(f"{r.metrica} H={br(r.H, 2)} p={float(r.p):.4g}"
                                             for r in TES[TES.recorte == "tipo"].itertuples()))


# ---------------------------------------------------------------------------
# 4. Proxy de desmatamento (SEEG MUT / 150 tCO2e/ha) x PRODES oficial
# ---------------------------------------------------------------------------
print("4. Proxy de desmatamento x PRODES oficial")
taxa = ler_csv(PROC / "prodes_mt_taxa_amazonia_legal.csv")
inc = ler_csv(PROC / "prodes_mt_serie_bioma.csv")
checar(set(inc["status"]) <= {"consolidado", "parcial"} and "data_acesso" in inc.columns,
       "PRODES por bioma: série oficial do TerraBrasilis (com status e data de acesso)")
checar(inc["url"].str.contains("terrabrasilis").all() and taxa["url"].str.contains("terrabrasilis").all(),
       "PRODES: todas as linhas com URL do TerraBrasilis")
est = ler_csv(PROC / "robustez_B_validacao_estadual_anual.csv")
prox = pd.read_parquet(PROC / "A_desmat_estimado_municipal_MT.parquet")
checar(prox["cod_ibge"].nunique() == 141 and 5100000 not in set(prox["cod_ibge"]), "proxy: 141 municípios, sem o não alocado")
pa = prox.groupby("ano")["desmat_ha_proxy"].sum()
checar(np.allclose(est.set_index("year")["proxy_ha"], pa.loc[ANO_INI:ANO_FIM], atol=0.01),
       "Tabela 3 do Artigo B (robustez): proxy anual = soma municipal da proxy")
tx = taxa[taxa["status"] == "consolidada"].set_index("year")["taxa_km2"] * 100
checar(np.allclose(est.set_index("year")["prodes_taxa_amz_legal_ha"], tx.loc[ANO_INI:ANO_FIM]),
       "Tabela 3 do Artigo B (robustez): PRODES = taxa oficial de MT x 100")
rp, pp = pearsonr(est["proxy_ha"], est["prodes_taxa_amz_legal_ha"])
rs, ps = spearmanr(est["proxy_ha"], est["prodes_taxa_amz_legal_ha"])
tp, tt = est["proxy_ha"].sum(), est["prodes_taxa_amz_legal_ha"].sum()
checar(round(tp) == 11614958 and round(tt) == 1458400, "totais 2010-2020: proxy 11.614.958 ha; PRODES 1.458.400 ha")
checar(round(tp / tt, 2) == 7.96, f"razão total = {br(tp / tt, 2)} (nota de correção: 7,96)")
checar(round(rp, 2) == 0.65 and round(pp, 2) == 0.03 and round(rs, 2) == 0.68,
       f"Pearson {br(rp, 3)} (p = {br(pp, 3)}); Spearman {br(rs, 3)} (nota de correção: 0,65; 0,03; 0,68)")
EST = est[["year", "proxy_ha", "prodes_taxa_amz_legal_ha", "razao_taxa"]].rename(
    columns={"year": "ano", "prodes_taxa_amz_legal_ha": "prodes_taxa_ha", "razao_taxa": "razao"})
EST["razao"] = EST["proxy_ha"] / EST["prodes_taxa_ha"]
RESUMO = pd.DataFrame([
    {"id": "n_anos", "valor": len(EST), "unidade": "anos"},
    {"id": "ano_ini", "valor": ANO_INI, "unidade": "ano"},
    {"id": "ano_fim", "valor": ANO_FIM, "unidade": "ano"},
    {"id": "proxy_total_ha", "valor": tp, "unidade": "ha"},
    {"id": "prodes_total_ha", "valor": tt, "unidade": "ha"},
    {"id": "razao_total", "valor": tp / tt, "unidade": "vezes"},
    {"id": "razao_min", "valor": EST["razao"].min(), "unidade": "vezes"},
    {"id": "razao_max", "valor": EST["razao"].max(), "unidade": "vezes"},
    {"id": "pearson", "valor": rp, "unidade": ""},
    {"id": "pearson_p", "valor": float(f"{pp:.6g}"), "unidade": ""},
    {"id": "spearman", "valor": rs, "unidade": ""},
    {"id": "spearman_p", "valor": ps, "unidade": ""},
    {"id": "fator_tco2e_ha", "valor": 150, "unidade": "tCO2e/ha"},
])

# Por bioma: recalculado com o bioma dominante IBGE 1:250 mil (2019), só períodos anuais.
# Conferência: com o crosswalk de 2004 usado na robustez, o resultado tem de ser o mesmo do arquivo.
pr = inc[(inc["status"] == "consolidado") & (inc["n_anos"] == 1)][["year", "bioma", "desmat_ha"]]
pr["bioma"] = pr["bioma"].map({"Amazonia": "Amazônia", "Cerrado": "Cerrado", "Pantanal": "Pantanal"})
checar(pr["bioma"].notna().all(), "PRODES por bioma: nomes de bioma reconhecidos")
cw = ler_csv(PROC / "clusters_municipios_MT.csv", usecols=["cod_ibge", "bioma_dominante"])
cw["bioma_dominante"] = cw["bioma_dominante"].map({"Amazonia": "Amazônia", "Cerrado": "Cerrado", "Pantanal": "Pantanal"})
rob = ler_csv(PROC / "robustez_B_validacao_bioma.csv")
rob = rob[rob["periodos"] == "anuais"]
rob["bioma"] = rob["bioma"].map({"Amazonia": "Amazônia", "Cerrado": "Cerrado", "Pantanal": "Pantanal"})


def valida_bioma(mapa: pd.Series, escala: str) -> list[dict]:
    p = prox.merge(mapa.rename("bioma"), left_on="cod_ibge", right_index=True, how="left")
    a = p.groupby(["bioma", "ano"])["desmat_ha_proxy"].sum().rename("proxy_ha").reset_index()
    j = a.merge(pr, left_on=["bioma", "ano"], right_on=["bioma", "year"], how="inner")
    out = []
    for b in BIOMAS:
        x = j[j["bioma"] == b]
        out.append({"escala_bioma": escala, "bioma": b, "periodos": "anuais", "n_anos": len(x),
                    "ano_ini": int(x["ano"].min()), "ano_fim": int(x["ano"].max()),
                    "n_mun": int((mapa == b).sum()),
                    "pearson": pearsonr(x["proxy_ha"], x["desmat_ha"])[0],
                    "spearman": spearmanr(x["proxy_ha"], x["desmat_ha"])[0],
                    "razao": x["proxy_ha"].sum() / x["desmat_ha"].sum(),
                    "proxy_total_ha": x["proxy_ha"].sum(), "prodes_total_ha": x["desmat_ha"].sum()})
    return out


v04 = pd.DataFrame(valida_bioma(cw.set_index("cod_ibge")["bioma_dominante"], "crosswalk 2004 (robustez do Artigo B)"))
for _, r in rob.iterrows():
    x = v04[v04["bioma"] == r["bioma"]].iloc[0]
    checar(abs(x["pearson"] - r["pearson"]) < 6e-4 and abs(x["spearman"] - r["spearman"]) < 6e-4
           and abs(x["razao"] - r["razao_proxy_prodes"]) < 6e-3 and x["n_anos"] == r["n_anos"],
           f"robustez reproduzida ({r['bioma']}): Pearson {br(x['pearson'], 3)}, Spearman {br(x['spearman'], 3)}, razão {br(x['razao'], 2)}")
v250 = pd.DataFrame(valida_bioma(MUN["bioma"], "IBGE 1:250 mil (2019)"))
BIO = pd.concat([v250, v04], ignore_index=True)
print("  por bioma (1:250 mil):", "; ".join(f"{r.bioma} r={br(r.pearson, 2)} rho={br(r.spearman, 2)} razão={br(r.razao, 1)}"
                                            for r in v250.itertuples()))
gravar(EST, "proxy_prodes_estadual.csv")
gravar(RESUMO, "proxy_prodes_resumo.csv")
gravar(BIO, "proxy_prodes_bioma.csv")


# ---------------------------------------------------------------------------
# 5. Dinâmica 2006-2017 (Artigo C recalculado pelos tipos do M1): todos os estabelecimentos
# ---------------------------------------------------------------------------
print("5. Dinâmica 2006-2017")
c = ler_csv(PROC / "C_base_dinamica_clusters_corrigido.csv",
            usecols=["cod_ibge", "n_estab_total_2006", "n_estab_total_2017", "area_total_ha_2006",
                     "area_total_ha_2017", "valor_2006_corrigido"])
checar(len(c) == 141 and c[["n_estab_total_2006", "n_estab_total_2017", "area_total_ha_2006", "area_total_ha_2017"]].notna().all().all(),
       "base da dinâmica: 141 municípios, estabelecimentos e área sem célula vazia")
c = c.set_index("cod_ibge").join(MUN[["municipio", "bioma", "tipo_m1"]], how="inner")
checar(len(c) == 141, "dinâmica: 141 municípios com tipo e bioma")
dsite = ler_csv(DS / "dinamica_2006_2017.csv").set_index("id_municipio")
checar(all(np.allclose(c[k], dsite.loc[c.index, k]) for k in
           ["n_estab_total_2006", "n_estab_total_2017", "area_total_ha_2006", "area_total_ha_2017"]),
       "dinâmica: igual a dados_site/dinamica_2006_2017.csv")
c["area_media_2006"] = c["area_total_ha_2006"] / c["n_estab_total_2006"]
c["area_media_2017"] = c["area_total_ha_2017"] / c["n_estab_total_2017"]
c["var_estab"] = 100 * (c["n_estab_total_2017"] / c["n_estab_total_2006"] - 1)
c["var_area"] = 100 * (c["area_total_ha_2017"] / c["area_total_ha_2006"] - 1)
c["var_area_media"] = 100 * (c["area_media_2017"] / c["area_media_2006"] - 1)

linhas = []
for rec, gr, d in [("mt", "MT", c)] + [("bioma", b, c[c["bioma"] == b]) for b in BIOMAS] + \
                  [("tipo", t, c[c["tipo_m1"] == t]) for t in TIPOS]:
    e6, e7 = d["n_estab_total_2006"].sum(), d["n_estab_total_2017"].sum()
    a6, a7 = d["area_total_ha_2006"].sum(), d["area_total_ha_2017"].sum()
    linhas.append({"recorte": rec, "grupo": gr, "n_mun": len(d),
                   "estab_2006": e6, "estab_2017": e7, "var_estab": 100 * (e7 / e6 - 1),
                   "area_2006": a6, "area_2017": a7, "var_area": 100 * (a7 / a6 - 1),
                   "area_media_2006": a6 / e6, "area_media_2017": a7 / e7, "var_area_media": 100 * ((a7 / e7) / (a6 / e6) - 1),
                   "mediana_var_estab": d["var_estab"].median(), "mediana_var_area": d["var_area"].median(),
                   "mediana_var_area_media": d["var_area_media"].median(),
                   "n_mun_estab_cai": int((d["var_estab"] < 0).sum()), "n_mun_area_cai": int((d["var_area"] < 0).sum())})
DIN = pd.DataFrame(linhas)
checar(int(DIN.loc[0, "estab_2006"]) == 112987 and int(DIN.loc[0, "estab_2017"]) == 118679,
       "soma municipal: 112.987 estab. (2006) e 118.679 (2017)")
checar(int(DIN.loc[0, "area_2006"]) == 48688715 and int(DIN.loc[0, "area_2017"]) == 54922849,
       "soma municipal: 48.688.715 ha (2006) e 54.922.849 ha (2017)")
DMET = {"var_estab": "Variação do número de estabelecimentos (%)", "var_area": "Variação da área (%)",
        "var_area_media": "Variação da área média por estabelecimento (%)"}
tes = []
for rec, gcol, ordem in (("tipo", "tipo_m1", TIPOS), ("bioma", "bioma", BIOMAS)):
    for col, rot in DMET.items():
        h, p, n, gl, eps = kw(c, col, gcol, ordem)
        tes.append({"recorte": rec, "metrica": col, "rotulo": rot, "n": n, "gl": gl, "H": h, "p": p, "epsilon2": eps})
DTES = pd.DataFrame(tes)
DTES["p"] = DTES["p"].map(lambda x: f"{x:.6g}")

# Conciliação com as tabelas estaduais (Tabelas_MT_Brasil_Censo2017.xlsx)
import openpyxl  # noqa: E402

wb = openpyxl.load_workbook(PROC / "Tabelas_MT_Brasil_Censo2017.xlsx", data_only=True, read_only=True)


def celula(aba: str, rotulo: str, col: int):
    for row in wb[aba].iter_rows(values_only=True):
        if row and isinstance(row[0], str) and row[0].strip().startswith(rotulo):
            return row[col]
    sys.exit(f"ERRO: '{rotulo}' não achado na aba '{aba}'")


comp_estab = celula("8. Comparacao 2006-2017", "Estabelecimentos (n)", 1)
comp_area = celula("8. Comparacao 2006-2017", "Area Total (ha)", 1)
comp_vbp = celula("8. Comparacao 2006-2017", "VBP Total (R$ 1.000)", 1)
comp_estab17 = celula("8. Comparacao 2006-2017", "Estabelecimentos (n)", 3)
comp_area17 = celula("8. Comparacao 2006-2017", "Area Total (ha)", 3)
checar(comp_estab17 == 118679 and comp_area17 == 54922850, "tabela estadual (aba 8): 118.679 estab.; 54.922.850 ha (2017)")
serie_estab = celula("5. Serie Historica", "Estabelecimentos (n)", 5)
serie_area = celula("5. Serie Historica", "Area Total (ha)", 5)
checar(comp_estab == 112978 and comp_area == 47805514 and comp_vbp == 9601893,
       "tabela estadual (aba 8): 112.978 estab.; 47.805.514 ha; VBP R$ 9.601.893 mil (2006)")
checar(serie_estab == 112987 and serie_area == 48688710,
       "tabela de confronto do IBGE (aba 5): 112.987 estab.; 48.688.710 ha (2006)")
vbp_mun = c["valor_2006_corrigido"].sum()
checar(round(vbp_mun) == 12291803, "base municipal corrigida: VBP 2006 = R$ 12.291.803 mil")
area_dif = DIN.loc[0, "area_2006"] - comp_area
CONC = pd.DataFrame([
    {"item": "estab_2006", "rotulo": "Estabelecimentos agropecuários, 2006", "unidade": "estabelecimentos",
     "soma_municipal": DIN.loc[0, "estab_2006"], "tabela_estadual": comp_estab, "tabela_confronto_ibge": serie_estab,
     "diferenca": DIN.loc[0, "estab_2006"] - comp_estab, "pct_diferenca": 100 * (DIN.loc[0, "estab_2006"] / comp_estab - 1)},
    {"item": "area_2006", "rotulo": "Área dos estabelecimentos agropecuários, 2006", "unidade": "hectares",
     "soma_municipal": DIN.loc[0, "area_2006"], "tabela_estadual": comp_area, "tabela_confronto_ibge": serie_area,
     "diferenca": area_dif, "pct_diferenca": 100 * area_dif / comp_area},
    {"item": "vbp_2006", "rotulo": "Valor da produção dos estabelecimentos agropecuários, 2006 (valores correntes)",
     "unidade": "R$ mil", "soma_municipal": vbp_mun, "tabela_estadual": comp_vbp, "tabela_confronto_ibge": np.nan,
     "diferenca": vbp_mun - comp_vbp, "pct_diferenca": 100 * (vbp_mun / comp_vbp - 1)},
    {"item": "estab_2017", "rotulo": "Estabelecimentos agropecuários, 2017", "unidade": "estabelecimentos",
     "soma_municipal": DIN.loc[0, "estab_2017"], "tabela_estadual": comp_estab17, "tabela_confronto_ibge": np.nan,
     "diferenca": DIN.loc[0, "estab_2017"] - comp_estab17, "pct_diferenca": 100 * (DIN.loc[0, "estab_2017"] / comp_estab17 - 1)},
    {"item": "area_2017", "rotulo": "Área dos estabelecimentos agropecuários, 2017", "unidade": "hectares",
     "soma_municipal": DIN.loc[0, "area_2017"], "tabela_estadual": comp_area17, "tabela_confronto_ibge": np.nan,
     "diferenca": DIN.loc[0, "area_2017"] - comp_area17, "pct_diferenca": 100 * (DIN.loc[0, "area_2017"] / comp_area17 - 1)},
])
checar(round(area_dif) == 883201 and round(100 * area_dif / comp_area, 1) == 1.8, "diferença de área em 2006: 883.201 ha (1,8%)")
checar(abs(vbp_mun / comp_vbp - 1) > 0.05, "VBP 2006 não concilia (diferença > 5%): fica fora do site")
gravar(DIN, "dinamica_grupos.csv")
gravar(DTES, "dinamica_testes.csv")
gravar(CONC, "dinamica_conciliacao.csv")


# ---------------------------------------------------------------------------
# 6. Figuras finais do M1 usadas nas páginas (SVG; o mapa da Figura 6 usa o PNG
#    que o script 01 já copia para resultados/figuras/m1/, porque o SVG tem 3,3 MB)
# ---------------------------------------------------------------------------
print("6. Figuras")
FIGS = ["fig3_matriz_phi_final.svg", "figA4_criterios_k_final.svg", "figA5_validacao_incra_final.svg"]
for f in FIGS:
    shutil.copy2(FIG / f, FIG_SITE / f)
    print(f"  copiada resultados/figuras/{f} ({(FIG_SITE / f).stat().st_size // 1024} kB)")
checar((FIG_SITE / "m1" / "fig6_censo_incra_final.png").exists(),
       "resultados/figuras/m1/fig6_censo_incra_final.png existe (script 01)")


# ---------------------------------------------------------------------------
# 7. Varredura: nada de caminho local, e-mail, Drive, base comercial ou menção proibida
# ---------------------------------------------------------------------------
print("7. Varredura")
# padrões montados por partes, para que este arquivo não contenha os próprios termos
RUINS = ["C:" + "/Users", "C:" + "\\Users", "Meu " + "Drive", "@" + "unemat", "@" + "gmail", "drive." + "google",
         "LS" + "EG", "Refi" + "nitiv", "Alli" + "ed Off" + "sets", "SR13" + "MT"]   # os demais termos vetados: script 07
alvos = list(OUT.glob("*.csv")) + [FIG_SITE / f for f in FIGS]
achados = []
for p in alvos:
    txt = p.read_text(encoding="utf-8", errors="ignore")
    for r in RUINS:
        if r in txt:
            achados.append(f"{p.name}: {r}")
checar(not achados, "saídas sem caminho local, e-mail, link do Drive ou base comercial" + (f" ({achados})" if achados else ""))

cat = pd.DataFrame([{"arquivo": p.name, "linhas": sum(1 for _ in open(p, encoding="utf-8")) - 1,
                     "kb": round(p.stat().st_size / 1024, 1)} for p in sorted(OUT.glob("*.csv")) if p.name != "catalogo.csv"])
gravar(cat, "catalogo.csv")

if ERROS:
    print(f"\n{len(ERROS)} checagem(ns) falharam:")
    for x in ERROS:
        print("  -", x)
    sys.exit(1)
print("\nTudo certo.")
