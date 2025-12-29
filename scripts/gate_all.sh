#!/usr/bin/env bash
set -euo pipefail

MODE="preflight"
STRICT="0"
for a in "$@"; do
  case "$a" in
    --mode=*) MODE="${a#*=}" ;;
    --strict) STRICT="1" ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

ok(){ echo "[ok] $*"; }
warn(){ echo "[warn] $*" >&2; }
err(){ echo "[err] $*" >&2; exit 3; }

pick_first() {
  for p in "$@"; do
    if [[ -f "$p" ]]; then echo "$p"; return 0; fi
  done
  return 1
}

PLAN="$(pick_first 03_MASTER_PLAN_frozen.yaml docs/03_MASTER_PLAN_frozen.yaml docs/ssot/03_MASTER_PLAN_frozen.yaml 2>/dev/null || true)"
ARCH="$(pick_first 02_ARCH_DIGEST.yaml docs/02_ARCH_DIGEST.yaml docs/ssot/02_ARCH_DIGEST.yaml 2>/dev/null || true)"
SPEC="$(pick_first 01_AI_SPECDIGEST.yaml docs/01_AI_SPECDIGEST.yaml docs/ssot/01_AI_SPECDIGEST.yaml 2>/dev/null || true)"

echo "== gate_all: start =="
echo "[info] root=$ROOT"
echo "[info] mode=$MODE"

# Print frozen fingerprints (prefer reading from MASTER_PLAN meta.inputs_fingerprints)
if [[ -n "${PLAN:-}" && -f "$PLAN" ]]; then
  python - "$PLAN" <<'PY'
import re,sys
p=sys.argv[1]
t=open(p,encoding="utf-8",errors="ignore").read()
def find(block):
  m=re.search(rf'inputs_fingerprints:\s*[\s\S]*?\n\s*{block}:\s*[\s\S]*?\n\s*sha256:\s*([0-9a-f]{{64}})', t)
  return m.group(1) if m else None
spec=find("AI_SPECDIGEST")
arch=find("ARCH_DIGEST")
mp=re.search(r'outputs_fingerprints:\s*[\s\S]*?\n\s*MASTER_PLAN:\s*[\s\S]*?\n\s*sha256:\s*([0-9a-f]{64})', t)
mp_sha=mp.group(1) if mp else None
print(f"[ok] fingerprints from MASTER_PLAN: spec_sha256={spec or 'NA'} arch_sha256={arch or 'NA'} master_plan_sha256={mp_sha or 'NA'}")
PY
else
  warn "03_MASTER_PLAN_frozen.yaml not found; cannot print frozen sha256 from plan."
fi

# Hard lock: ports 2000/7000 must appear in ARCH_DIGEST
if [[ -n "${ARCH:-}" && -f "$ARCH" ]]; then
  grep -q 'web_dev_server:[[:space:]]*2000' "$ARCH" || err "missing ports_lock.local.web_dev_server: 2000 in $ARCH"
  grep -q 'api_server:[[:space:]]*7000' "$ARCH" || err "missing ports_lock.local.api_server: 7000 in $ARCH"
  ok "ports_lock validated: web=2000 api=7000 (from ARCH_DIGEST)"
else
  err "02_ARCH_DIGEST.yaml not found; cannot validate ports_lock."
fi

# Soft checks (warn only): request-id header presence in contracts
if grep -q 'X-Request-Id' "$ARCH" 2>/dev/null; then
  ok "request_id header mentioned in ARCH_DIGEST"
else
  warn "X-Request-Id not found in ARCH_DIGEST text (may exist in ARCH_CONTRACT_SUMMARY)."
fi

# List downstream gate scripts
MISSING=0
expect_scripts=(
  scripts/gate_api_smoke.sh
  scripts/gate_openapi_reachable.sh
  scripts/gate_health_contract_check.sh
  scripts/gate_request_id_propagation_check.sh
  scripts/gate_error_envelope_check.sh
)
for s in "${expect_scripts[@]}"; do
  if [[ -f "$s" ]]; then ok "gate present: $s"; else warn "missing downstream gate: $s"; MISSING=$((MISSING+1)); fi
done

if [[ "$MODE" == "preflight" ]]; then
  if [[ "$MISSING" -gt 0 ]]; then
    warn "downstream gates missing ($MISSING). preflight is still allowed to continue."
    [[ "$STRICT" == "1" ]] && err "preflight strict mode: missing downstream gates"
  fi
  ok "preflight done"
  exit 0
fi

if [[ "$MODE" == "full" ]]; then
  ok "running required gates (full)"
  bash scripts/gate_api_smoke.sh
  ok "full done"
  exit 0
fi

err "unknown --mode=$MODE"
