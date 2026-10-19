# -*- coding: utf-8 -*-
"""
01_preparar_dados.py - Observatório RESA-MT

Lê as bases do Projeto RESA e grava, no repositório, só o que o site usa e o
que pode ser baixado:
  dados_site/   dados lidos na renderização (ver README, seção "Dados do site")
  arquivos/     downloads (CSV com dicionário, malha GeoJSON)
  resultados/figuras/m1/   figuras finais do Manuscrito 1 usadas nas páginas (PNG)

A raiz do projeto vem da variável de ambiente RESA_FONTES ou do arquivo
config.local.toml (fora do controle de versão), com a linha:
  resa_fontes = "<raiz do projeto RESA>"

Rodar a partir da raiz do repositório (Git Bash):
  RESA_FONTES="<raiz do projeto RESA>" python -I scripts/01_preparar_dados.py

Regras aplicadas aqui (ver README):
  - X (sigilo do IBGE), – (zero absoluto) e ... (não disponível) nunca viram 0
    nem célula vazia: a célula do número traz o próprio sinal (como nas tabelas
    do IBGE) e a coluna de sinal repete o sinal ("valor" quando há número).
  - Bioma: IBGE 1:250 mil (2019), coluna dom_250mil_2019.
  - Tipologia: só a do Manuscrito 1 (k = 5), com rótulos provisórios.
  - Não usa colunas __compl, __compl_fonte, chk_ nem os arquivos de espelhos
    de sigilo, nem a série antiga do PRODES.
O script para com erro se alguma checagem falhar.
"""

import json
import os
import shutil
import sys
import unicodedata
from pathlib import Path

import numpy as np
import pandas as pd

REPO = Path(__file__).resolve().parents[1]
HOJE = "19/10/2026"


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
    if not (p / "2_Dados" / "Processados").is_dir():
        sys.exit("ERRO: RESA_FONTES não aponta para a raiz do projeto (falta 2_Dados/Processados).")
    return p


FONTES = raiz_fontes()
M1 = FONTES / "4_Outputs" / "artigos" / "01_Manuscrito_1_LUP_Corrigido"
EXT = M1 / "02_Dados_extraidos"
RES = M1 / "03_Resultados"
FIG = M1 / "04_Figuras" / "final_v5"
PROC = FONTES / "2_Dados" / "Processados"

# Arquivos que o site nunca usa (regra do projeto)
PROIBIDOS = ("sigilo_espelhos_", "dataset_AF_MT_sigilo_R1_final.csv", "sigilo_E2_R3_",
             "prodes_mt_serie_bioma_" + "ANTI" + "GO_manual.csv", "mapeamento_vars_cabral_sidra.json")  # o nome da série manual vai em partes

DS = REPO / "dados_site"
ARQ = REPO / "arquivos"
for d in (DS, ARQ / "dados" / "dicionarios", ARQ / "geo", REPO / "resultados" / "figuras" / "m1"):
    d.mkdir(parents=True, exist_ok=True)

ERROS: list[str] = []


def checar(cond: bool, msg: str) -> None:
    print(("  ok  " if cond else "  ERRO ") + msg)
    if not cond:
        ERROS.append(msg)


def ler_csv(p: Path, **kw) -> pd.DataFrame:
    nome = p.name
    if any(nome.startswith(x) or nome == x for x in PROIBIDOS):
        sys.exit(f"ERRO: arquivo proibido: {nome}")
    return pd.read_csv(p, encoding="utf-8", **kw)


def sem_colunas_proibidas(df: pd.DataFrame, onde: str) -> None:
    ruins = [c for c in df.columns if "__compl" in c or c.startswith("chk_")]
    if ruins:
        sys.exit(f"ERRO: colunas proibidas em {onde}: {ruins}")


def slugify(x: str) -> str:
    x = unicodedata.normalize("NFKD", x).encode("ascii", "ignore").decode("ascii").lower()
    out = []
    for ch in x:
        out.append(ch if ch.isalnum() else "-")
    s = "".join(out)
    while "--" in s:
        s = s.replace("--", "-")
    return s.strip("-")


def fmt_num(x) -> str:
    """Número para CSV: vazio se NaN; inteiro sem casas; senão até 6 casas, ponto decimal."""
    if x is None or (isinstance(x, float) and np.isnan(x)):
        return ""
    x = float(x)
    if abs(x - round(x)) < 1e-9 and abs(x) < 1e15:
        return str(int(round(x)))
    return f"{x:.6f}".rstrip("0").rstrip(".")


def gravar(df: pd.DataFrame, p: Path) -> None:
    df = df.copy()
    for c in df.columns:
        if pd.api.types.is_float_dtype(df[c]):
            df[c] = df[c].map(fmt_num)
    df.to_csv(p, index=False, encoding="utf-8", lineterminator="\n")


# ---------------------------------------------------------------------------
# 1. Municípios: bioma (IBGE 1:250 mil, 2019), tipo do M1 (k = 5), sedes dos pilotos
# ---------------------------------------------------------------------------
print("\n1. Municípios")
BIOMA_NOME = {"Amazonia": "Amazônia", "Cerrado": "Cerrado", "Pantanal": "Pantanal"}
ROTULO_M1 = {  # rótulos PROVISÓRIOS (pendentes dos autores do Manuscrito 1)
    "T1": "Baixo porte agregado",
    "T2": "Posse aguardando titulação, sem especialização",
    "T3": "Grande porte agregado",
    "T4": "Mecanizado com posse aguardando titulação",
    "T5": "Hortícola-irrigado",
}
N_TIPO = {"T1": 74, "T2": 25, "T3": 20, "T4": 10, "T5": 12}
ROTULO_STATUS = "provisório (pendente dos autores)"
PILOTOS = {  # município-sede -> área-piloto (uma por bioma)
    5105101: ("Juara", "Vale do Arinos", "vale-do-arinos"),
    5105259: ("Lucas do Rio Verde", "Quatá e N. Sra. Aparecida", "quata-nsa-aparecida"),
    5106505: ("Poconé", "Lambari", "lambari"),
}

bio = ler_csv(EXT / "biomas_municipios_5000mil_vs_250mil.csv")
tip = ler_csv(RES / "tipologia_municipios_final.csv")
lista = ler_csv(RES / "tipologia_k5_lista_municipios_final.csv")

mun = pd.DataFrame({
    "id_municipio": bio["cod_ibge"].astype(int),
    "municipio": bio["municipio"].astype(str).str.strip(),
    "bioma": bio["dom_250mil_2019"].map(BIOMA_NOME),
    "pct_amazonia": bio["pct_Amazonia_250mil_2019"].astype(float),
    "pct_cerrado": bio["pct_Cerrado_250mil_2019"].astype(float),
    "pct_pantanal": bio["pct_Pantanal_250mil_2019"].astype(float),
})
t = tip[["cod_ibge", "tipo_k5", "bioma_250"]].rename(columns={"cod_ibge": "id_municipio"})
mun = mun.merge(t, on="id_municipio", how="left", validate="1:1")
checar(mun["tipo_k5"].notna().all(), "todos os municípios têm tipo do M1")
mun["tipo_m1"] = "T" + mun["tipo_k5"].astype(int).astype(str)
mun["rotulo_m1"] = mun["tipo_m1"].map(ROTULO_M1)
checar((mun["bioma_250"].map(BIOMA_NOME) == mun["bioma"]).all(),
       "bioma da tipologia do M1 = dom_250mil_2019 em todos os municípios")
mun = mun.drop(columns=["tipo_k5", "bioma_250"])
mun["slug"] = mun["municipio"].map(slugify)
mun["sede_piloto"] = mun["id_municipio"].isin(PILOTOS)
mun["piloto"] = mun["id_municipio"].map(lambda i: PILOTOS[i][1] if i in PILOTOS else "")
mun["piloto_slug"] = mun["id_municipio"].map(lambda i: PILOTOS[i][2] if i in PILOTOS else "")
mun = mun.sort_values("municipio", key=lambda s: s.map(slugify)).reset_index(drop=True)
mun = mun[["id_municipio", "municipio", "slug", "bioma", "pct_amazonia", "pct_cerrado", "pct_pantanal",
           "tipo_m1", "rotulo_m1", "sede_piloto", "piloto", "piloto_slug"]]

checar(len(mun) == 141, f"141 municípios (lidos: {len(mun)})")
checar(mun["id_municipio"].astype(str).str.fullmatch(r"51\d{5}").all(), "códigos IBGE de 7 dígitos (51xxxxx)")
checar(mun["slug"].is_unique, "slugs únicos")
vc = mun["bioma"].value_counts().to_dict()
checar(vc == {"Amazônia": 76, "Cerrado": 61, "Pantanal": 4}, f"biomas 76/61/4 (lidos: {vc})")
vt = mun["tipo_m1"].value_counts().to_dict()
checar(vt == N_TIPO, f"tipos do M1 74/25/20/10/12 (lidos: {vt})")
for i, (nome, _, _) in PILOTOS.items():
    checar(mun.loc[mun.id_municipio == i, "municipio"].item() == nome, f"sede de piloto {i} = {nome}")
# conferência com a lista de municípios por tipo (Tabela A.19)
for _, r in lista.iterrows():
    tipo = f"T{int(r['tipo'])}"
    nomes_lista = sorted(slugify(x.strip()) for x in str(r["municipios"]).split(";"))
    nomes_mun = sorted(mun.loc[mun.tipo_m1 == tipo, "slug"])
    checar(nomes_lista == nomes_mun and int(r["n"]) == N_TIPO[tipo], f"{tipo}: lista de municípios confere")
gravar(mun, DS / "municipios.csv")
IDS = mun["id_municipio"].tolist()

# ---------------------------------------------------------------------------
# 2. Células do Censo 2017 com o sinal de cada uma
# ---------------------------------------------------------------------------
print("\n2. Células do Censo Agropecuário 2017 (com sinal)")
MAPA_SINAL = {"valor": "valor", "X_sigilo": "X", "X": "X", "zero_absoluto": "–", "-": "–", "–": "–",
              "...": "...", "sem_registro": "..."}


def padroniza(s: pd.Series) -> pd.Series:
    s = s.fillna("").astype(str).str.strip()
    desconhecidos = sorted(set(s) - set(MAPA_SINAL))
    if desconhecidos:
        sys.exit(f"ERRO: sinal desconhecido: {desconhecidos}")
    return s.map(MAPA_SINAL)


CEL: dict[str, pd.DataFrame] = {}   # variável -> DataFrame(index=id_municipio; valor, sinal)


def guarda(var: str, ids, valor, sinal) -> None:
    df = pd.DataFrame({"valor": pd.to_numeric(pd.Series(list(valor)), errors="coerce").values,
                       "sinal": list(sinal)}, index=pd.Index([int(i) for i in ids], name="id_municipio"))
    df.loc[df["sinal"] != "valor", "valor"] = np.nan        # X, – e ... nunca viram número
    if df.loc[df["sinal"] == "valor", "valor"].isna().any():
        sys.exit(f"ERRO: célula com sinal 'valor' sem número em {var}")
    df = df.reindex(IDS)
    if df["sinal"].isna().any():
        sys.exit(f"ERRO: municípios sem célula em {var}")
    CEL[var] = df


# 2a. Variáveis do SIDRA com sinal célula a célula (D1a do M1)
sid = ler_csv(EXT / "sidra_raw_status_long.csv", dtype=str, keep_default_na=False)
VARS_SIDRA = ["n_estab_AF_total", "area_AF_total", "n_estab_AF_assent", "area_AF_assent", "pocupestagro",
              "prodestagro_val", "valprodanimal", "estagrotrat", "estagroplantdir", "estagroirri",
              "estagrorechidri", "estagrohort", "estagroprodprop", "estagroveic", "estagrocolh", "pocup_assent"]
for v in VARS_SIDRA:
    x = sid[(sid["variavel"] == v) & (sid["tipo"] == "extraida")]
    checar(len(x) == 141, f"{v}: 141 células no arquivo de sinais")
    guarda(v, x["cod_ibge"], x["valor_num"].replace("", np.nan), padroniza(x["status"]))

# 2b. Bases complementares do M1 (D1b), com a coluna __status de cada série
def de_arquivo(arquivo: str, variaveis: list[str]) -> None:
    d = ler_csv(EXT / arquivo, dtype=str, keep_default_na=False)
    for v in variaveis:
        guarda(v, d["cod_ibge"], d[v].replace("", np.nan), padroniza(d[v + "__status"]))


de_arquivo("orientacao_tecnica_AF_MT.csv", ["ot_total", "ot_recebe"])
de_arquivo("financiamento_AF_MT.csv", ["financ_total_n_estab", "financ_pronaf_n_estab", "dap_total_n_estab",
                                       "dap_sim_n_estab"])
de_arquivo("finalidade_producao_AF_MT.csv", ["finalid_total_n_estab", "finalid_consumo_proprio_n_estab"])
de_arquivo("leite_AF_MT.csv", ["leite_n_estab"])
de_arquivo("alimentos_basicos_AF_MT.csv", ["mandioca_n_estab"])

# 2c. Todos os estabelecimentos (AF e não AF), 2006 e 2017 (base da dinâmica, todos os estabelecimentos)
din = ler_csv(PROC / "C_base_dinamica_clusters_corrigido.csv")
din = din.rename(columns={"cod_ibge": "id_municipio"})
din = din[["id_municipio", "n_estab_total_2006", "n_estab_total_2017", "area_total_ha_2006",
           "area_total_ha_2017", "pct_var_n_estab", "pct_var_area"]]    # o tipo antigo (k = 6) fica fora
for v in ["n_estab_total_2006", "n_estab_total_2017", "area_total_ha_2006", "area_total_ha_2017"]:
    checar(din[v].notna().all(), f"{v}: sem célula vazia")
    guarda(v, din["id_municipio"], din[v], ["valor"] * len(din))

# 2d. INCRA/SIPRA (Relatório 0227, posição de 03/06/2025), por município-sede
inc = ler_csv(EXT / "incra_pa_por_municipio.csv")
for v in ["n_projetos", "familias_assentadas", "area_ha"]:
    checar(inc[v].notna().all(), f"SIPRA {v}: sem célula vazia")
    guarda("sipra_" + v, inc["cod_ibge"], inc[v], ["valor"] * len(inc))

# 2e. Consistência dos denominadores
d1 = CEL["ot_total"]["valor"]; d2 = CEL["n_estab_AF_total"]["valor"]
dif = (d1 - d2).abs()
print(f"  info ot_total (tab. 6780) x n_estab_AF_total (tab. 6878): {int((dif > 0).sum())} municípios diferem; "
      f"maior diferença = {fmt_num(dif.max())}")
checar(CEL["n_estab_AF_total"]["sinal"].eq("valor").all(), "n_estab_AF_total sem X, – ou ...")

# ---------------------------------------------------------------------------
# 3. Indicadores (34): especificação
# ---------------------------------------------------------------------------
print("\n3. Indicadores")
T6878 = "IBGE, Censo Agropecuário 2017, SIDRA, tabela 6878"
NOTA_AF = "Agricultura familiar (AF) conforme a Lei 11.326/2006, na tipologia do Censo Agropecuário 2017."
NOTA_46504 = ("Categoria 46504 do Censo 2017 (condição do produtor em relação às terras): concessionário(a) ou "
              "assentado(a) aguardando titulação definitiva (Censo 2017). Não equivale ao total de assentados da "
              "reforma agrária: assentados com título aparecem como proprietários.")
NOTA_SIPRA = ("INCRA/SIPRA, Relatório 0227, posição de 03/06/2025. Cada projeto conta só no município-sede; "
              "projetos que se estendem por mais de um município não são divididos.")
NOTA_SEEG = ("O SEEG estima as emissões do município inteiro, não só da agricultura familiar. "
             "SEEG 13, GWP-AR5. Nas emissões brutas, a soma dos municípios fica um pouco abaixo do total "
             "estadual, porque uma parte das emissões de energia e de processos industriais não é atribuída "
             "a município.")
NOTA_SEEG_1990 = (" O SEEG só estima a mudança de uso da terra e florestas a partir de 1990; de 1970 a 1989 "
                  "as células desse indicador levam o sinal ... (não disponível).")
NOTA_DIN = ("Todos os estabelecimentos agropecuários (AF e não AF). A soma municipal de 2006 não fecha com a "
            "tabela estadual: 112.987 contra 112.978 estabelecimentos e 48,69 contra 47,81 milhões de ha.")

# campos: id, dim, rotulo, rotulo_curto, unidade, fmt, origem, fonte, arquivo, variavel, num, den, fator,
#         agregacao, soma, kpi, sentido, nota
I = []


def ind(**k):
    base = dict(den=None, fator=1.0, soma=0, kpi=0, sentido=0, nota="", serie=0, download=1)
    base.update(k)
    I.append(base)


ARQ_SIDRA = "sidra_raw_status_long.csv"
# ---- estrutura (9)
ind(id="estab_af", dim="estrutura", rotulo="Estabelecimentos da agricultura familiar",
    rotulo_curto="Estabelecimentos da AF", unidade="estabelecimentos", fmt="int", origem="censo2017",
    fonte=T6878, arquivo=ARQ_SIDRA, variavel="n_estab_AF_total", num="n_estab_AF_total",
    agregacao="soma", soma=1, kpi=1, nota=NOTA_AF)
ind(id="pct_estab_af", dim="estrutura", rotulo="Participação da AF no número de estabelecimentos",
    rotulo_curto="% da AF nos estabelecimentos", unidade="% dos estabelecimentos agropecuários", fmt="pct1",
    origem="censo2017", fonte=T6878, arquivo=ARQ_SIDRA + "; C_base_dinamica_clusters_corrigido.csv",
    variavel="100 * n_estab_AF_total / n_estab_total_2017", num="n_estab_AF_total", den="n_estab_total_2017",
    fator=100, agregacao="razao", kpi=1, nota="Denominador: todos os estabelecimentos agropecuários do município.")
ind(id="area_af", dim="estrutura", rotulo="Área dos estabelecimentos da agricultura familiar",
    rotulo_curto="Área da AF", unidade="hectares", fmt="int", origem="censo2017", fonte=T6878,
    arquivo=ARQ_SIDRA, variavel="area_AF_total", num="area_AF_total", agregacao="soma", soma=1, nota=NOTA_AF)
ind(id="pct_area_af", dim="estrutura", rotulo="Participação da AF na área dos estabelecimentos",
    rotulo_curto="% da AF na área", unidade="% da área dos estabelecimentos agropecuários", fmt="pct1",
    origem="censo2017", fonte=T6878, arquivo=ARQ_SIDRA + "; C_base_dinamica_clusters_corrigido.csv",
    variavel="100 * area_AF_total / area_total_ha_2017", num="area_AF_total", den="area_total_ha_2017",
    fator=100, agregacao="razao", nota="Denominador: área de todos os estabelecimentos agropecuários do município.")
ind(id="area_media_af", dim="estrutura", rotulo="Área média dos estabelecimentos da AF",
    rotulo_curto="Área média da AF", unidade="hectares por estabelecimento", fmt="dec1", origem="censo2017",
    fonte=T6878, arquivo=ARQ_SIDRA, variavel="area_AF_total / n_estab_AF_total", num="area_AF_total",
    den="n_estab_AF_total", agregacao="razao", kpi=1,
    nota="Nos agregados, área total dividida pelo total de estabelecimentos (média ponderada).")
ind(id="pessoal_af", dim="estrutura", rotulo="Pessoal ocupado na agricultura familiar",
    rotulo_curto="Pessoal ocupado na AF", unidade="pessoas", fmt="int", origem="censo2017",
    fonte="IBGE, Censo Agropecuário 2017, SIDRA, tabela 6884", arquivo=ARQ_SIDRA, variavel="pocupestagro",
    num="pocupestagro", agregacao="soma", soma=1, nota=NOTA_AF)
ind(id="valor_prod_af", dim="estrutura", rotulo="Valor da produção da agricultura familiar",
    rotulo_curto="Valor da produção da AF", unidade="R$ mil (valores de 2017)", fmt="brl_mil",
    origem="censo2017", fonte="IBGE, Censo Agropecuário 2017, SIDRA, tabela 6898", arquivo=ARQ_SIDRA,
    variavel="prodestagro_val", num="prodestagro_val", agregacao="soma", soma=1, kpi=1,
    nota="Valor da produção em reais correntes de 2017.")
ind(id="valor_prod_estab_af", dim="estrutura", rotulo="Valor da produção por estabelecimento da AF",
    rotulo_curto="Valor da produção por estabelecimento", unidade="R$ por estabelecimento (valores de 2017)",
    fmt="brl", origem="censo2017", fonte="IBGE, Censo Agropecuário 2017, SIDRA, tabelas 6898 e 6878",
    arquivo=ARQ_SIDRA, variavel="1000 * prodestagro_val / n_estab_AF_total", num="prodestagro_val",
    den="n_estab_AF_total", fator=1000, agregacao="razao",
    nota="Valor da produção (R$ mil convertidos em R$) dividido por todos os estabelecimentos da AF.")
ind(id="pct_valor_animal_af", dim="estrutura", rotulo="Participação da produção animal no valor da produção da AF",
    rotulo_curto="% animal no valor da produção", unidade="% do valor da produção da AF", fmt="pct1",
    origem="censo2017", fonte="IBGE, Censo Agropecuário 2017, SIDRA, tabela 6898", arquivo=ARQ_SIDRA,
    variavel="100 * valprodanimal / prodestagro_val", num="valprodanimal", den="prodestagro_val", fator=100,
    agregacao="razao")
# ---- tecnologia, assistência e crédito (8)
for id_, v, tab, rot, curto, sent, nota in [
    ("pct_trator_af", "estagrotrat", "6873", "Estabelecimentos da AF com trator", "% com trator", 0, ""),
    ("pct_plantio_direto_af", "estagroplantdir", "6855", "Estabelecimentos da AF com plantio direto na palha",
     "% com plantio direto", 0, ""),
    ("pct_irrigacao_af", "estagroirri", "6857", "Estabelecimentos da AF com irrigação", "% com irrigação", 0,
     "Araguainha não tem linha na resposta da API do SIDRA para esta variável (sem registro). O IBGE não "
     "publicou sinal para essa célula; o site a mostra como ... (não disponível), nunca como zero."),
    ("pct_energia_af", "estagrorechidri", "6778", "Estabelecimentos da AF com energia elétrica",
     "% com energia elétrica", 1, "Variável estagrorechidri: existência de energia elétrica (tabela 6778)."),
]:
    ind(id=id_, dim="tecnologia", rotulo=rot, rotulo_curto=curto, unidade="% dos estabelecimentos da AF",
        fmt="pct1", origem="censo2017", fonte=f"IBGE, Censo Agropecuário 2017, SIDRA, tabelas {tab} e 6878",
        arquivo=ARQ_SIDRA, variavel=f"100 * {v} / n_estab_AF_total", num=v, den="n_estab_AF_total", fator=100,
        agregacao="razao", sentido=sent, nota=nota)
ind(id="pct_orientacao_af", dim="tecnologia", rotulo="Estabelecimentos da AF que recebem orientação técnica",
    rotulo_curto="% com orientação técnica", unidade="% dos estabelecimentos da AF", fmt="pct1",
    origem="censo2017", fonte="IBGE, Censo Agropecuário 2017, SIDRA, tabela 6780",
    arquivo="orientacao_tecnica_AF_MT.csv", variavel="100 * ot_recebe / ot_total", num="ot_recebe",
    den="ot_total", fator=100, agregacao="razao", sentido=1)
for id_, v, rot, curto, tab in [
    ("pct_financiamento_af", "financ_total_n_estab", "Estabelecimentos da AF que obtiveram financiamento",
     "% com financiamento", "6895"),
    ("pct_pronaf_af", "financ_pronaf_n_estab", "Estabelecimentos da AF com financiamento do Pronaf",
     "% com Pronaf", "6895"),
]:
    ind(id=id_, dim="tecnologia", rotulo=rot, rotulo_curto=curto, unidade="% dos estabelecimentos da AF",
        fmt="pct1", origem="censo2017", fonte=f"IBGE, Censo Agropecuário 2017, SIDRA, tabelas {tab} e 6780",
        arquivo="financiamento_AF_MT.csv", variavel=f"100 * {v} / ot_total", num=v, den="ot_total", fator=100,
        agregacao="razao", sentido=1, nota="Denominador: total de estabelecimentos da AF da tabela 6780.")
ind(id="pct_dap_af", dim="tecnologia", rotulo="Estabelecimentos da AF com DAP",
    rotulo_curto="% com DAP", unidade="% dos estabelecimentos da AF", fmt="pct1", origem="censo2017",
    fonte="IBGE, Censo Agropecuário 2017, SIDRA, tabela 6771", arquivo="financiamento_AF_MT.csv",
    variavel="100 * dap_sim_n_estab / dap_total_n_estab", num="dap_sim_n_estab", den="dap_total_n_estab",
    fator=100, agregacao="razao", sentido=1, nota="DAP: Declaração de Aptidão ao Pronaf.")
# ---- produção e alimentos (4)
ind(id="pct_consumo_proprio_af", dim="alimentos",
    rotulo="Estabelecimentos da AF que produzem principalmente para consumo próprio",
    rotulo_curto="% com produção para consumo próprio", unidade="% dos estabelecimentos da AF", fmt="pct1",
    origem="censo2017", fonte="IBGE, Censo Agropecuário 2017, SIDRA, tabela 6773",
    arquivo="finalidade_producao_AF_MT.csv",
    variavel="100 * finalid_consumo_proprio_n_estab / finalid_total_n_estab",
    num="finalid_consumo_proprio_n_estab", den="finalid_total_n_estab", fator=100, agregacao="razao",
    nota="Finalidade principal declarada: consumo próprio e de pessoas com laços de parentesco com o produtor.")
for id_, v, arq, tab, rot, curto in [
    ("pct_leite_af", "leite_n_estab", "leite_AF_MT.csv", "6912", "Estabelecimentos da AF que produzem leite de vaca",
     "% que produz leite"),
    ("pct_mandioca_af", "mandioca_n_estab", "alimentos_basicos_AF_MT.csv", "6957",
     "Estabelecimentos da AF que produzem mandioca", "% que produz mandioca"),
]:
    ind(id=id_, dim="alimentos", rotulo=rot, rotulo_curto=curto, unidade="% dos estabelecimentos da AF",
        fmt="pct1", origem="censo2017", fonte=f"IBGE, Censo Agropecuário 2017, SIDRA, tabelas {tab} e 6780",
        arquivo=arq, variavel=f"100 * {v} / ot_total", num=v, den="ot_total", fator=100, agregacao="razao",
        nota="Denominador: total de estabelecimentos da AF da tabela 6780.")
ind(id="pct_horticultura_af", dim="alimentos",
    rotulo="Estabelecimentos da AF no grupo de atividade horticultura e floricultura",
    rotulo_curto="% em horticultura e floricultura", unidade="% dos estabelecimentos da AF", fmt="pct1",
    origem="censo2017", fonte=T6878, arquivo=ARQ_SIDRA, variavel="100 * estagrohort / n_estab_AF_total",
    num="estagrohort", den="n_estab_AF_total", fator=100, agregacao="razao",
    nota="Atividade econômica principal do estabelecimento.")
# ---- posse e reforma agrária (7)
ROT46504 = "concessionário(a) ou assentado(a) aguardando titulação definitiva (Censo 2017)"
ind(id="estab_af_46504", dim="posse", rotulo="Estabelecimentos da AF de " + ROT46504,
    rotulo_curto="Estab. da AF em 46504", unidade="estabelecimentos", fmt="int", origem="censo2017",
    fonte=T6878, arquivo=ARQ_SIDRA, variavel="n_estab_AF_assent", num="n_estab_AF_assent", agregacao="soma",
    soma=1, nota=NOTA_46504)
ind(id="pct_estab_46504", dim="posse", rotulo="Estabelecimentos da AF de " + ROT46504 + ", em % da AF",
    rotulo_curto="% da AF em 46504", unidade="% dos estabelecimentos da AF", fmt="pct1", origem="censo2017",
    fonte=T6878, arquivo=ARQ_SIDRA, variavel="100 * n_estab_AF_assent / n_estab_AF_total",
    num="n_estab_AF_assent", den="n_estab_AF_total", fator=100, agregacao="razao", kpi=1, nota=NOTA_46504)
ind(id="pct_area_46504", dim="posse", rotulo="Área da AF de " + ROT46504 + ", em % da área da AF",
    rotulo_curto="% da área da AF em 46504", unidade="% da área dos estabelecimentos da AF", fmt="pct1",
    origem="censo2017", fonte=T6878, arquivo=ARQ_SIDRA, variavel="100 * area_AF_assent / area_AF_total",
    num="area_AF_assent", den="area_AF_total", fator=100, agregacao="razao",
    nota=NOTA_46504 + " A área tem X (sigilo) em muitos municípios; os agregados usam só os municípios sem X.")
ind(id="pct_estab_prop_af", dim="posse", rotulo="Estabelecimentos da AF de produtor proprietário(a)",
    rotulo_curto="% da AF de proprietário(a)", unidade="% dos estabelecimentos da AF", fmt="pct1",
    origem="censo2017", fonte="IBGE, Censo Agropecuário 2017, SIDRA, tabelas 6753 e 6878", arquivo=ARQ_SIDRA,
    variavel="100 * estagroprodprop / n_estab_AF_total", num="estagroprodprop", den="n_estab_AF_total",
    fator=100, agregacao="razao", nota="Condição do produtor em relação às terras: proprietário(a).")
ind(id="n_pa", dim="posse", rotulo="Projetos de assentamento com sede no município",
    rotulo_curto="Projetos de assentamento", unidade="projetos", fmt="int", origem="sipra",
    fonte="INCRA/SIPRA, Relatório 0227 (posição de 03/06/2025)", arquivo="incra_pa_por_municipio.csv",
    variavel="n_projetos", num="sipra_n_projetos", agregacao="soma", soma=1, nota=NOTA_SIPRA)
ind(id="fam_pa", dim="posse", rotulo="Famílias assentadas nos projetos com sede no município",
    rotulo_curto="Famílias assentadas", unidade="famílias", fmt="int", origem="sipra",
    fonte="INCRA/SIPRA, Relatório 0227 (posição de 03/06/2025)", arquivo="incra_pa_por_municipio.csv",
    variavel="familias_assentadas", num="sipra_familias_assentadas", agregacao="soma", soma=1, kpi=1,
    nota=NOTA_SIPRA)
ind(id="area_pa", dim="posse", rotulo="Área dos projetos de assentamento com sede no município",
    rotulo_curto="Área dos projetos", unidade="hectares", fmt="int", origem="sipra",
    fonte="INCRA/SIPRA, Relatório 0227 (posição de 03/06/2025)", arquivo="incra_pa_por_municipio.csv",
    variavel="area_ha", num="sipra_area_ha", agregacao="soma", soma=1,
    nota=NOTA_SIPRA + " Área declarada no SIPRA, não a área dos polígonos.")
# ---- clima, SEEG 13 (4): séries 1970-2024
# Totais absolutos: sentido 0 (contexto). Comparar o total de um município com a mediana do bioma
# puniria ou premiaria o município só pelo tamanho.
for id_, rot, curto, sent, kpi in [
    ("seeg_emissao_bruta", "Emissões brutas de gases de efeito estufa", "Emissões brutas", 0, 1),
    ("seeg_agropecuaria", "Emissões da agropecuária", "Emissões da agropecuária", 0, 0),
    ("seeg_mut", "Emissões de mudança de uso da terra e florestas", "Emissões de mudança de uso da terra", 0, 0),
    ("seeg_remocoes", "Remoções de gases de efeito estufa (mudança de uso da terra e florestas)", "Remoções", 0, 0),
]:
    nota = NOTA_SEEG
    if id_ == "seeg_mut":
        nota = NOTA_SEEG + NOTA_SEEG_1990
    if id_ == "seeg_remocoes":
        nota = ("O SEEG registra as remoções com sinal negativo; aqui aparecem em valor absoluto. " + NOTA_SEEG
                + NOTA_SEEG_1990)
    if id_ == "seeg_emissao_bruta":
        nota = "Soma dos cinco setores do SEEG (agropecuária, energia, mudança de uso da terra, processos " \
               "industriais e resíduos), sem as remoções. " + NOTA_SEEG
    ind(id=id_, dim="clima", rotulo=rot, rotulo_curto=curto, unidade="mil tCO2e (GWP-AR5)", fmt="dec1",
        origem="seeg", fonte="SEEG 13, Observatório do Clima, dados municipais (GWP-AR5)",
        arquivo="seeg_mt_municipal_wide.parquet", variavel=id_, num=id_, agregacao="soma", soma=1, kpi=kpi,
        sentido=sent, serie=1, download=0, nota=nota)
# ---- dinâmica 2006-2017 (2)
ind(id="var_estab_0617", dim="dinamica", rotulo="Variação do número de estabelecimentos agropecuários, 2006–2017",
    rotulo_curto="Variação dos estabelecimentos 2006–2017", unidade="% (2017 sobre 2006)", fmt="pct1",
    origem="censo2006_2017", fonte="IBGE, Censos Agropecuários 2006 e 2017",
    arquivo="C_base_dinamica_clusters_corrigido.csv", variavel="pct_var_n_estab", num="n_estab_total_2017",
    den="n_estab_total_2006", fator=100, agregacao="variacao", kpi=1, nota=NOTA_DIN)
ind(id="var_area_0617", dim="dinamica", rotulo="Variação da área dos estabelecimentos agropecuários, 2006–2017",
    rotulo_curto="Variação da área 2006–2017", unidade="% (2017 sobre 2006)", fmt="pct1",
    origem="censo2006_2017", fonte="IBGE, Censos Agropecuários 2006 e 2017",
    arquivo="C_base_dinamica_clusters_corrigido.csv", variavel="pct_var_area", num="area_total_ha_2017",
    den="area_total_ha_2006", fator=100, agregacao="variacao", nota=NOTA_DIN)

checar(len(I) == 34, f"34 indicadores (definidos: {len(I)})")
checar(len({x["id"] for x in I}) == 34, "ids de indicador únicos")

# Linha "Cálculo" das páginas de indicador, em palavras. Os nomes das variáveis (códigos do SIDRA e do
# projeto) ficam só nos dicionários dos downloads.
ROT_VAR = {
    "n_estab_AF_total": "estabelecimentos da AF",
    "area_AF_total": "área dos estabelecimentos da AF",
    "n_estab_AF_assent": "estabelecimentos da AF na categoria 46504",
    "area_AF_assent": "área da AF na categoria 46504",
    "pocupestagro": "pessoal ocupado na AF",
    "prodestagro_val": "valor da produção da AF (R$ mil)",
    "valprodanimal": "valor da produção animal da AF",
    "estagrotrat": "estabelecimentos da AF com trator",
    "estagroplantdir": "estabelecimentos da AF com plantio direto na palha",
    "estagroirri": "estabelecimentos da AF com irrigação",
    "estagrorechidri": "estabelecimentos da AF com energia elétrica",
    "estagrohort": "estabelecimentos da AF no grupo horticultura e floricultura",
    "estagroprodprop": "estabelecimentos da AF de produtor proprietário(a)",
    "ot_total": "estabelecimentos da AF (total da tabela 6780)",
    "ot_recebe": "estabelecimentos da AF que recebem orientação técnica",
    "financ_total_n_estab": "estabelecimentos da AF que obtiveram financiamento",
    "financ_pronaf_n_estab": "estabelecimentos da AF com financiamento do Pronaf",
    "dap_total_n_estab": "estabelecimentos da AF (total da tabela 6771)",
    "dap_sim_n_estab": "estabelecimentos da AF com DAP",
    "finalid_total_n_estab": "estabelecimentos da AF (total da tabela 6773)",
    "finalid_consumo_proprio_n_estab": "estabelecimentos da AF com produção principalmente para consumo próprio",
    "leite_n_estab": "estabelecimentos da AF que produziram leite de vaca",
    "mandioca_n_estab": "estabelecimentos da AF que produziram mandioca",
    "n_estab_total_2006": "estabelecimentos agropecuários (todos) em 2006",
    "n_estab_total_2017": "estabelecimentos agropecuários (todos) em 2017",
    "area_total_ha_2006": "área dos estabelecimentos agropecuários (todos) em 2006",
    "area_total_ha_2017": "área dos estabelecimentos agropecuários (todos) em 2017",
    "sipra_n_projetos": "projetos de assentamento com sede no município",
    "sipra_familias_assentadas": "famílias assentadas nos projetos com sede no município",
    "sipra_area_ha": "área declarada dos projetos com sede no município",
}
CALC_SEEG = {
    "seeg_emissao_bruta": "soma das emissões dos cinco setores do SEEG (agropecuária, energia, mudança de uso da "
                          "terra e florestas, processos industriais e resíduos), sem as remoções",
    "seeg_agropecuaria": "emissões do setor agropecuária no SEEG",
    "seeg_mut": "emissões do setor mudança de uso da terra e florestas no SEEG",
    "seeg_remocoes": "remoções do setor mudança de uso da terra e florestas no SEEG, em valor absoluto",
}


def calculo(x: dict) -> str:
    if x["origem"] == "seeg":
        t = CALC_SEEG[x["id"]]
    elif x["agregacao"] == "variacao":
        t = f"({ROT_VAR[x['num']]} ÷ {ROT_VAR[x['den']]} − 1) × 100"
    elif x["den"] and x["fator"] == 1000:
        t = f"{ROT_VAR[x['num']]} × 1.000 ÷ {ROT_VAR[x['den']]}"
    elif x["den"]:
        t = f"{ROT_VAR[x['num']]} ÷ {ROT_VAR[x['den']]}" + (" × 100" if x["fator"] == 100 else "")
    else:
        t = ROT_VAR[x["num"]]
    return t[0].upper() + t[1:]


for x in I:
    x["calculo"] = calculo(x)

# ---------------------------------------------------------------------------
# 4. Valores em formato longo (id_municipio, indicador, ano, valor, sinal)
# ---------------------------------------------------------------------------
print("\n4. Valores em formato longo")


def razao(num: pd.DataFrame, den: pd.DataFrame, fator: float) -> pd.DataFrame:
    """Razão célula a célula com propagação do sinal: X > ... > – (numerador zero absoluto)."""
    out = pd.DataFrame(index=num.index)
    s = np.where((num["sinal"] == "X") | (den["sinal"] == "X"), "X",
        np.where((num["sinal"] == "...") | (den["sinal"] == "...") | (den["sinal"] == "–") | (den["valor"] == 0),
                 "...",
        np.where(num["sinal"] == "–", "–", "valor")))
    out["sinal"] = s
    out["valor"] = np.where(out["sinal"] == "valor", fator * num["valor"] / den["valor"], np.nan)
    return out


ANO = {"censo2017": 2017, "sipra": 2025, "censo2006_2017": 2017}
partes = []
for x in I:
    if x["origem"] == "seeg":
        continue
    if x["agregacao"] == "variacao":
        c = razao(CEL[x["num"]], CEL[x["den"]], 1.0)
        c.loc[c["sinal"] == "valor", "valor"] = 100 * (c.loc[c["sinal"] == "valor", "valor"] - 1)
    elif x["den"]:
        c = razao(CEL[x["num"]], CEL[x["den"]], x["fator"])
    else:
        c = CEL[x["num"]].copy()
    partes.append(pd.DataFrame({"id_municipio": c.index, "indicador": x["id"], "ano": ANO[x["origem"]],
                                "valor": c["valor"].values, "sinal": c["sinal"].values}))

# SEEG 13 municipal: soma das duas grafias de Santo Antônio de Leverger; sem o código 5100000 (não alocado)
print("  SEEG 13")
w = pd.read_parquet(PROC / "seeg_mt_municipal_wide.parquet")
SET = {"emissao_agropecuaria": "Agropecuária", "emissao_energia": "Energia",
       "emissao_mudanca_de_uso_da_terra_e_floresta": "Mudança de Uso da Terra e Floresta",
       "emissao_processos_industriais": "Processos Industriais", "emissao_resíduos": "Resíduos"}
nao_alocado = w[w["cod_ibge"] == 5100000]
w = w[w["cod_ibge"] != 5100000]
cols = list(SET) + ["remocao_mudanca_de_uso_da_terra_e_floresta"]
g = w.groupby(["cod_ibge", "ano"])[cols].sum(min_count=1).reset_index()
checar(set(g["cod_ibge"]) == set(IDS), "SEEG: os mesmos 141 municípios")
checar(len(g) == 141 * 55 and g["ano"].min() == 1970 and g["ano"].max() == 2024, "SEEG: 141 x 55 anos (1970-2024)")
checar(g[cols].notna().all().all(), "SEEG: sem célula vazia depois de juntar as grafias")
seeg = pd.DataFrame({"id_municipio": g["cod_ibge"].astype(int), "ano": g["ano"].astype(int)})
seeg["seeg_emissao_bruta"] = g[list(SET)].sum(axis=1) * 1000          # MtCO2e -> mil tCO2e
seeg["seeg_agropecuaria"] = g["emissao_agropecuaria"] * 1000
seeg["seeg_mut"] = g["emissao_mudanca_de_uso_da_terra_e_floresta"] * 1000
seeg["seeg_remocoes"] = g["remocao_mudanca_de_uso_da_terra_e_floresta"].abs() * 1000
# Mudança de uso da terra e remoções: o SEEG só as estima a partir de 1990. Antes disso a fonte traz 0,
# que não é zero medido: essas células saem com o sinal ... (não disponível) e sem número.
ANTES_1990 = seeg["ano"] < 1990
for v in ["seeg_mut", "seeg_remocoes"]:
    checar((seeg.loc[ANTES_1990, v] == 0).all(), f"SEEG: {v} é 0 em todos os municípios de 1970 a 1989 (setor não estimado)")
for v in ["seeg_emissao_bruta", "seeg_agropecuaria", "seeg_mut", "seeg_remocoes"]:
    nd = ANTES_1990 if v in ("seeg_mut", "seeg_remocoes") else pd.Series(False, index=seeg.index)
    partes.append(pd.DataFrame({"id_municipio": seeg["id_municipio"], "indicador": v, "ano": seeg["ano"],
                                "valor": seeg[v].where(~nd), "sinal": np.where(nd, "...", "valor")}))
setor = ler_csv(PROC / "seeg_mt_setor_serie.csv")
tot24 = setor.loc[setor["year"] == 2024, "emissao_MtCO2e"].sum()
mun24 = g.loc[g["ano"] == 2024, list(SET)].sum().sum()
na24 = nao_alocado.loc[nao_alocado["ano"] == 2024, list(SET)].sum(min_count=1).sum()
checar(round(tot24, 1) == 231.2, f"SEEG 2024: total de MT = {tot24:.3f} MtCO2e (231,2)")
checar(abs(mun24 + na24 - tot24) < 0.01,
       f"SEEG 2024: municípios ({mun24:.3f}) + não alocado ({na24:.3f}) = total estadual ({tot24:.3f})")

val = pd.concat(partes, ignore_index=True)
val["id_municipio"] = val["id_municipio"].astype(int)
val["ano"] = val["ano"].astype(int)
val = val.sort_values(["indicador", "ano", "id_municipio"]).reset_index(drop=True)

# ---- checagens dos sinais
nX = int((val["sinal"] == "X").sum())
checar(set(val["sinal"]) <= {"valor", "X", "–", "..."}, f"sinais no vocabulário (valor, X, –, ...): {sorted(set(val['sinal']))}")
checar(val.loc[val["sinal"] != "valor", "valor"].isna().all(), f"nenhum X, – ou ... com número ({nX} células X)")
checar(val.loc[val["sinal"] == "valor", "valor"].notna().all(), "nenhuma célula 'valor' vazia")
checar(val["sinal"].notna().all() and (val["sinal"] != "").all(), "nenhuma célula vazia sem sinal")
cont = val.groupby(["indicador", "ano"]).size()
checar((cont == 141).all(), "141 municípios em cada indicador e ano")
# X na fonte nunca vira 0: toda célula X de numerador ou denominador sai X
for x in I:
    if x["origem"] == "seeg":
        continue
    fonte_x = set(CEL[x["num"]].index[CEL[x["num"]]["sinal"] == "X"])
    if x["den"]:
        fonte_x |= set(CEL[x["den"]].index[CEL[x["den"]]["sinal"] == "X"])
    saida = val[(val["indicador"] == x["id"])].set_index("id_municipio")
    if fonte_x and not (saida.loc[sorted(fonte_x), "sinal"] == "X").all():
        ERROS.append(f"X da fonte não propagado em {x['id']}")
checar(not any(e.startswith("X da fonte") for e in ERROS), "todo X da fonte continua X no indicador")
checar(not ((val["sinal"] == "X") & (val["valor"] == 0)).any(), "nenhum X convertido em 0")

# ---- conferência com as derivadas do M1 (mesmas células)
def confere(arquivo, coluna, id_):
    d = ler_csv(EXT / arquivo).set_index("cod_ibge")[coluna]
    s = val[(val["indicador"] == id_) & (val["sinal"] == "valor")].set_index("id_municipio")["valor"]
    dif = (s - d.reindex(s.index)).abs().max()
    checar(bool(dif < 1e-6), f"{id_} confere com {coluna} do M1 (maior diferença {dif:.2e})")


confere("orientacao_tecnica_AF_MT.csv", "pct_recebe_ot", "pct_orientacao_af")
confere("financiamento_AF_MT.csv", "pct_estab_AF_obtiveram_financ", "pct_financiamento_af")
confere("financiamento_AF_MT.csv", "pct_estab_AF_financ_pronaf", "pct_pronaf_af")
confere("finalidade_producao_AF_MT.csv", "pct_estab_consumo_proprio", "pct_consumo_proprio_af")
confere("leite_AF_MT.csv", "pct_estab_AF_produzem_leite", "pct_leite_af")
confere("alimentos_basicos_AF_MT.csv", "pct_estab_AF_com_mandioca", "pct_mandioca_af")
pa = sid[sid["variavel"] == "pct_estab_assentados"].set_index(sid.loc[sid["variavel"] == "pct_estab_assentados", "cod_ibge"].astype(int))
s = val[(val["indicador"] == "pct_estab_46504") & (val["sinal"] == "valor")].set_index("id_municipio")["valor"]
dif = (s - pd.to_numeric(pa["valor_num"].reindex(s.index), errors="coerce")).abs().max()
checar(bool(dif < 1e-9), "pct_estab_46504 confere com pct_estab_assentados do M1")
for id_, col in [("var_estab_0617", "pct_var_n_estab"), ("var_area_0617", "pct_var_area")]:
    s = val[(val["indicador"] == id_)].set_index("id_municipio")["valor"]
    dif = (s - din.set_index("id_municipio")[col].reindex(s.index)).abs().max()
    checar(bool(dif < 1e-6), f"{id_} confere com {col} da base da dinâmica")

def com_sinal(valor: pd.Series, sinal: pd.Series) -> pd.Series:
    """Texto da célula do número: o número (ponto decimal) ou, sem número, o próprio sinal (X, – ou ...)."""
    return pd.Series(np.where(sinal == "valor", valor.map(fmt_num), sinal), index=valor.index)


val_txt = val.copy()
val_txt["valor"] = com_sinal(val["valor"], val["sinal"])
checar(not (val_txt["valor"] == "").any(), "valores.csv: nenhuma célula do número vazia (sem número, vai o sinal)")
gravar(val_txt, DS / "valores.csv")
print(f"  valores.csv: {len(val)} linhas; sinais: {val['sinal'].value_counts().to_dict()}")

# Nota de valor atípico na área média da AF (o maior valor muito acima do segundo)
am = val[(val["indicador"] == "area_media_af") & (val["sinal"] == "valor")].sort_values("valor", ascending=False)
if am["valor"].iloc[0] > 5 * am["valor"].iloc[1]:
    i1 = int(am["id_municipio"].iloc[0])
    nome1 = mun.loc[mun.id_municipio == i1, "municipio"].item()
    br_ = lambda v, d: f"{v:,.{d}f}".replace(",", "§").replace(".", ",").replace("§", ".")
    x_am = next(x for x in I if x["id"] == "area_media_af")
    x_am["nota"] += (f" Valor atípico: {nome1} tem {br_(am['valor'].iloc[0], 1)} ha por estabelecimento "
                     f"({br_(CEL['area_AF_total'].loc[i1, 'valor'], 0)} ha em {br_(CEL['n_estab_AF_total'].loc[i1, 'valor'], 0)} "
                     f"estabelecimentos da AF), muito acima do segundo maior valor ({br_(am['valor'].iloc[1], 1)} ha). "
                     "É o valor publicado pelo IBGE (SIDRA, tabela 6878).")
    print(f"  nota de valor atípico em area_media_af: {nome1}")

# ---------------------------------------------------------------------------
# 5. indicadores.csv
# ---------------------------------------------------------------------------
TEMA = {"estrutura": "Estrutura da agricultura familiar", "tecnologia": "Tecnologia, assistência e crédito",
        "alimentos": "Produção e alimentos", "posse": "Posse e reforma agrária", "clima": "Clima (SEEG 13)",
        "dinamica": "Dinâmica 2006–2017"}
ano_ref = val.groupby("indicador")["ano"].max().to_dict()
ind_df = pd.DataFrame([{
    "id": x["id"], "ordem": k + 1, "dim": x["dim"], "tema": TEMA[x["dim"]], "rotulo": x["rotulo"],
    "rotulo_curto": x["rotulo_curto"], "unidade": x["unidade"], "fmt": x["fmt"], "ano_ref": ano_ref[x["id"]],
    "ano_col": "ano", "kpi": x["kpi"], "serie": x["serie"], "soma": x["soma"], "sentido": x["sentido"],
    "agregacao": x["agregacao"], "numerador": x["num"], "denominador": x["den"] or "",
    "fator": x["fator"] if x["den"] else "", "origem": x["origem"], "fonte": x["fonte"], "arquivo": x["arquivo"],
    "variavel": x["variavel"], "calculo": x["calculo"], "nota": x["nota"], "download": x["download"]}
    for k, x in enumerate(I)])
ind_df["fator"] = ind_df["fator"].map(lambda v: fmt_num(v) if v != "" else "")
gravar(ind_df, DS / "indicadores.csv")
checar(sorted(ind_df["dim"].unique()) == sorted(TEMA), "dims por extenso: " + ", ".join(TEMA))
print("  indicadores.csv por tema:", ind_df["dim"].value_counts().to_dict())

# ---------------------------------------------------------------------------
# 6. Agregados por bioma, por tipo do M1 e MT
# ---------------------------------------------------------------------------
print("\n6. Agregados")
GRUPOS = [("mt", "MT", IDS)]
GRUPOS += [("bioma", b, mun.loc[mun.bioma == b, "id_municipio"].tolist()) for b in ["Amazônia", "Cerrado", "Pantanal"]]
GRUPOS += [("tipo", t_, mun.loc[mun.tipo_m1 == t_, "id_municipio"].tolist()) for t_ in ROTULO_M1]


def calc(c: pd.DataFrame) -> pd.Series:
    """Valor para cálculo: – (zero absoluto) conta como 0; X e ... ficam fora."""
    return c["valor"].where(c["sinal"] == "valor", np.where(c["sinal"] == "–", 0.0, np.nan))


linhas = []
for x in I:
    vi = val[val["indicador"] == x["id"]]
    for ano, va in vi.groupby("ano"):
        va = va.set_index("id_municipio")
        for recorte, grupo, ids in GRUPOS:
            u = va.loc[ids]
            uc = calc(u)
            r = {"indicador": x["id"], "ano": ano, "recorte": recorte, "grupo": grupo, "regra": x["agregacao"],
                 "n_mun": len(ids), "n_valor": int((u["sinal"] == "valor").sum()),
                 "n_x": int((u["sinal"] == "X").sum()), "n_zero": int((u["sinal"] == "–").sum()),
                 "n_nd": int((u["sinal"] == "...").sum()), "mediana": float(np.nanmedian(uc)) if uc.notna().any() else np.nan}
            if x["agregacao"] == "soma":
                r["valor"] = float(uc.sum()) if uc.notna().any() else np.nan
                r["n_usados"] = int(uc.notna().sum())
            else:
                if x["origem"] == "seeg":
                    raise SystemExit("regra inesperada")
                nm, dn = CEL[x["num"]].loc[ids], CEL[x["den"]].loc[ids]
                a, b = calc(nm), calc(dn)
                ok = a.notna() & b.notna()
                r["n_usados"] = int(ok.sum())
                if ok.any() and b[ok].sum() > 0:
                    q = a[ok].sum() / b[ok].sum()
                    r["valor"] = 100 * (q - 1) if x["agregacao"] == "variacao" else x["fator"] * q
                else:
                    r["valor"] = np.nan
            linhas.append(r)
agr = pd.DataFrame(linhas)[["indicador", "ano", "recorte", "grupo", "regra", "valor", "mediana", "n_mun",
                            "n_usados", "n_valor", "n_x", "n_zero", "n_nd"]]
# Grupos em que todos os municípios têm ... (SEEG: mudança de uso da terra e remoções antes de 1990) não
# têm agregado: a linha sai, em vez de ficar com a célula vazia.
so_nd = agr["valor"].isna() & (agr["n_nd"] == agr["n_mun"])
print(f"  {int(so_nd.sum())} linhas de agregado sem nenhum valor (todos os municípios com ...) ficam fora")
agr = agr[~so_nd].reset_index(drop=True)
checar(agr["valor"].notna().all() and agr["mediana"].notna().all(), "agregados: todo grupo com valor e mediana")
gravar(agr, DS / "agregados.csv")


def ag(id_, grupo, ano=None):
    a = agr[(agr.indicador == id_) & (agr.grupo == grupo)]
    if ano is not None:
        a = a[a.ano == ano]
    return float(a["valor"].iloc[-1])


checar(ag("estab_af", "MT") == 81635, f"soma n_estab_AF_total = 81.635 (lida: {ag('estab_af', 'MT'):.0f})")
tot_estab = CEL["n_estab_total_2017"]["valor"].sum()
checar(tot_estab == 118679, f"118.679 estabelecimentos em 2017 (lidos: {tot_estab:.0f})")
area17 = CEL["area_total_ha_2017"]["valor"].sum()
checar(abs(area17 - 54922850) <= 1, f"área de 2017: soma municipal {fmt_num(area17)} ha contra 54.922.850 ha da "
       "tabela estadual (diferença de arredondamento)")
checar(ag("n_pa", "MT") == 575, f"575 projetos de assentamento (lidos: {ag('n_pa', 'MT'):.0f})")
checar(ag("fam_pa", "MT") == 85653, f"85.653 famílias assentadas (lidas: {ag('fam_pa', 'MT'):.0f})")
checar(abs(ag("seeg_emissao_bruta", "MT", 2024) / 1000 - mun24) < 1e-9, "SEEG 2024 nos agregados = soma municipal")
# conferência com a Tabela 3 do M1 (perfis dos tipos)
t3 = ler_csv(RES / "tipologia_k5_tabela3_final.csv", dtype={"tipo": str})
for _, r in t3.iterrows():
    gname = "MT" if r["tipo"] == "MT" else f"T{int(float(r['tipo']))}"
    for id_, col in [("pct_estab_46504", "pct_estab_46504_ponderada"),
                     ("pct_area_46504", "pct_area_46504_ponderada_sem_sigilo"),
                     ("area_media_af", "area_media_AF_ha_por_estab_ponderada")]:
        checar(abs(ag(id_, gname) - float(r[col])) < 0.01, f"Tabela 3 do M1, {gname}: {id_} = {float(r[col]):.2f}")
    checar(abs(ag("estab_af", gname) - float(r["soma_estab_AF"])) < 0.5, f"Tabela 3 do M1, {gname}: soma de estab. AF")

# ---------------------------------------------------------------------------
# 7. Totais estaduais oficiais (para os números da página inicial)
# ---------------------------------------------------------------------------
print("\n7. Totais estaduais")
nf = ler_csv(RES / "NUMEROS_FINAIS.csv", dtype=str).set_index("id")
FONTE_N3 = "IBGE, Censo Agropecuário 2017, SIDRA (MT, nível estadual), tabelas 6878 e 6884"
tot = []


def t_(id_, rotulo, valor, unidade, ano, fonte):
    tot.append({"id": id_, "rotulo": rotulo, "valor": float(valor), "unidade": unidade, "ano": ano, "fonte": fonte})


for k, rot, un in [("TOT_TODOS_ESTAB", "Estabelecimentos agropecuários de MT", "estabelecimentos"),
                   ("TOT_AF_ESTAB", "Estabelecimentos da agricultura familiar em MT", "estabelecimentos"),
                   ("PCT_AF_ESTAB_MT", "Participação da AF nos estabelecimentos de MT", "%"),
                   ("TOT_TODOS_AREA", "Área dos estabelecimentos agropecuários de MT", "hectares"),
                   ("TOT_AF_AREA", "Área dos estabelecimentos da AF em MT", "hectares"),
                   ("PCT_AF_AREA_MT", "Participação da AF na área dos estabelecimentos de MT", "%"),
                   ("TOT_AF_PESSOAL", "Pessoal ocupado na AF em MT", "pessoas"),
                   ("AREA_MEDIA_AF_MT", "Área média dos estabelecimentos da AF em MT", "hectares por estabelecimento"),
                   ("TOT_46504_ESTAB", "Estabelecimentos da AF de " + ROT46504 + " em MT", "estabelecimentos"),
                   ("PCT_46504_ESTAB_MT", "Estabelecimentos da AF de " + ROT46504 + ", em % da AF de MT", "%"),
                   ("TOT_46504_AREA", "Área da AF de " + ROT46504 + " em MT", "hectares"),
                   ("PCT_46504_AREA_MT", "Área da AF de " + ROT46504 + ", em % da área da AF de MT", "%"),
                   ("TOT_TODOS_46504_ESTAB", "Estabelecimentos de " + ROT46504 + " em MT, AF e não AF", "estabelecimentos")]:
    t_(k.lower(), rot, nf.loc[k, "valor_bruto"], un, 2017, FONTE_N3)
import openpyxl  # noqa: E402

wb = openpyxl.load_workbook(PROC / "Tabelas_MT_Brasil_Censo2017.xlsx", data_only=True)
e = wb["1. Estrutura Geral"]; vb = wb["2. VBP"]; wi = wb["6. Assentamentos INCRA"]
checar(e["B4"].value == 118679 and e["C4"].value == 81635, "planilha estadual: 118.679 e 81.635 estabelecimentos")
t_("pct_af_estab_br", "Participação da AF nos estabelecimentos do Brasil", e["G4"].value, "%", 2017,
   "IBGE, Censo Agropecuário 2017")
t_("pessoal_total_mt", "Pessoal ocupado nos estabelecimentos agropecuários de MT", e["B7"].value, "pessoas", 2017,
   "IBGE, Censo Agropecuário 2017")
t_("vbp_total_mt", "Valor da produção dos estabelecimentos agropecuários de MT", vb["B4"].value, "R$ mil", 2017,
   "IBGE, Censo Agropecuário 2017")
t_("vbp_af_mt", "Valor da produção da AF em MT", vb["C4"].value, "R$ mil", 2017, "IBGE, Censo Agropecuário 2017")
t_("pct_af_vbp_mt", "Participação da AF no valor da produção de MT", vb["I4"].value, "%", 2017,
   "IBGE, Censo Agropecuário 2017")
t_("pct_af_vbp_lavperm_mt", "Participação da AF no valor da lavoura permanente de MT", vb["I8"].value, "%", 2017,
   "IBGE, Censo Agropecuário 2017")
t_("pct_af_vbp_hort_mt", "Participação da AF no valor da horticultura de MT", vb["I9"].value, "%", 2017,
   "IBGE, Censo Agropecuário 2017")
checar(wi["B3"].value == 575 and wi["B4"].value == 85653, "planilha estadual: 575 PAs e 85.653 famílias")
t_("n_pa_mt", "Projetos de assentamento do INCRA em MT", wi["B3"].value, "projetos", 2025,
   "INCRA/SIPRA, Relatório 0227 (posição de 03/06/2025)")
t_("fam_pa_mt", "Famílias assentadas nos projetos do INCRA em MT", wi["B4"].value, "famílias", 2025,
   "INCRA/SIPRA, Relatório 0227 (posição de 03/06/2025)")
t_("area_pa_mt", "Área dos projetos de assentamento do INCRA em MT", inc["area_ha"].sum(), "hectares", 2025,
   "INCRA/SIPRA, Relatório 0227 (posição de 03/06/2025)")
FONTE_SEEG = "SEEG 13, Observatório do Clima (GWP-AR5)"
t_("seeg_bruta_mt_2024", "Emissões brutas de GEE de MT", tot24, "MtCO2e", 2024, FONTE_SEEG)
for setor_nome, idk in [("Mudança de Uso da Terra e Floresta", "seeg_mut_mt_2024"), ("Agropecuária", "seeg_agro_mt_2024")]:
    v = setor.loc[(setor["year"] == 2024) & (setor["setor"] == setor_nome), "emissao_MtCO2e"].item()
    t_(idk, f"Emissões de MT: {setor_nome.lower()}", v, "MtCO2e", 2024, FONTE_SEEG)
tx = ler_csv(PROC / "prodes_mt_taxa_amazonia_legal.csv")
cons = tx[tx["status"] == "consolidada"]
ult = cons[cons["year"] == cons["year"].max()].iloc[0]
t_("prodes_taxa_mt", "Taxa de desmatamento de MT (PRODES Amazônia Legal, formações florestais)", ult["taxa_km2"],
   "km²", int(ult["year"]), "INPE/PRODES, TerraBrasilis (acesso em 19/10/2026; atualização do INPE em "
   + "/".join(reversed(str(ult["atualizacao_inpe"]).split("-"))) + ")")
tot_df = pd.DataFrame(tot)
gravar(tot_df, DS / "totais_mt.csv")

# Séries estaduais: SEEG por setor e PRODES oficial (sem os fatores de emissão, que não têm fonte primária)
s2 = setor.rename(columns={"year": "ano", "emissao_MtCO2e": "emissao_mtco2e"})
# Mudança de uso da terra antes de 1990: o SEEG não estima o setor (a fonte traz 0); sai com o sinal ...
nd_mut = (s2["setor"] == "Mudança de Uso da Terra e Floresta") & (s2["ano"] < 1990)
checar((s2.loc[nd_mut, "emissao_mtco2e"] == 0).all(), "SEEG estadual: mudança de uso da terra é 0 de 1970 a 1989 (não estimada)")
s2["sinal_emissao_mtco2e"] = np.where(nd_mut, "...", "valor")
s2["emissao_mtco2e"] = com_sinal(s2["emissao_mtco2e"], s2["sinal_emissao_mtco2e"])
gravar(s2[["ano", "setor", "emissao_mtco2e", "sinal_emissao_mtco2e"]], DS / "seeg_mt_setor.csv")
gravar(tx[["year", "taxa_km2", "status", "periodo_inicio", "periodo_fim", "fonte", "url", "data_acesso",
           "atualizacao_inpe", "versao_painel"]].rename(columns={"year": "ano"}), DS / "prodes_mt_taxa.csv")
pb = ler_csv(PROC / "prodes_mt_serie_bioma.csv")
pb["bioma"] = pb["bioma"].map(BIOMA_NOME)
gravar(pb[["year", "bioma", "desmat_km2", "status", "periodo_inicio", "periodo_fim", "n_anos", "fonte", "url",
           "data_acesso", "atualizacao_inpe", "versao_painel"]].rename(columns={"year": "ano"}), DS / "prodes_mt_bioma.csv")
checar(int(tx.loc[tx.year == 2019, "taxa_km2"].item()) == 1702, "PRODES oficial: taxa de MT em 2019 = 1.702 km²")

# Dinâmica 2006-2017 (para a página de resultados)
gravar(din.merge(mun[["id_municipio"]], on="id_municipio"), DS / "dinamica_2006_2017.csv")

# ---------------------------------------------------------------------------
# 8. Manuscrito 1: perfis dos tipos, fatores e figuras finais
# ---------------------------------------------------------------------------
print("\n8. Manuscrito 1")
t3p = t3.copy()
t3p["tipo"] = t3p["tipo"].map(lambda s: "MT" if s == "MT" else f"T{int(float(s))}")
t3p["rotulo_provisorio"] = t3p["tipo"].map(lambda s: ROTULO_M1.get(s, "Mato Grosso (141 municípios)"))
manter = ["tipo", "rotulo_provisorio", "n"] + [c for c in t3p.columns if c.startswith("F")] + [
    "pct_estab_46504_ponderada", "pct_estab_46504_mediana_municipal", "n_munis_com_estab_46504",
    "pct_area_46504_ponderada_sem_sigilo", "n_munis_sigilo_area_46504", "n_munis_sem_sigilo_area_46504",
    "area_media_AF_ha_por_estab_ponderada", "area_media_AF_ha_por_estab_mediana_municipal",
    "estab_AF_por_municipio_media", "estab_AF_por_municipio_mediana", "soma_estab_AF", "soma_estab_AF_46504",
    "soma_area_AF_ha", "bioma250_Amazonia", "bioma250_Cerrado", "bioma250_Pantanal",
    "jaccard_bootstrap_repeticoes", "jaccard_bootstrap_clusterboot_padrao"]
t3p = t3p[manter].rename(columns={"bioma250_Amazonia": "n_amazonia", "bioma250_Cerrado": "n_cerrado",
                                  "bioma250_Pantanal": "n_pantanal"})
gravar(t3p, DS / "m1_tipos_perfis.csv")
gravar(pd.DataFrame([
    ("F1", "Lavoura temporária mecanizada", "volume municipal de lavoura temporária mecanizada"),
    ("F2", "Porte agregado", "totais municipais da AF (área, pessoal, produção animal, estabelecimentos com trator)"),
    ("F3", "Horticultura e irrigação", "volume municipal de horticultura e irrigação"),
    ("F4", "Lavoura permanente", "dominado por poucos municípios; muito X na área"),
    ("F5", "Posse aguardando titulação (46504)", "estabelecimentos e pessoal na categoria 46504"),
], columns=["fator", "nome", "descricao"]), DS / "m1_fatores.csv")
# Só as figuras PNG usadas nas páginas (as demais ficariam publicadas sem legenda nem selo de rótulo provisório)
dest = REPO / "resultados" / "figuras" / "m1"
FIGS_PNG = ["fig6_censo_incra_final.png"]
for f in sorted(dest.glob("*")):
    if f.name not in FIGS_PNG:
        f.unlink()
        print(f"  removida a cópia sem uso resultados/figuras/m1/{f.name}")
for f in FIGS_PNG:
    shutil.copy2(FIG / f, dest / f)
checar(sorted(x.name for x in dest.glob("*")) == sorted(FIGS_PNG), f"figuras PNG do M1 usadas nas páginas: {', '.join(FIGS_PNG)}")

# ---------------------------------------------------------------------------
# 9. Áreas-piloto (só identificação; sem números de famílias ou área, sem polígonos)
# ---------------------------------------------------------------------------
pil = pd.DataFrame([
    {"slug": "vale-do-arinos", "piloto": "Vale do Arinos", "id_municipio": 5105101, "municipio_sede": "Juara",
     "bioma": "Amazônia", "modalidade": "Projeto de assentamento do INCRA (MT0641000), criado em 09/09/2003",
     "situacao_numeros": "números em conciliação", "reconhecimento_campo": "a confirmar",
     "homonimos": "PCA Arinos, também em Juara, é outro projeto."},
    {"slug": "quata-nsa-aparecida", "piloto": "Quatá e N. Sra. Aparecida", "id_municipio": 5105259,
     "municipio_sede": "Lucas do Rio Verde", "bioma": "Cerrado",
     "modalidade": "N. Sra. Aparecida: crédito fundiário (PNCF). Quatá: modalidade a confirmar",
     "situacao_numeros": "números em conciliação", "reconhecimento_campo": "a confirmar",
     "homonimos": "Há PAs N. Sra. Aparecida em Diamantino, Várzea Grande e Alta Floresta; não são este piloto."},
    {"slug": "lambari", "piloto": "Lambari", "id_municipio": 5106505, "municipio_sede": "Poconé",
     "bioma": "Pantanal", "modalidade": "Banco da Terra",
     "situacao_numeros": "números em conciliação", "reconhecimento_campo": "a confirmar",
     "homonimos": "A Fazenda Lambari, de Jaciara, é outra área."},
])
pil["bioma_fonte"] = "bioma do município-sede, IBGE 1:250 mil (2019)"
checar(all(mun.set_index("id_municipio").loc[pil.id_municipio, "bioma"].values == pil.bioma.values),
       "bioma dos pilotos = bioma do município-sede")
gravar(pil, DS / "pilotos.csv")

# ---------------------------------------------------------------------------
# 10. Fontes e licenças
# ---------------------------------------------------------------------------
# data_acesso: data da consulta ou do download; quando não há registro da consulta, a data do arquivo baixado
fl = pd.DataFrame([
    ("IBGE", "Censo Agropecuário 2017 (SIDRA, API de agregados v3)", "indicadores da AF, posse (categoria 46504)",
     "dados públicos; citar a fonte", "https://sidra.ibge.gov.br", "16/09/2026"),
    ("IBGE", "Censo Agropecuário 2006 (resultados municipais)", "dinâmica 2006–2017 (todos os estabelecimentos)",
     "dados públicos; citar a fonte", "https://sidra.ibge.gov.br", "fev/2026 (data do arquivo baixado)"),
    ("IBGE", "Biomas do Brasil, escala 1:250 mil (2019)", "bioma dominante de cada município",
     "dados públicos; citar a fonte", "https://www.ibge.gov.br/geociencias", "16/09/2026"),
    ("IBGE", "Malha Municipal 2022 (141 municípios de MT), simplificada para a web", "mapas do site e malha GeoJSON",
     "dados públicos; citar a fonte", "https://www.ibge.gov.br/geociencias", "mar/2026"),
    ("INCRA", "SIPRA, Relatório 0227 (posição de 03/06/2025)", "projetos, famílias e área por município-sede",
     "dados públicos; citar a fonte", "https://www.gov.br/incra", "16/09/2026"),
    ("Observatório do Clima", "SEEG 13, emissões e remoções municipais e estaduais (GWP-AR5)", "indicadores de clima",
     "licença a conferir; dados municipais fora dos downloads até a conferência", "https://seeg.eco.br",
     "abr/2026 (data do arquivo baixado)"),
    ("INPE", "PRODES, painel TerraBrasilis v3.5.10: taxa anual de MT e incremento anual por bioma",
     "desmatamento oficial de MT", "dados públicos; licença a conferir", "https://terrabrasilis.dpi.inpe.br", "19/10/2026"),
    ("INPE", "PRODES Amazônia, Cerrado e Pantanal, painel TerraBrasilis v3.5.10: incremento anual por município",
     "desmatamento por município (OE1) e por tipo do M1 (Artigo A refeito); fora dos downloads",
     "dados públicos; licença a conferir", "https://terrabrasilis.dpi.inpe.br", "19/10/2026"),
    ("MapBiomas", "Coleção de cobertura e uso da terra, estatísticas municipais", "previsto (OE1); ainda não usado",
     "CC BY 4.0 (a conferir)", "https://brasil.mapbiomas.org", "não se aplica (ainda não usado)"),
    ("Projeto RESA", "Manuscrito 1 (em preparação): tipologia municipal k = 5", "tipos dos municípios (rótulos provisórios)",
     "resultado do projeto; citar o projeto", "", HOJE),
], columns=["orgao", "produto", "uso_no_site", "licenca", "url", "data_acesso"])
gravar(fl, DS / "fontes_licencas.csv")

# ---------------------------------------------------------------------------
# 11. Malha GeoJSON com bioma e tipo
# ---------------------------------------------------------------------------
print("\n11. Malha")
gj_p = ARQ / "geo" / "mt_municipios.geojson"
gj = json.loads(gj_p.read_text(encoding="utf-8"))
m_idx = mun.set_index("id_municipio")
ids_geo = []
for f in gj["features"]:
    i = int(f["properties"]["id_municipio"])
    ids_geo.append(i)
    r = m_idx.loc[i]
    f["properties"] = {"id_municipio": i, "municipio": r["municipio"], "slug": r["slug"], "bioma": r["bioma"],
                       "tipo_m1": r["tipo_m1"], "rotulo_m1": r["rotulo_m1"], "rotulo_status": ROTULO_STATUS,
                       "sede_piloto": bool(r["sede_piloto"])}
checar(sorted(ids_geo) == sorted(IDS), "malha com os 141 municípios")
gj["name"] = "mt_municipios"
gj_p.write_text(json.dumps(gj, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
(ARQ / "geo" / "dicionarios").mkdir(parents=True, exist_ok=True)
gravar(pd.DataFrame([
    ("id_municipio", "Código IBGE do município (7 dígitos)", "", "IBGE"),
    ("municipio", "Nome do município", "", "IBGE"),
    ("slug", "Nome do município sem acento, usado no endereço do perfil no site", "", "Projeto RESA"),
    ("bioma", "Bioma dominante do município (maior área)", "", "IBGE, Biomas 1:250 mil (2019)"),
    ("tipo_m1", "Tipo municipal da AF no Manuscrito 1 (k = 5)", "", "Projeto RESA, Manuscrito 1 (em preparação)"),
    ("rotulo_m1", "Rótulo do tipo", "", "Projeto RESA, Manuscrito 1 (em preparação)"),
    ("rotulo_status", "Situação do rótulo: provisório, pendente de aprovação dos autores", "", "Projeto RESA"),
    ("sede_piloto", "Município-sede de uma das três áreas-piloto (true/false)", "", "Projeto RESA"),
    ("geometria", "Polígono do município, simplificado para a web (coordenadas com 3 casas decimais, WGS 84)", "graus",
     "IBGE, Malha Municipal 2022"),
], columns=["coluna", "descricao", "unidade", "fonte"]), ARQ / "geo" / "dicionarios" / "mt_municipios.csv")

# ---------------------------------------------------------------------------
# 12. Downloads com dicionário
# ---------------------------------------------------------------------------
print("\n12. Downloads")
DD = ARQ / "dados"
DIC = DD / "dicionarios"
id_cols = mun[["id_municipio", "municipio", "bioma", "tipo_m1", "rotulo_m1"]].copy()
id_cols["rotulo_status"] = ROTULO_STATUS
dic_id = [("id_municipio", "Código IBGE do município (7 dígitos)", "", "IBGE"),
          ("municipio", "Nome do município", "", "IBGE"),
          ("bioma", "Bioma dominante do município (maior área)", "", "IBGE, Biomas 1:250 mil (2019)"),
          ("tipo_m1", "Tipo municipal da AF no Manuscrito 1 (k = 5)", "", "Projeto RESA, Manuscrito 1"),
          ("rotulo_m1", "Rótulo do tipo (provisório: ver rotulo_status)", "", "Projeto RESA, Manuscrito 1"),
          ("rotulo_status", "Situação do rótulo: provisório, pendente de aprovação dos autores", "", "Projeto RESA")]
NOTA_SINAL = "Coluna sinal_*: valor, X (sigilo do IBGE), – (zero absoluto) ou ... (não disponível). " \
             "Quando não há número, a coluna do número traz o próprio sinal (X, – ou ...), como nas tabelas do " \
             "IBGE; essas células nunca são zero."
# Nomes das colunas nos downloads: a categoria 46504 vai pelo código, não por "assentados"
NOME_DL = {"n_estab_AF_assent": "n_estab_AF_46504", "area_AF_assent": "area_AF_46504", "pocup_assent": "pocup_46504"}


def dicionario(nome, linhas):
    gravar(pd.DataFrame(linhas, columns=["coluna", "descricao", "unidade", "fonte"]), DIC / nome)


# 12a. indicadores (sem os do SEEG, cuja licença está em conferência)
largo = id_cols.copy()
dic = list(dic_id)
for x in I:
    if not x["download"]:
        continue
    v = val[(val["indicador"] == x["id"]) & (val["ano"] == ano_ref[x["id"]])].set_index("id_municipio")
    largo[x["id"]] = largo["id_municipio"].map(com_sinal(v["valor"], v["sinal"]))
    largo["sinal_" + x["id"]] = largo["id_municipio"].map(v["sinal"])
    dic.append((x["id"], x["rotulo"] + f" ({ano_ref[x['id']]})", x["unidade"], x["fonte"]))
    dic.append(("sinal_" + x["id"], "Sinal da célula de " + x["id"], "", NOTA_SINAL))
gravar(largo, DD / "resa_indicadores_municipios.csv")
dicionario("resa_indicadores_municipios.csv", dic)

# 12b. células do Censo 2017 da AF (contagens e áreas usadas nos indicadores)
VARS_DL = [("n_estab_AF_total", "Estabelecimentos da AF", "estabelecimentos", "6878"),
           ("area_AF_total", "Área dos estabelecimentos da AF", "hectares", "6878"),
           ("n_estab_AF_assent", "Estabelecimentos da AF de " + ROT46504, "estabelecimentos", "6878"),
           ("area_AF_assent", "Área da AF de " + ROT46504, "hectares", "6878"),
           ("pocupestagro", "Pessoal ocupado na AF", "pessoas", "6884"),
           ("pocup_assent", "Pessoal ocupado na AF de " + ROT46504, "pessoas", "6884"),
           ("prodestagro_val", "Valor da produção da AF", "R$ mil", "6898"),
           ("valprodanimal", "Valor da produção animal da AF", "R$ mil", "6898"),
           ("estagrotrat", "Estabelecimentos da AF com trator", "estabelecimentos", "6873"),
           ("estagroveic", "Estabelecimentos da AF com semeadeiras/plantadeiras", "estabelecimentos", "6873"),
           ("estagrocolh", "Estabelecimentos da AF com colheitadeiras", "estabelecimentos", "6873"),
           ("estagroplantdir", "Estabelecimentos da AF com plantio direto na palha", "estabelecimentos", "6855"),
           ("estagroirri", "Estabelecimentos da AF com irrigação", "estabelecimentos", "6857"),
           ("estagrorechidri", "Estabelecimentos da AF com energia elétrica", "estabelecimentos", "6778"),
           ("estagrohort", "Estabelecimentos da AF no grupo horticultura e floricultura", "estabelecimentos", "6878"),
           ("estagroprodprop", "Estabelecimentos da AF de produtor proprietário(a)", "estabelecimentos", "6753"),
           ("ot_total", "Estabelecimentos da AF (total da tabela de orientação técnica)", "estabelecimentos", "6780"),
           ("ot_recebe", "Estabelecimentos da AF que recebem orientação técnica", "estabelecimentos", "6780"),
           ("financ_total_n_estab", "Estabelecimentos da AF que obtiveram financiamento", "estabelecimentos", "6895"),
           ("financ_pronaf_n_estab", "Estabelecimentos da AF com financiamento do Pronaf", "estabelecimentos", "6895"),
           ("dap_total_n_estab", "Estabelecimentos da AF (total da tabela de DAP)", "estabelecimentos", "6771"),
           ("dap_sim_n_estab", "Estabelecimentos da AF com DAP", "estabelecimentos", "6771"),
           ("finalid_total_n_estab", "Estabelecimentos da AF (total da tabela de finalidade)", "estabelecimentos", "6773"),
           ("finalid_consumo_proprio_n_estab", "Estabelecimentos da AF com produção principalmente para consumo próprio", "estabelecimentos", "6773"),
           ("leite_n_estab", "Estabelecimentos da AF que produziram leite de vaca", "estabelecimentos", "6912"),
           ("mandioca_n_estab", "Estabelecimentos da AF que produziram mandioca", "estabelecimentos", "6957"),
           ("n_estab_total_2017", "Estabelecimentos agropecuários (todos)", "estabelecimentos", "Censo 2017"),
           ("area_total_ha_2017", "Área dos estabelecimentos agropecuários (todos)", "hectares", "Censo 2017")]
cz = mun[["id_municipio", "municipio"]].copy()
dic = dic_id[:2]
for v, rot, un, tab in VARS_DL:
    c = CEL[v]
    col = NOME_DL.get(v, v)
    cz[col] = cz["id_municipio"].map(com_sinal(c["valor"], c["sinal"]))
    cz["sinal_" + col] = cz["id_municipio"].map(c["sinal"])
    fonte = f"IBGE, Censo Agropecuário 2017, SIDRA, tabela {tab}" if tab.isdigit() else f"IBGE, {tab}"
    nota_v = NOTA_SINAL
    if v == "estagroirri":
        nota_v += " Araguainha: sem registro na API do SIDRA; o IBGE não publicou sinal, e a célula vai como ..."
    dic += [(col, rot + " (2017)", un, fonte), ("sinal_" + col, "Sinal da célula de " + col, "", nota_v)]
gravar(cz, DD / "resa_censo2017_af_municipios.csv")
dicionario("resa_censo2017_af_municipios.csv", dic)

# 12c. tipologia do M1
gravar(id_cols, DD / "resa_tipologia_m1_municipios.csv")
dicionario("resa_tipologia_m1_municipios.csv", dic_id)

# 12d. SIPRA por município-sede
sp = mun[["id_municipio", "municipio"]].merge(
    inc.rename(columns={"cod_ibge": "id_municipio"})[["id_municipio", "n_projetos", "familias_assentadas",
                                                      "capacidade_familias", "area_ha"]], on="id_municipio")
gravar(sp, DD / "resa_incra_sipra_municipios.csv")
dicionario("resa_incra_sipra_municipios.csv", dic_id[:2] + [
    ("n_projetos", "Projetos de assentamento com sede no município", "projetos", "INCRA/SIPRA, Relatório 0227 (03/06/2025)"),
    ("familias_assentadas", "Famílias assentadas", "famílias", "INCRA/SIPRA, Relatório 0227 (03/06/2025)"),
    ("capacidade_familias", "Capacidade de famílias dos projetos", "famílias", "INCRA/SIPRA, Relatório 0227 (03/06/2025)"),
    ("area_ha", "Área declarada dos projetos", "hectares", "INCRA/SIPRA, Relatório 0227 (03/06/2025)")])

# 12e. dinâmica 2006-2017
dz = mun[["id_municipio", "municipio"]].merge(din, on="id_municipio")
gravar(dz, DD / "resa_dinamica_2006_2017_municipios.csv")
dicionario("resa_dinamica_2006_2017_municipios.csv", dic_id[:2] + [
    ("n_estab_total_2006", "Estabelecimentos agropecuários (todos), 2006", "estabelecimentos", "IBGE, Censo Agropecuário 2006"),
    ("n_estab_total_2017", "Estabelecimentos agropecuários (todos), 2017", "estabelecimentos", "IBGE, Censo Agropecuário 2017"),
    ("area_total_ha_2006", "Área dos estabelecimentos (todos), 2006", "hectares", "IBGE, Censo Agropecuário 2006"),
    ("area_total_ha_2017", "Área dos estabelecimentos (todos), 2017", "hectares", "IBGE, Censo Agropecuário 2017"),
    ("pct_var_n_estab", "Variação do número de estabelecimentos, 2006–2017", "%", "cálculo do projeto"),
    ("pct_var_area", "Variação da área, 2006–2017", "%", "cálculo do projeto")])

gravar(fl, DD / "fontes_licencas.csv")
cat = []
for f in sorted(DD.glob("*.csv")):
    d = pd.read_csv(f, dtype=str)
    sem_colunas_proibidas(d, f.name)
    cat.append({"arquivo": f.name, "linhas": len(d), "colunas": d.shape[1], "kb": round(f.stat().st_size / 1024, 1),
                "dicionario": ("dicionarios/" + f.name) if (DIC / f.name).exists() else ""})
gravar(pd.DataFrame(cat), DD / "catalogo_downloads.csv")

# ---------------------------------------------------------------------------
# 13. Varredura final: nada de caminho local, e-mail, Drive ou colunas proibidas
# ---------------------------------------------------------------------------
print("\n13. Varredura dos arquivos gravados")
# padrões montados por partes, para que este arquivo não contenha os próprios termos
RUINS = ["C:" + "/Users", "C:" + "\\Users", "Meu " + "Drive", "@" + "unemat", "drive." + "google",
         "LS" + "EG", "Refi" + "nitiv", "Alli" + "ed Off" + "sets"]
achados = []
for p in list(DS.rglob("*.csv")) + list(ARQ.rglob("*.csv")) + [gj_p]:
    txt = p.read_text(encoding="utf-8")
    for r in RUINS:
        if r in txt:
            achados.append(f"{p.relative_to(REPO)}: {r}")
    if "__compl" in txt or ",chk_" in txt:
        achados.append(f"{p.relative_to(REPO)}: coluna proibida")
checar(not achados, "nenhum caminho local, e-mail, link do Drive ou base comercial" + (f": {achados}" if achados else ""))

print()
if ERROS:
    print(f"FALHOU: {len(ERROS)} checagem(ns).")
    for e_ in ERROS:
        print("  -", e_)
    sys.exit(1)
print("Concluído sem erros.")
