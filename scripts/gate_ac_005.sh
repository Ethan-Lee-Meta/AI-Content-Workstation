#!/usr/bin/env bash
set -euo pipefail

echo "== gate_ac_005: start =="

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "[err] not inside a git repo"; exit 1; }
cd "$ROOT" || exit 1

EVID="docs/EVIDENCE_AC_005.md"
if [ ! -f "$EVID" ]; then
  echo "[err] missing evidence doc: $EVID" >&2
  exit 2
fi

# 1) Parse interaction_layers_count <= 3
COUNT_LINE="$(grep -nE '^\s*-\s*interaction_layers_count:\s*[0-9]+' "$EVID" || true)"
if [ -z "$COUNT_LINE" ]; then
  echo "[err] missing 'interaction_layers_count' line in $EVID" >&2
  exit 3
fi
COUNT="$(echo "$COUNT_LINE" | sed -E 's/.*interaction_layers_count:\s*([0-9]+).*/\1/')"
if ! echo "$COUNT" | grep -qE '^[0-9]+$'; then
  echo "[err] invalid interaction_layers_count value: $COUNT" >&2
  exit 4
fi
if [ "$COUNT" -gt 3 ]; then
  echo "[err] interaction depth too high: $COUNT (>3)" >&2
  exit 5
fi
echo "[ok] AC-005 interaction depth <= 3 (count=$COUNT)"

# 2) Verify Home has direct /generate entry (prefer home page, fallback to sidebar)
HOME_OK=0
if grep -R --line-number -E 'href=["'\'']/generate|router\.push\(\s*["'\'']/generate' apps/web/app/page.js >/dev/null 2>&1; then
  HOME_OK=1
fi
if [ "$HOME_OK" -eq 0 ]; then
  if grep -R --line-number -E 'href:\s*"/generate"|href:\s*'"'"'/generate'"'"'' apps/web/app/_components/Sidebar.js >/dev/null 2>&1; then
    HOME_OK=1
  fi
fi
if [ "$HOME_OK" -eq 0 ]; then
  echo "[err] cannot find direct /generate entry in home page or sidebar" >&2
  exit 6
fi
echo "[ok] /generate entry exists (home or sidebar)"

# 3) Verify /generate stable section markers exist
GEN_FILE="apps/web/app/generate/GenerateClient.js"
if [ ! -f "$GEN_FILE" ]; then
  echo "[err] missing generate client file: $GEN_FILE" >&2
  exit 7
fi

for k in "InputTypeSelector" "PromptEditor" "RunQueuePanel" "ResultsPanel"; do
  if ! grep -q "$k" "$GEN_FILE"; then
    echo "[err] missing marker in GenerateClient.js: $k" >&2
    exit 8
  fi
done
echo "[ok] /generate contains required markers"

echo "== gate_ac_005: passed =="
