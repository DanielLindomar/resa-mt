# -*- coding: utf-8 -*-
"""
03_gerar_paginas.py - Observatório RESA-MT

Atalho mantido por compatibilidade. Quem gera as páginas-esqueleto (stubs) é
scripts/03_gerar_stubs.py:

  municipios/_perfil.qmd     ->  municipios/<slug>.qmd   (os 141 perfis, por padrão)
  indicadores/_indicador.qmd ->  indicadores/<id>.qmd    (os 34 indicadores)

As páginas das áreas-piloto (pilotos/*.qmd) são escritas à mão, a partir do
modelo comum pilotos/_modelo_piloto.qmd, e não são geradas por script.

Este atalho só repassa os argumentos:
  python -I scripts/03_gerar_paginas.py                      # = 03_gerar_stubs.py (141 perfis)
  python -I scripts/03_gerar_paginas.py --municipios sedes   # perfis só das 3 sedes
"""

import runpy
import sys
from pathlib import Path

ALVO = Path(__file__).resolve().with_name("03_gerar_stubs.py")
sys.argv[0] = str(ALVO)
runpy.run_path(str(ALVO), run_name="__main__")
