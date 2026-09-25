# =============================================================================
# Makefile - ChampionCHIP RV32I_Zmmul_Xicrc
# Cada alvo chama um script em scripts/, que funciona no Windows (Docker +
# espelho local), no Linux (Docker) e no CI (CHAMPIONCHIP_NATIVE=1).
# =============================================================================
PY ?= python

.PHONY: help build-image lint test mutation firmware gls openlane openlane-opt openlane-final reports dashboard notebooks all

help:
	@echo "build-image   imagem Docker com todas as ferramentas (uma vez)"
	@echo "lint          lint sintetizavel (Verilator -Wall)"
	@echo "test          regressao: unit + ISA + firmware + diferencial randomizado"
	@echo "mutation      teste de mutacao (forca da verificacao)"
	@echo "firmware      compila e simula o firmware (log + waveform)"
	@echo "openlane      RTL -> GDSII baseline (40 ns, ~50 min)"
	@echo "openlane-opt  RTL -> GDSII otimizado (30 ns, ~50 min)"
	@echo "openlane-final RTL -> GDSII final (30 ns, sem diodos heuristicos)"
	@echo "gls           simulacao gate-level da netlist pos-layout"
	@echo "reports       agrega evidencias em reports/"
	@echo "dashboard     gera dashboard/index.html"
	@echo "notebooks     regenera e executa os notebooks"
	@echo "all           lint + test + mutation + gls + reports + dashboard"

build-image:
	docker build -t championchip-dev:latest -f tools/docker/Dockerfile tools/docker

lint:
	bash scripts/run_lint.sh

test:
	bash scripts/run_regression.sh

mutation:
	bash scripts/run_mutation.sh

firmware:
	bash scripts/run_firmware_sim.sh

openlane:
	bash scripts/run_openlane.sh openlane/config/config.json baseline

openlane-opt:
	bash scripts/run_openlane.sh openlane/config/config_opt30.json opt30

openlane-final:
	bash scripts/run_openlane.sh openlane/config/config_final.json final

gls:
	bash scripts/run_gls.sh

reports:
	$(PY) tools/build_reports.py

dashboard: reports
	$(PY) tools/build_dashboard.py

notebooks:
	$(PY) tools/make_notebooks.py
	$(PY) -m jupyter nbconvert --to notebook --execute --inplace --ExecutePreprocessor.timeout=3600 notebooks/0*.ipynb

all: lint test mutation gls dashboard
