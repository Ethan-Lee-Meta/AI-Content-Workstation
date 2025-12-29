#!/usr/bin/env bash
set -euo pipefail
set +x 2>/dev/null || true

say()  { printf "%s\n" "$*"; }
ok()   { say "[ok]  $*"; }
warn() { say "[warn] $*"; }
err()  { say "[err] $*" >&2; }

# ---- ARCH defaults (from your ARCH_DIGEST) ----
ARCH_APP_ENV="${ARCH_APP_ENV:-local_dev}"
ARCH_LOG_LEVEL="${ARCH_LOG_LEVEL:-info}"
ARCH_DATABASE_URL="${ARCH_DATABASE_URL:-sqlite:///./data/app.db}"
ARCH_STORAGE_ROOT="${ARCH_STORAGE_ROOT:-./data/storage}"
ARCH_WEB_PORT="${ARCH_WEB_PORT:-2000}"
ARCH_API_PORT="${ARCH_API_PORT:-7000}"

MODE="install"  # preflight|install
DO_GATE="1"
DO_BACKEND="1"
DO_FRONTEND="1"

for a in "${@:-}"; do
  case "$a" in
    --preflight) MODE="preflight" ;;
    --install) MODE="install" ;;
    --no-gate) DO_GATE="0" ;;
    --no-backend) DO_BACKEND="0" ;;
    --no-frontend) DO_FRONTEND="0" ;;
    *)
      err "unknown arg: $a"
      say "usage: --preflight|--install [--no-gate] [--no-backend] [--no-frontend]"
      exit 2
      ;;
  esac
done

# ---- repo root = script_dir/.. (NO upward walking) ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ok "repo_root=$ROOT"
cd "$ROOT"

# sanity check expected layout; warn (do not loop)
if [ ! -d "apps/api" ]; then warn "missing apps/api under repo_root"; fi
if [ ! -d "apps/web" ]; then warn "missing apps/web under repo_root"; fi

have() { command -v "$1" >/dev/null 2>&1; }

choose_python() {
  if have python; then echo "python"; return 0; fi
  if have python3; then echo "python3"; return 0; fi
  if have py; then echo "py -3"; return 0; fi
  return 1
}

PY="$(choose_python || true)"
[ -n "${PY:-}" ] || { err "python not found in PATH"; exit 4; }
have node || { err "node not found in PATH"; exit 4; }
have npm  || { err "npm not found in PATH"; exit 4; }

ok "python: $($PY --version 2>&1 || true)"
ok "node  : $(node --version 2>&1 || true)"
ok "npm   : $(npm --version 2>&1 || true)"

# ---- port check (warn only) ----
is_windows_gbash() {
  case "$(uname -s 2>/dev/null || true)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

check_port() {
  local port="$1"
  if is_windows_gbash; then
    local lines
    lines="$(netstat -ano -p tcp 2>/dev/null | grep -E "LISTENING|LISTEN" | grep -E ":${port}[[:space:]]" || true)"
    if [ -n "$lines" ]; then
      warn "port $port appears in use:"
      say "$lines"
    else
      ok "port $port available (netstat)"
    fi
  else
    warn "port check skipped (non-windows mode)"
  fi
}

check_port "$ARCH_WEB_PORT"
check_port "$ARCH_API_PORT"

# ---- export env (ARCH defaults) ----
export APP_ENV="$ARCH_APP_ENV"
export LOG_LEVEL="$ARCH_LOG_LEVEL"
export DATABASE_URL="$ARCH_DATABASE_URL"
export STORAGE_ROOT="$ARCH_STORAGE_ROOT"
ok "env exported: APP_ENV=$APP_ENV LOG_LEVEL=$LOG_LEVEL DATABASE_URL=$DATABASE_URL STORAGE_ROOT=$STORAGE_ROOT"

# ---- runtime dirs ----
mkdir -p "./data"
mkdir -p "${STORAGE_ROOT}"
ok "runtime dirs ensured: ./data , ${STORAGE_ROOT}"

if [ "$MODE" = "preflight" ]; then
  ok "preflight done"
  exit 0
fi

# ---- backend install (adaptive) ----
backend_install() {
  local bd="apps/api"
  [ -d "$bd" ] || { err "backend dir not found: $bd"; return 10; }

  local venv="$bd/.venv"
  local activate=""
  if [ -f "$venv/Scripts/activate" ]; then
    activate="$venv/Scripts/activate"
  elif [ -f "$venv/bin/activate" ]; then
    activate="$venv/bin/activate"
  else
    ok "creating venv: $venv"
    (cd "$bd" && eval "$PY -m venv .venv")
    if [ -f "$venv/Scripts/activate" ]; then
      activate="$venv/Scripts/activate"
    else
      activate="$venv/bin/activate"
    fi
  fi

  # shellcheck disable=SC1090
  . "$activate"
  ok "venv active: $(python --version 2>&1)"

  python -m pip install -U pip setuptools wheel >/dev/null 2>&1 || true

  local req=""
  for f in "$bd"/requirements*.txt; do
    if [ -f "$f" ]; then req="$f"; break; fi
  done

  if [ -n "$req" ]; then
    ok "backend deps via requirements: $req"
    python -m pip install -r "$req"
    ok "backend deps installed"
    return 0
  fi

  if [ -f "$bd/pyproject.toml" ]; then
    warn "no requirements*.txt; trying pip -e . from pyproject.toml"
    (cd "$bd" && python -m pip install -e .)
    ok "backend deps installed (pip -e .)"
    return 0
  fi

  err "cannot determine backend deps: missing requirements*.txt and pyproject.toml under apps/api"
  return 15
}

# ---- frontend install (adaptive) ----
frontend_install() {
  local wd="apps/web"
  [ -d "$wd" ] || { err "frontend dir not found: $wd"; return 20; }
  [ -f "$wd/package.json" ] || { err "missing $wd/package.json"; return 21; }

  if [ -f "$wd/package-lock.json" ]; then
    ok "frontend: npm ci"
    (cd "$wd" && npm ci)
  else
    warn "frontend: no package-lock.json -> npm install"
    (cd "$wd" && npm install)
  fi
  ok "frontend deps installed"
}

# ---- gate (optional) ----
run_gate() {
  local gate="scripts/gate_all.sh"
  if [ ! -f "$gate" ]; then
    warn "gate not found: $gate (allowed to skip in PRE-BATCH)"
    return 0
  fi
  ok "running gate: $gate --mode=preflight (if supported)"
  if bash "$gate" --mode=preflight; then ok "gate preflight passed"; return 0; fi
  warn "gate --mode=preflight failed; retry no-arg"
  bash "$gate" || warn "gate failed (allowed in PRE-BATCH)"
  return 0
}

say "== PRE-BATCH-ENV-INIT v2: install =="

if [ "$DO_BACKEND" = "1" ]; then
  say "== backend: install =="
  backend_install
else
  warn "backend skipped (--no-backend)"
fi

if [ "$DO_FRONTEND" = "1" ]; then
  say "== frontend: install =="
  frontend_install
else
  warn "frontend skipped (--no-frontend)"
fi

if [ "$DO_GATE" = "1" ]; then
  say "== gate: optional =="
  run_gate
else
  warn "gate skipped (--no-gate)"
fi

ok "PRE-BATCH-ENV-INIT v2 done"