#!/usr/bin/env bash
set +e

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/gate_all.sh --mode=preflight
  bash scripts/gate_all.sh --mode=full [--repeat=N]

Notes:
- mode=preflight: minimal fast checks
- mode=full: P0 regression (API baseline + UI AC-001..004 + e2e evidence)
USAGE
}

MODE="preflight"
REPEAT="1"

for arg in "$@"; do
  case "$arg" in
    --mode=preflight) MODE="preflight" ;;
    --mode=full) MODE="full" ;;
    --repeat=*) REPEAT="${arg#--repeat=}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[err] unknown arg: $arg"; usage; exit 2 ;;
  esac
done

case "$REPEAT" in
  ''|*[!0-9]*) echo "[err] --repeat must be an integer"; exit 2 ;;
esac
if [ "$REPEAT" -lt 1 ]; then echo "[err] --repeat must be >= 1"; exit 2; fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "[err] not inside a git repo"; exit 1; }
cd "$ROOT" || exit 1

mkdir -p tmp docs

TS="$(date -u +%Y%m%d_%H%M%S 2>/dev/null || echo NA)"
BR="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo NA)"
HEADSHA="$(git rev-parse HEAD 2>/dev/null || echo NA)"

echo "== gate_all: start =="
echo "== [info] mode=$MODE repeat=$REPEAT ts=$TS =="
echo "== [info] branch=$BR head=$HEADSHA =="

run_gate() {
  label="$1"
  script="$2"
  run_idx="$3"

  out="tmp/_out_gate_${label}.txt"
  if [ "$REPEAT" -gt 1 ]; then
    out="tmp/_out_gate_${label}__run${run_idx}.txt"
  fi

  echo "== ${label}: start =="
  if [ ! -f "$script" ]; then
    echo "[err] missing script: $script"
    return 20
  fi

  bash "$script" 2>&1 | tee "$out"
  rc=${PIPESTATUS[0]}
  if [ $rc -ne 0 ]; then
    echo "[err] ${label} failed rc=$rc (see $out)"
    return $rc
  fi

  echo "== ${label}: passed =="
  return 0
}

gen_evidence_full() {
  run_idx="$1"
  doc="docs/EVIDENCE_P0_FULL.md"

  {
    echo "# P0 FULL Regression Evidence"
    echo
    echo "- Generated at (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo NA)"
    echo "- Branch: $BR"
    echo "- HEAD: $HEADSHA"
    echo "- Command: bash scripts/gate_all.sh --mode=full$( [ "$REPEAT" -gt 1 ] && echo " --repeat=$REPEAT" )"
    echo
    echo "## Required gates (min set) + e2e"
    echo "- gate_api_smoke"
    echo "- gate_openapi_reachable"
    echo "- gate_health_contract_check"
    echo "- gate_request_id_propagation_check"
    echo "- gate_ac_001"
    echo "- gate_ac_002"
    echo "- gate_ac_003"
    echo "- gate_ac_004"
    echo "- gate_e2e_happy_path"
    echo
    echo "## Key [ok] lines (run ${run_idx})"
    echo '```text'
    for label in health_contract_check request_id_propagation_check openapi_reachable api_smoke web_routes ac_001 ac_002 ac_003 ac_004 e2e_happy_path; do
      f="tmp/_out_gate_${label}.txt"
      if [ "$REPEAT" -gt 1 ]; then f="tmp/_out_gate_${label}__run${run_idx}.txt"; fi
      if [ -f "$f" ]; then
        grep -E '^\[ok\]' "$f" 2>/dev/null || true
      else
        echo "[warn] missing log: $f"
      fi
    done
    echo '```'
    echo
    echo "## request_id samples (run ${run_idx})"
    echo '```text'
    f1="tmp/_out_gate_ac_003.txt"
    f2="tmp/_out_gate_ac_004.txt"
    if [ "$REPEAT" -gt 1 ]; then f1="tmp/_out_gate_ac_003__run${run_idx}.txt"; f2="tmp/_out_gate_ac_004__run${run_idx}.txt"; fi
    ( grep -Eo 'request_id=[0-9a-fA-F-]+' "$f1" "$f2" 2>/dev/null || true ) | head -n 10
    ( grep -Ei 'x-request-id' "$f1" "$f2" 2>/dev/null || true ) | head -n 10
    echo '```'
    echo
    echo "## Raw logs"
    echo "- tmp/_out_gate_*"
  } > "$doc"

  echo "[ok] evidence written: $doc"
  return 0
}

i=1
while [ $i -le "$REPEAT" ]; do
  echo "== [run] ${i}/${REPEAT} =="

  if [ "$MODE" = "preflight" ]; then
    run_gate "api_smoke" "scripts/gate_api_smoke.sh" "$i" || exit $?
  elif [ "$MODE" = "full" ]; then
    run_gate "health_contract_check" "scripts/gate_health_contract_check.sh" "$i" || exit $?
    run_gate "request_id_propagation_check" "scripts/gate_request_id_propagation_check.sh" "$i" || exit $?
    run_gate "openapi_reachable" "scripts/gate_openapi_reachable.sh" "$i" || exit $?

    run_gate "api_smoke" "scripts/gate_api_smoke.sh" "$i" || exit $?
    run_gate "web_routes" "scripts/gate_web_routes.sh" "$i" || exit $?

    run_gate "ac_001" "scripts/gate_ac_001.sh" "$i" || exit $?
    run_gate "ac_002" "scripts/gate_ac_002.sh" "$i" || exit $?
    run_gate "ac_003" "scripts/gate_ac_003.sh" "$i" || exit $?
    run_gate "ac_004" "scripts/gate_ac_004.sh" "$i" || exit $?

    run_gate "e2e_happy_path" "scripts/gate_e2e_happy_path.sh" "$i" || exit $?
    gen_evidence_full "$i" || exit $?
  else
    echo "[err] unknown mode=$MODE"
    usage
    exit 2
  fi

  i=$((i+1))
done

echo "== gate_all: passed =="
exit 0
