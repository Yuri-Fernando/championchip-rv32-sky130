# =============================================================================
# Makefile - ChampionCHIP RV32I_Zmmul_Xicrc
# Todos os alvos rodam a toolchain dentro do container championchip-dev
# (ver tools/docker/Dockerfile) via scripts/*.sh, por causa da limitacao de
# bind mount do Docker Desktop na unidade de rede do Google Drive (ver
# DECISIONS.md ADR-007).
# =============================================================================

.PHONY: build-image test lint firmware openlane-baseline clean

build-image:
	docker build -t championchip-dev:latest -f tools/docker/Dockerfile tools/docker

test:
	bash scripts/run_regression.sh

lint:
	bash scripts/run_lint.sh

firmware:
	bash scripts/build_firmware.sh

openlane-baseline:
	bash scripts/run_openlane.sh

clean:
	rm -rf /c/tmp/championchip-build
