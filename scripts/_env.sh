# shellcheck shell=bash
# =============================================================================
# _env.sh - Ambiente comum dos scripts (fonte: `source scripts/_env.sh`).
#
# Tres modos de execucao, escolhidos automaticamente:
#   1. CHAMPIONCHIP_NATIVE=1   -> ferramentas instaladas no proprio host
#                                 (ex.: GitHub Actions, ver .github/workflows)
#   2. Linux/macOS com Docker  -> monta o projeto direto no container
#   3. Windows (Git Bash)      -> espelha o projeto em C:/tmp (a pasta do
#                                 Google Drive nao aceita bind mount no Docker
#                                 Desktop) e traz as evidencias de volta
#                                 (ver docs/governance/DECISIONS.md ADR-007)
#
# Uso: in_env "<comando>" [argumentos extras do docker run...]
# =============================================================================
PROJDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${CHAMPIONCHIP_IMAGE:-championchip-dev:latest}"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) ON_WINDOWS=1 ;;
  *) ON_WINDOWS=0 ;;
esac

in_env() {
  local cmd="$1"; shift
  if [ "${CHAMPIONCHIP_NATIVE:-0}" = 1 ]; then
    (cd "$PROJDIR" && bash -c "$cmd")
    return $?
  fi
  local src="$PROJDIR"
  if [ "$ON_WINDOWS" = 1 ]; then
    export MSYS_NO_PATHCONV=1
    bash "$PROJDIR/scripts/sync_mirror.sh" to >/dev/null
    src="C:/tmp/championchip-build"
  fi
  docker run --rm -v "$src:/work" -w /work "$@" "$IMAGE" bash -c "$cmd"
  local rc=$?
  if [ "$ON_WINDOWS" = 1 ]; then
    bash "$PROJDIR/scripts/sync_mirror.sh" from >/dev/null
  fi
  return $rc
}
