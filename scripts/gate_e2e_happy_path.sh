#!/usr/bin/env bash
set +e

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "[err] not inside a git repo"; exit 1; }
cd "$ROOT" || exit 1

latest() {
  ls -1t "tmp/_out_gate_${1}"*.txt 2>/dev/null | head -n 1
}

need_file() {
  f="$(latest "$1")"
  if [ -z "$f" ] || [ ! -s "$f" ]; then
    echo "[err] missing/empty log for gate '${1}' (expected tmp/_out_gate_${1}*.txt)" >&2
    echo "[hint] run: bash scripts/gate_all.sh --mode=full" >&2
    return 2
  fi
  echo "[info] using log: $f" >&2
  echo "$f"   # IMPORTANT: stdout must be ONLY the filepath
  return 0
}

echo "== gate_e2e_happy_path: start =="

F_HEALTH="$(need_file health_contract_check)" || exit $?
F_REQID="$(need_file request_id_propagation_check)" || exit $?
F_OPENAPI="$(need_file openapi_reachable)" || exit $?
F_AC003="$(need_file ac_003)" || exit $?
F_AC004="$(need_file ac_004)" || exit $?

grep -Eq '^\[ok\] /health keys present:' "$F_HEALTH" || { echo "[err] missing /health ok evidence"; exit 3; }
grep -Eq '^\[ok\] header present: X-Request-Id \(non-empty\)' "$F_REQID" || { echo "[err] missing request-id propagation ok evidence"; exit 4; }
grep -Eq '^\[ok\] /openapi\.json reachable' "$F_OPENAPI" || { echo "[err] missing openapi reachable ok evidence"; exit 5; }

grep -Eq 'create run:' "$F_AC003" || { echo "[err] missing generation evidence in AC-003 log"; exit 6; }
grep -Eq 'request_id=' "$F_AC003" || { echo "[err] missing request_id evidence in AC-003 log"; exit 7; }
grep -Eq 'override missing reason rejected' "$F_AC004" || { echo "[err] missing review override-negative evidence in AC-004 log"; exit 8; }
grep -Eq 'request_id=' "$F_AC004" || { echo "[err] missing request_id evidence in AC-004 log"; exit 9; }

RID="$( (grep -Eo 'request_id=[0-9a-fA-F-]+' "$F_AC003" "$F_AC004" 2>/dev/null || true) | head -n 1 )"
if [ -n "$RID" ]; then
  echo "[ok] request_id sample: $RID"
else
  echo "[warn] request_id sample not found by regex; check AC logs manually"
fi

echo "[ok] e2e happy path passed"
echo "== gate_e2e_happy_path: passed =="
exit 0
