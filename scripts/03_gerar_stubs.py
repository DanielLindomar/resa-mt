# -*- coding: utf-8 -*-
"""
03_gerar_stubs.py - Observatório RESA-MT

Gera as páginas-esqueleto (stubs) dos municípios e dos indicadores a partir de
dados_site/, no mesmo padrão do DSIP-MT:

  municipios/_perfil.qmd     ->  municipios/<slug>.qmd    (perfis; os 141 ou só as 3 sedes)
  indicadores/_indicador.qmd ->  indicadores/<id>.qmd     (uma página por indicador de indicadores.csv)

Cada stub só tem o front matter, um bloco que define a chave (MUN_ID, inteiro,
ou IND_ID, texto) e {{< include _modelo.qmd >}}. O conteúdo fica no modelo.

Regras de segurança:
  - só escreve em municipios/ e indicadores/;
  - nunca toca index.qmd, arquivos que começam com "_" nem arquivos sem a marca
    de stub (a deste script ou a de scripts/03_gerar_paginas.py);
  - apaga os stubs com marca que não estão mais na lista (por exemplo, ao
    passar de --municipios todos para --municipios sedes).
Lê só dados_site/municipios.csv e dados_site/indicadores.csv.

Rodar a partir da raiz do repositório, depois dos scripts 01 e 02:
  python -I scripts/03_gerar_stubs.py                       # 141 perfis e 34 indicadores
  python -I scripts/03_gerar_stubs.py --municipios sedes    # perfis só das 3 sedes
Depois: quarto render municipios indicadores
"""

import argparse
import csv
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MARCA = "<!-- stub gerado por scripts/03_gerar_stubs.py; edite o modelo, não este arquivo -->"
MARCAS_CONHECIDAS = (
    MARCA,
    "<!-- stub gerado por scripts/03_gerar_paginas.py; edite o modelo, não este arquivo -->",
)


def ler(nome):
    with open(REPO / "dados_site" / nome, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def aspas(x: str) -> str:
    return x.replace("\\", "\\\\").replace('"', '\\"')


def eh_stub(p: Path) -> bool:
    try:
        txt = p.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return False
    return any(m in txt for m in MARCAS_CONHECIDAS)


def stub(titulo, descricao, chave_r, modelo):
    return "\n".join([
        "---",
        f'title: "{aspas(titulo)}"',
        f'description: "{aspas(descricao)}"',
        "toc: false",
        "page-layout: full",
        "---",
        "",
        MARCA,
        "",
        "```{r}",
        "#| include: false",
        chave_r,
        "```",
        "",
        "{{< include " + modelo + " >}}",
        "",
    ])


def gerar(pasta, modelo, paginas):
    d = REPO / pasta
    if not (d / modelo).exists():
        print(f"  {pasta}/{modelo} não existe: nenhuma página gerada em {pasta}/")
        return 0
    novos, pulados, iguais = set(), [], 0
    for nome, txt in paginas:
        p = d / f"{nome}.qmd"
        if nome == "index" or nome.startswith("_"):
            pulados.append(p.name)
            continue
        if p.exists() and not eh_stub(p):
            pulados.append(p.name)
            continue
        if p.exists() and p.read_text(encoding="utf-8") == txt:
            iguais += 1
        else:
            p.write_text(txt, encoding="utf-8", newline="\n")
        novos.add(p.name)
    for p in sorted(d.glob("*.qmd")):
        if p.name in novos or p.name == "index.qmd" or p.name.startswith("_"):
            continue
        if eh_stub(p):
            p.unlink()
            print(f"  apagado stub antigo: {pasta}/{p.name}")
    for n in pulados:
        print(f"  AVISO: {pasta}/{n} existe e não é stub; não foi alterado")
    print(f"  {pasta}/: {len(novos)} páginas a partir de {modelo} ({len(novos) - iguais} gravadas, {iguais} sem mudança)")
    return len(novos)


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass
    ap = argparse.ArgumentParser(description="Gera os stubs de municipios/ e indicadores/")
    ap.add_argument("--municipios", choices=["todos", "sedes"], default="todos",
                    help="perfis dos 141 municípios (padrão) ou só das 3 sedes das áreas-piloto")
    a = ap.parse_args()

    ind = ler("indicadores.csv")
    mun = ler("municipios.csv")
    if len(ind) != 34 or len(mun) != 141:
        sys.exit(f"dados_site inesperado: {len(ind)} indicadores e {len(mun)} municípios (esperado 34 e 141)")
    if len({m["slug"] for m in mun}) != 141 or len({r["id"] for r in ind}) != 34:
        sys.exit("slugs ou ids repetidos em dados_site")

    paginas_ind = []
    for r in sorted(ind, key=lambda r: int(r["ordem"])):
        # O SEEG só estima mudança de uso da terra e remoções a partir de 1990
        ini = "1990" if r["id"] in ("seeg_mut", "seeg_remocoes") else "1970"
        ano = "2025" if r["origem"] == "sipra" else (f"{ini}–{r['ano_ref']}" if r["serie"] == "1" else r["ano_ref"])
        tabela = "tabela com os sinais do IBGE" if r["origem"].startswith("censo") else "tabela dos 141 municípios"
        desc = (f'Indicador do tema {r["tema"]}. Unidade: {r["unidade"]}; referência: {ano}. Apresentam-se o mapa dos 141 municípios de Mato Grosso, '
                f'a classificação no bioma e em MT e a {tabela}. Fonte: {r["fonte"]}.')
        paginas_ind.append((r["id"], stub(r["rotulo"], desc, f'IND_ID <- "{r["id"]}"', "_indicador.qmd")))

    if a.municipios == "sedes":
        mun = [m for m in mun if m["sede_piloto"] == "True"]
    paginas_mun = []
    for m in mun:
        sede = f' O município é sede da área-piloto {m["piloto"]}.' if m["sede_piloto"] == "True" else ""
        desc = (f'Perfil do município de {m["municipio"]} (MT), de bioma dominante {m["bioma"]} e classificado no tipo {m["tipo_m1"]} do Manuscrito 1 '
                f'(rótulo provisório), com indicadores da agricultura familiar no Censo 2017, da posse, do SIPRA, do SEEG e da dinâmica 2006–2017.{sede}')
        paginas_mun.append((m["slug"], stub(m["municipio"], desc, f'MUN_ID <- {int(m["id_municipio"])}L', "_perfil.qmd")))

    print("Gerando stubs:")
    gerar("indicadores", "_indicador.qmd", paginas_ind)
    gerar("municipios", "_perfil.qmd", paginas_mun)


if __name__ == "__main__":
    main()
