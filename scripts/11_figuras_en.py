# -*- coding: utf-8 -*-
"""
11_figuras_en.py - Observatório RESA-MT: versões em inglês de quatro figuras do Manuscrito 1

Grava, com os mesmos nomes de arquivo das versões em português:
  en/resultados/figuras/fig3_matriz_phi_final.svg
  en/resultados/figuras/figA4_criterios_k_final.svg
  en/resultados/figuras/figA5_validacao_incra_final.svg
  en/resultados/figuras/m1/fig6_censo_incra_final.png

A raiz do projeto vem da variável de ambiente RESA_FONTES ou do arquivo
config.local.toml (fora do controle de versão), com a linha:
  resa_fontes = "<raiz do projeto RESA>"

Rodar a partir da raiz do repositório (Git Bash):
  RESA_FONTES="<raiz do projeto RESA>" python -I scripts/11_figuras_en.py

Método: lê o texto de 41v5_figuras_rotulos.py e de 40_figuras.py (de onde ele reusa estilo e
formatação) sem alterá-los, aplica em memória as listas abaixo, cada troca tendo de casar
exatamente uma vez, e executa só as quatro figuras. É o mesmo método com que o M1 gerou a
versão v5 a partir do script anterior. Dados, contas e semente não mudam.
  ACERTOS_*    redirecionam a saída e tiram o que as quatro figuras não usam (limites dos biomas)
  NUMEROS_40   formato de número do inglês
  TEXTOS_41    português -> inglês, com os termos de i18n/GLOSSARIO_EN.md

Conferências; o script para com erro se alguma falhar:
  1. O gerador roda antes sem as traduções: o resultado tem de ser idêntico às figuras em
     português do site. Assim, o que muda na versão em inglês vem só das trocas.
  2. Texto a texto, os números das duas versões têm de ser iguais, na mesma ordem.
  3. Nenhuma palavra de português na versão em inglês (nomes próprios em PERMITIDOS).
  4. Nenhum texto fora da figura que não estivesse fora em português. Sobreposições de textos
     que não existiam em português são listadas para exame visual.
  5. Nada muda na pasta do M1 (nomes, tamanhos e datas de modificação). Além disso, uma guarda
     interrompe o script se o Python tentar gravar qualquer coisa na raiz das fontes.
"""

import sys

sys.dont_write_bytecode = True   # 00_config.py é carregado da raiz das fontes: nada de __pycache__ lá

import contextlib
import csv
import io
import os
import re
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


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
GERADOR = M1 / "01_Scripts" / "41v5_figuras_rotulos.py"
S40 = M1 / "01_Scripts" / "40_figuras.py"
DESTINO = REPO / "en" / "resultados" / "figuras"
PT_SITE = REPO / "resultados" / "figuras"

# nome da figura no gerador -> arquivo publicado, relativo a resultados/figuras/
ARQUIVOS = {"fig3_matriz_phi_final": "fig3_matriz_phi_final.svg",
            "fig6_censo_incra_final": "m1/fig6_censo_incra_final.png",
            "figA4_criterios_k_final": "figA4_criterios_k_final.svg",
            "figA5_validacao_incra_final": "figA5_validacao_incra_final.svg"}
FUNCOES = ["figura3", "figura6", "figuraA4", "figuraA5"]

# ---------------------------------------------------------------------------
# Guarda: nada de gravar na raiz das fontes (criar pasta que já existe é inócuo)
# ---------------------------------------------------------------------------
_RAIZ = os.path.normcase(os.path.abspath(FONTES)) + os.sep


def _guarda(evento, args):
    if evento == "open":
        alvos, flags = args[:1], args[2]
        if not isinstance(flags, int) or not flags & (os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC | os.O_APPEND):
            return
    elif evento in ("os.mkdir", "os.remove", "os.rmdir"):
        alvos = args[:1]
    elif evento == "os.rename":
        alvos = args[:2]
    else:
        return
    for a in alvos:
        if isinstance(a, (str, bytes, os.PathLike)):
            p = os.path.abspath(os.fsdecode(a))
            if os.path.normcase(p).startswith(_RAIZ) and not (evento == "os.mkdir" and os.path.isdir(p)):
                raise PermissionError(f"tentativa de gravar na raiz das fontes ({evento}): {os.path.basename(p)}")


sys.addaudithook(_guarda)


def retrato(pasta: Path) -> dict:
    r = {}
    for d, _, arqs in os.walk(pasta):
        for a in arqs:
            st = os.stat(os.path.join(d, a))
            r[os.path.relpath(os.path.join(d, a), pasta)] = (st.st_size, st.st_mtime_ns)
    return r


# ---------------------------------------------------------------------------
# Trocas no texto dos geradores
# ---------------------------------------------------------------------------
ACERTOS_40 = [
    ('CACHE.mkdir(parents=True, exist_ok=True)\n', ''),
]
ACERTOS_41 = [
    ('_arv = ast.parse(_S40.read_text(encoding="utf-8"))', '_arv = ast.parse(TEXTO_40)'),
    ('FIG = cfg.FIGURAS / "final_v5"\nFIG.mkdir(parents=True, exist_ok=True)\nLOG_PATH = FIG / "figuras_41v5_log.txt"\n'
     'CACHE41 = DAD / "_cache_41_figuras"\nCACHE41.mkdir(parents=True, exist_ok=True)\n', 'FIG = LOG_PATH = None\n'),
    ('LIM_BIOMAS, META_BIOMAS = carregar_biomas_250()', 'LIM_BIOMAS, META_BIOMAS = None, None'),
]
NUMEROS_40 = [
    ('s = f"{x:,.{nd}f}".replace(",", "X").replace(".", ",").replace("X", ".")', 's = f"{x:,.{nd}f}"'),
    ('return "n.d."', 'return "n/a"'),
]
TEXTOS_41 = [
    # Rótulos comuns
    (r'FAT_CURTO = {"F1": "mecanização", "F2": "porte agregado", "F3": "horticultura", "F4": "lavoura permanente", "F5": "posse"}',
     r'FAT_CURTO = {"F1": "mechanisation", "F2": "aggregate scale", "F3": "horticulture", "F4": "permanent crops", "F5": "tenure"}'),
    (r'FAT_COL = {"F1": "F1\nLavoura temp.\nmecanizada", "F2": "F2\nPorte\nagregado",',
     r'FAT_COL = {"F1": "F1\nMechanised\ntemp. crops", "F2": "F2\nAggregate\nscale",'),
    (r'"F3": "F3\nHorticultura\ne irrigação", "F4": "F4\nLavoura\npermanente",',
     r'"F3": "F3\nHorticulture\nand irrigation", "F4": "F4\nPermanent\ncrops",'),
    (r'           "F5": "F5\nPosse\naguardando\ntitulação\n(46504)"}',
     r'           "F5": "F5\nTenure\nawaiting\ntitle\n(46504)"}'),
    (r'ROT_CURTO = {1: "Baixo porte agregado", 2: "Posse aguardando titulação, sem especialização", 3: "Grande porte agregado",',
     r'ROT_CURTO = {1: "Low aggregate scale", 2: "Tenure awaiting title, unspecialised", 3: "High aggregate scale",'),
    (r'             4: "Mecanizado com posse aguardando titulação", 5: "Hortícola-irrigado"}',
     r'             4: "Mechanised with tenure awaiting title", 5: "Horticultural-irrigated"}'),
    (r'return "p < 0,001" if p < 0.001', r'return "p < 0.001" if p < 0.001'),

    # Figura 3
    (r'"Φ\n[IC 95% bootstrap iid]"', r'"Φ\n[95% iid bootstrap CI]"'),
    (r'"[IC 95% bootstrap em blocos, 18 RGI]"', r'"[95% block bootstrap CI, 18 RGIs]"'),
    (r'ylabs.append(f"posse × {FAT_CURTO[f]}")', r'ylabs.append(f"tenure × {FAT_CURTO[f]}")'),
    (r'ylabs.append("máx |Φ| posse ×\n(porte agregado ou mecanização)")',
     r'ylabs.append("max |Φ| tenure ×\n(aggregate scale or mechanisation)")'),
    (r'axb.set_xlabel("Φ e IC 95% bootstrap (2.000 reamostras por esquema)")',
     r'axb.set_xlabel("Φ and 95% bootstrap CI (2,000 resamples per scheme)")'),
    (r'[(-0.10, 0.20, "independência"), (0.20, 0.35, "independência\nparcial"), (0.35, 0.60, "reformulação")]',
     r'[(-0.10, 0.20, "independence"), (0.20, 0.35, "partial\nindependence"), (0.35, 0.60, "reformulation")]'),
    (r'label="oblimin, blocos (18 RGI)"', r'label="oblimin, blocks (18 RGIs)"'),
    (r'label="promax, blocos (18 RGI)"', r'label="promax, blocks (18 RGIs)"'),
    (r'"Fonte: IBGE, Censo Agropecuário 2017; PAF iterada (21 variáveis) com rotação oblimin (γ = 0) e promax (κ = 4); IC "',
     r'"Source: IBGE, 2017 Agricultural Census; iterated PAF (21 variables) with oblimin (γ = 0) and promax (κ = 4) rotation; "'),
    (r'"percentil de 2.000 reamostras bootstrap de municípios (iid)\ne de 2.000 reamostras das 18 Regiões Geográficas Imediatas (blocos). "',
     r'"percentile CI from 2,000 bootstrap resamples of municipalities (iid)\nand from 2,000 resamples of the 18 Immediate Geographic Regions (blocks). "'),
    (r'"Faixas da regra de decisão (limiares 0,20 e 0,35) aplicáveis ao máx |Φ| entre posse e porte agregado ou mecanização;\nas linhas por par são "',
     r'"Decision rule bands (thresholds 0.20 and 0.35) apply to the max |Φ| between tenure and aggregate scale or mechanisation;\nthe lines for each pair are "'),
    (r'"descritivas.", fontsize=5.5', r'"descriptive.", fontsize=5.5'),

    # Figura 6
    (r'ROT_CL = ["0", "> 0 a 5", "> 5 a 10", "> 10 a 25", "> 25 a 50", "> 50 a 100", "> 100"]',
     r'ROT_CL = ["0", "> 0 to 5", "> 5 to 10", "> 10 to 25", "> 25 to 50", "> 50 to 100", "> 100"]'),
    (r'"Estabelecimentos AF na categoria 46504 (Censo 2017)\npor 100 estabelecimentos AF"',
     r'"Family farms in category 46504 (2017 Census)\nper 100 family farms"'),
    (r'"Beneficiários INCRA (assentados e titulados, homologados\naté 30/09/2017) por 100 estabelecimentos AF"',
     r'"INCRA beneficiaries (settlers and titled beneficiaries, approved\nup to 30 September 2017) per 100 family farms"'),
    (r'title="Por 100 estabelecimentos AF (número de municípios em a; b)"',
     r'title="Per 100 family farms (number of municipalities in a; b)"'),
    (r'label=f"Beneficiários ≥ 50 e 46504 < 5 por 100 estab. AF\n({len(regraA)} municípios; contorno com halo branco)"',
     r'label=f"Beneficiaries ≥ 50 and 46504 < 5 per 100 family farms\n({len(regraA)} municipalities; outline with white halo)"'),
    (r'label=f"Maioria das famílias em projetos criados até 1995 ({len(antigos)} municípios; em b)"',
     r'label=f"Most families in projects created up to 1995 ({len(antigos)} municipalities; in b)"'),
    (r'title="Marcas"', r'title="Map symbols"'),
    (r'} estabelecimentos 46504 e {num(mt.REF_por100AF_ponderado, 1)} beneficiários por 100 "',
     r'} family farms in category 46504 and {num(mt.REF_por100AF_ponderado, 1)} beneficiaries per 100 "'),
    (r'f"estab. AF (cobertura 46504/beneficiários = {num(mt.cobertura_46504AF_sobre_REF, 3)}).\nρ de Spearman municipal entre a e b = "',
     r'''f"family farms (46504/beneficiaries coverage = {num(mt.cobertura_46504AF_sobre_REF, 3)}).\nMunicipal Spearman's ρ between a and b = "'''),
    (r'({p_fmt(s_pct.p_dutilleul)} com o t modificado de Dutilleul et al., 1993).\n"',
     r'({p_fmt(s_pct.p_dutilleul)} with the modified t-test of Dutilleul et al., 1993).\n"'),
    (r'({int(t3.n_municipios)} municípios): {num(t3.pct_estab_46504_ponderado, 2)} e "',
     r'({int(t3.n_municipios)} municipalities): {num(t3.pct_estab_46504_ponderado, 2)} and "'),
    (r'} por 100 estab. AF; {num(t3.pct_REF_do_MT, 1)}% dos beneficiários do estado; cobertura "',
     r'''} per 100 family farms; {num(t3.pct_REF_do_MT, 1)}% of the state's beneficiaries; coverage "'''),
    # o ano médio é escrito sem separador de milhar: em inglês, o separador a tirar é a vírgula
    (r''';\nano médio de criação dos projetos {num(float(t3.ano_criacao_medio_pond_familias), 1).replace('.', '')}; "''',
     r''';\nmean year of project creation {num(float(t3.ano_criacao_medio_pond_familias), 1).replace(',', '')}; "'''),
    (r'{num(t3.pct_familias_projetos_ate1995, 1)}% das famílias em projetos criados até 1995.\n"',
     r'{num(t3.pct_familias_projetos_ate1995, 1)}% of families in projects created up to 1995.\n"'),
    (r'f"Municípios contornados por tipo: "', r'f"Outlined municipalities by type: "'),
    (r'"Fonte: IBGE, Censo Agropecuário 2017 (tabela 6878, API v3); INCRA/SIPRA (Relatório 0227 e relação de beneficiários "',
     r'"Source: IBGE, 2017 Agricultural Census (table 6878, API v3); INCRA/SIPRA (Report 0227 and SR-13 list of "'),
    (r'"da SR-13), beneficiários alocados pela área dos polígonos do Acervo Fundiário;\nmalha municipal IBGE 2022. Classes iguais nos "',
     r'"beneficiaries), with beneficiaries allocated by the area of the Acervo Fundiário polygons;\nIBGE 2022 municipal boundaries. Same classes in "'),
    (r'"dois painéis (mesma unidade: por 100 estabelecimentos AF). Projeção cônica equivalente de Albers (SIRGAS 2000)."',
     r'"both panels (same unit: per 100 family farms). Albers equal-area conic projection (SIRGAS 2000)."'),

    # Figura A4
    (r'"Silhueta média (maior é melhor)"', r'"Mean silhouette (higher is better)"'),
    (r'"Calinski-Harabasz (maior é melhor)"', r'"Calinski-Harabasz (higher is better)"'),
    (r'"Davies-Bouldin (menor é melhor)"', r'"Davies-Bouldin (lower is better)"'),
    (r'f"empate com k = 4\n(Δ = {num(s5 - s4, 4)})"', r'f"tie with k = 4\n(Δ = {num(s5 - s4, 4)})"'),
    (r'f"regra de 1 EP: k = {k_gap}"', r'f"1-SE rule: k = {k_gap}"'),
    (r'"Estatística gap ± $s_k$ (B = 500)"', r'"Gap statistic ± $s_k$ (B = 500)"'),
    (r'label="média, com repetições"', r'label="mean, with repetitions"'),
    (r'label="média, convenção padrão"', r'label="mean, standard convention"'),
    (r'label="mínimo por tipo, com repetições"', r'label="minimum per type, with repetitions"'),
    (r'label="mínimo por tipo, convenção padrão"', r'label="minimum per type, standard convention"'),
    (r'"Jaccard bootstrap (200 reamostras)"', r'"Bootstrap Jaccard (200 resamples)"'),
    (r'label=f"k escolhido ({k_regra}): maior silhueta\nentre k = 3 e 6, todos os grupos ≥ 3"',
     r'label=f"chosen k ({k_regra}): highest silhouette\nbetween k = 3 and 6, all groups ≥ 3"'),
    (r'title="Painel e e faixa cinza"', r'title="Panel e and grey band"'),
    (r'"Linhas de referência em e: 0,60 e 0,75\n(faixas usuais de estabilidade)."',
     r'"Reference lines in e: 0.60 and 0.75\n(conventional stability bands)."'),
    (r'"Fonte: IBGE, Censo Agropecuário 2017; k-médias (50 inicializações) sobre escores de Bartlett PAF-oblimin winsorizados; "',
     r'"Source: IBGE, 2017 Agricultural Census; k-means (50 initialisations) on winsorised PAF-oblimin Bartlett scores; "'),
    (r'"todos os k de 3 a 8 são viáveis."', r'"all k from 3 to 8 are feasible."'),

    # Figura A5
    (r'"% estab. AF na categoria 46504\n(concessionário/assentado sem título definitivo)"',
     r'"% of family farms in category 46504\n(grantee or settler awaiting a definitive title)"'),
    (r'"Escore F5 – posse aguardando titulação\n(Bartlett)"', r'"F5 score – tenure awaiting title\n(Bartlett)"'),
    (r'"% estab. AF 46504 + proprietários com\ntitulação via reforma agrária (medida combinada)"',
     r'"% of family farms in 46504 + owners titled\nthrough agrarian reform (combined measure)"'),
    (r'ax.set_xlabel("Beneficiários INCRA por 100 estab. AF (escala symlog)")',
     r'ax.set_xlabel("INCRA beneficiaries per 100 family farms (symlog scale)")'),
    (r'(("todos_141", "todos"), ("REF_ge100", "com ≥ 100 beneficiários"))',
     r'(("todos_141", "all"), ("REF_ge100", "with ≥ 100 beneficiaries"))'),
    (r'f"   {p_fmt(s.p_ingenuo)} (teste usual); {p_fmt(s.p_dutilleul)} com correção espacial "',
     r'f"   {p_fmt(s.p_ingenuo)} (standard test); {p_fmt(s.p_dutilleul)} with spatial correction "'),
    (r'f"(n efetivo = {num(s.ESS_dutilleul, 0)})"', r'f"(effective n = {num(s.ESS_dutilleul, 0)})"'),
    (r'''f"{', '.join(nomes[:-1])} e {nomes[-1]} ({'/'.join(tipos_sel)}): {num(sel.fam_incra_ref.min(), 0)} a "''',
     r'''f"{', '.join(nomes[:-1])} and {nomes[-1]} ({'/'.join(tipos_sel)}): {num(sel.fam_incra_ref.min(), 0)} to "'''),
    (r'} beneficiários e menos de 1% na categoria 46504", 21))', r'} beneficiaries and less than 1% in category 46504", 21))'),
    (r'bbox_to_anchor=(0.0, 1.10), title="Tipo (k-médias, k = 5)"', r'bbox_to_anchor=(0.0, 1.10), title="Type (k-means, k = 5)"'),
    (r'"Cada ponto é um município (n = 141). Beneficiários: situação\nAssentado ou Titulado, homologados até 30/09/2017, "',
     r'"Each point is a municipality (n = 141). Beneficiaries with status\nSettler or Titled, approved up to 30 September 2017, "'),
    (r'"alocados\npela área dos polígonos dos projetos. IC 95% por bootstrap\nde pares (2.000 réplicas)."',
     r'"allocated\nby the area of the project polygons. 95% CI from pairs\nbootstrap (2,000 replicates)."'),
    (r'"Fonte: IBGE, Censo Agropecuário 2017 (tabelas 6878 e 6774, API v3); INCRA/SIPRA (Relatório 0227 e relação de beneficiários da SR-13); "',
     r'"Source: IBGE, 2017 Agricultural Census (tables 6878 and 6774, API v3); INCRA/SIPRA (Report 0227 and SR-13 list of beneficiaries); "'),
    (r'"teste t modificado de\nDutilleul et al. (1993)."', r'"modified t-test of\nDutilleul et al. (1993)."'),
]


def aplicar(texto: str, trocas: list, arquivo: str) -> str:
    for de, para in trocas:
        n = texto.count(de)
        if n != 1:
            sys.exit(f"ERRO: a troca casou {n} vezes em {arquivo}: {de[:100]}")
        texto = texto.replace(de, para)
    return texto


# ---------------------------------------------------------------------------
# Execução do gerador
# ---------------------------------------------------------------------------
def gerar(ingles: bool, destino: Path) -> dict:
    """Executa as quatro figuras e devolve {figura: [(texto, caixa do texto, caixa da figura)]}."""
    t40 = aplicar(S40.read_text(encoding="utf-8"), ACERTOS_40, S40.name)
    t41 = aplicar(GERADOR.read_text(encoding="utf-8"), ACERTOS_41, GERADOR.name)
    if ingles:
        t40 = aplicar(t40, NUMEROS_40, S40.name)
        t41 = aplicar(t41, TEXTOS_41, GERADOR.name)
    if t41.count("# Execucao\n") != 1:
        sys.exit("ERRO: marcador '# Execucao' não encontrado no gerador.")
    ns = {"__name__": "gerador_m1", "__file__": str(GERADOR), "TEXTO_40": t40}
    with contextlib.redirect_stdout(io.StringIO()):
        exec(compile(t41[:t41.index("# Execucao\n")], str(GERADOR), "exec"), ns)  # noqa: S102
    from matplotlib.text import Text
    textos, caixas = {}, {}

    def salvar(fig, nome):
        fig.canvas.draw()
        r = fig.canvas.get_renderer()
        # rótulos de eixo dos mapas (eixos desligados) existem, mas não são desenhados
        ocultos = {id(x) for ax in fig.axes if not ax.axison for x in ax.get_xticklabels() + ax.get_yticklabels()}
        textos[nome] = [(t.get_text(), Text.get_window_extent(t, r).frozen()) for t in fig.findobj(Text)
                        if t.get_visible() and t.get_text().strip() and id(t) not in ocultos]
        caixas[nome] = fig.bbox.frozen()
        alvo = destino / ARQUIVOS[nome]
        alvo.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(alvo, dpi=300, facecolor=ns["SURF"], metadata={"Date": None} if alvo.suffix == ".svg" else {})
        ns["plt"].close(fig)

    ns["salvar"] = salvar
    with contextlib.redirect_stdout(io.StringIO()):
        for f in FUNCOES:
            ns[f]()
    if sorted(textos) != sorted(ARQUIVOS):
        sys.exit(f"ERRO: figuras geradas: {sorted(textos)}")
    return {nome: [(s, c, caixas[nome]) for s, c in textos[nome]] for nome in textos}


# ---------------------------------------------------------------------------
# Conferências
# ---------------------------------------------------------------------------
MESES = {m: i for i, m in enumerate(("January", "February", "March", "April", "May", "June", "July", "August", "September",
                                     "October", "November", "December"), start=1)}
RX_NUM_PT = re.compile(r"(?:(?<![\w.,])-)?(?:\d{1,3}(?:\.\d{3})+(?:,\d+)?|\d+,\d+|\d+)")
RX_NUM_EN = re.compile(r"(?:(?<![\w.,])-)?(?:\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+\.\d+|\d+)")


def numeros(s: str, ingles: bool) -> list:
    """Números de um texto, na ordem, em forma comum. Datas viram aaaammdd; T1, F5 e k = 5 também contam."""
    s = s.replace("−", "-")
    if ingles:
        s = re.sub(rf"\b(\d{{1,2}}) ({'|'.join(MESES)}) (\d{{4}})\b", lambda m: f" {m[3]}{MESES[m[2]]:02d}{int(m[1]):02d} ", s)
        return [x.replace(",", "") for x in RX_NUM_EN.findall(s)]
    s = re.sub(r"\b(\d{2})/(\d{2})/(\d{4})\b", lambda m: f" {m[3]}{m[2]}{m[1]} ", s)
    return [x.replace(".", "").replace(",", ".") for x in RX_NUM_PT.findall(s)]


RX_PT = re.compile(r"[áàâãéêíóôõúç]|\b(não|nao|são|município|municípios|municipio|municipios|estabelecimento|estabelecimentos|estab|"
                   r"agricultura|familiar|para|pela|pelo|pelos|pelas|uma|com|que|nas|nos|aos|dos|das|por|fonte|tabela|tabelas|"
                   r"posse|reforma|agrária|assentado|assentados|titulado|titulados|beneficiários|área|ano|tipo|tipos|até|entre|sobre|"
                   r"cada|maior|menor|sem|ou|faixa|faixas|silhueta|média|mínimo|reamostras|blocos|lavoura|porte|agregado|escala|"
                   r"cobertura|malha|painel|painéis|teste|regra|linhas|marcas)\b", re.I)
# Trechos que ficam em português, cada um com o motivo
PERMITIDOS = ["Acervo Fundiário",   # nome próprio da base do INCRA
              ]


def sobras_pt(texto: str, nomes_mun: list) -> list:
    for n in PERMITIDOS + nomes_mun:
        texto = texto.replace(n, " ")
    return [m.group(0) for m in RX_PT.finditer(texto)]


def parou(erros: list, titulo: str) -> None:
    if erros:
        print(f"ERRO: {titulo}:")
        for e in erros:
            print(f"  - {e}")
        sys.exit(1)


def fora(T: list) -> set:
    """Índices dos textos que saem da figura."""
    return {i for i, (_, c, f) in enumerate(T) if c.x0 < f.x0 - 0.5 or c.x1 > f.x1 + 0.5 or c.y0 < f.y0 - 0.5 or c.y1 > f.y1 + 0.5}


def cruzam(T: list) -> set:
    """Pares de índices de textos cujas caixas se sobrepõem."""
    return {(i, j) for i in range(len(T)) for j in range(i + 1, len(T)) if T[i][1].overlaps(T[j][1])}


def principal() -> None:
    antes = retrato(M1)
    print(f"Pasta do M1: {len(antes)} arquivos no retrato inicial")

    with tempfile.TemporaryDirectory() as tmp:
        print("1. Gerador sem as traduções, contra as figuras em português do site")
        PT = gerar(False, Path(tmp))
        erros = []
        for arq in ARQUIVOS.values():
            if (Path(tmp) / arq).read_bytes() != (PT_SITE / arq).read_bytes():
                erros.append(f"{arq}: o gerador sem traduções não reproduz o arquivo do site")
            else:
                print(f"  idêntico: resultados/figuras/{arq}")
        parou(erros, "as figuras em português não foram reproduzidas (mudou o gerador, a versão do matplotlib ou a figura do site?)")

    print("2. Figuras em inglês")
    EN = gerar(True, DESTINO)
    for arq in ARQUIVOS.values():
        print(f"  gravada en/resultados/figuras/{arq} ({(DESTINO / arq).stat().st_size // 1024} kB)")

    print("3. Números, texto a texto")
    erros = []
    for nome in ARQUIVOS:
        if len(PT[nome]) != len(EN[nome]):
            erros.append(f"{nome}: {len(PT[nome])} textos em português e {len(EN[nome])} em inglês")
            continue
        total = 0
        for (sa, _, _), (sb, _, _) in zip(PT[nome], EN[nome]):
            na, nb = numeros(sa, False), numeros(sb, True)
            total += len(na)
            if na != nb:
                erros.append(f"{nome}: {sa!r} {na} x {sb!r} {nb}")
        print(f"  {nome}: {len(EN[nome])} textos, {total} números")
    parou(erros, "números diferentes")

    print("4. Sobras de português")
    with open(REPO / "dados_site" / "municipios.csv", encoding="utf-8", newline="") as f:
        nomes_mun = sorted((r["municipio"] for r in csv.DictReader(f)), key=len, reverse=True)
    erros = []
    for nome in ARQUIVOS:
        for s, _, _ in EN[nome]:
            # a anotação da Figura A5 quebra os nomes de município em várias linhas
            ach = sobras_pt(" ".join(s.split()), nomes_mun)
            if ach:
                erros.append(f"{nome}: {s!r}: {ach}")
    parou(erros, "português na versão em inglês")
    print("  nenhuma")

    print("5. Textos fora da figura e sobreposições novas")
    erros = []
    for nome in ARQUIVOS:
        for i in sorted(fora(EN[nome]) - fora(PT[nome])):
            erros.append(f"{nome}: fora da figura: {EN[nome][i][0]!r}")
        for i, j in sorted(cruzam(EN[nome]) - cruzam(PT[nome])):
            print(f"  examinar em {nome}: {EN[nome][i][0]!r} sobre {EN[nome][j][0]!r}")
    parou(erros, "texto cortado")

    print("6. Pasta do M1")
    depois = retrato(M1)
    mudou = [k for k in set(antes) | set(depois) if antes.get(k) != depois.get(k)]
    parou(mudou, "a pasta do M1 mudou durante a execução")
    print(f"  sem mudança: {len(depois)} arquivos")
    print("OK")


principal()
