#!/usr/bin/env bash
set -euo pipefail

echo "== gate_bulk_actions: start =="

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "[err] not inside a git repo"; exit 1; }
cd "$ROOT" || exit 1

F="apps/web/app/library/LibraryClient.js"
if [ ! -f "$F" ]; then
  echo "[err] missing: $F" >&2
  exit 2
fi

# Must keep existing P0 markers
grep -Fq 'data-testid="filters-bar"' "$F" || { echo "[err] missing filters-bar marker" >&2; exit 3; }
grep -Fq 'data-testid="asset-grid"' "$F" || { echo "[err] missing asset-grid marker" >&2; exit 4; }
grep -Fq 'data-testid="bulk-action-bar"' "$F" || { echo "[err] missing bulk-action-bar marker" >&2; exit 5; }

# New bulk markers
grep -Fq 'data-testid="bulk-item-checkbox"' "$F" || { echo "[err] missing bulk item checkbox marker" >&2; exit 6; }
grep -Fq 'data-testid="bulk-select-all"' "$F" || { echo "[err] missing bulk-select-all marker" >&2; exit 7; }
grep -Fq 'data-testid="bulk-clear-selection"' "$F" || { echo "[err] missing bulk-clear-selection marker" >&2; exit 8; }
grep -Fq 'data-testid="bulk-soft-delete"' "$F" || { echo "[err] missing bulk-soft-delete marker" >&2; exit 9; }
grep -Fq 'data-testid="bulk-selected-count"' "$F" || { echo "[err] missing bulk-selected-count marker" >&2; exit 10; }

# Ensure DELETE is used via apiFetch to /assets/{id}
# Use fixed-string matching to avoid grep regex pitfalls with ${...}
if ! (grep -Fq 'apiFetch(`/assets/${encodeURIComponent' "$F" || grep -Fq 'apiFetch("/assets/' "$F" || grep -Fq "apiFetch('/assets/" "$F"); then
  echo "[err] missing apiFetch(/assets/{id}) pattern" >&2
  exit 11
fi
grep -Fq 'method: "DELETE"' "$F" || grep -Fq "method: 'DELETE'" "$F" || { echo "[err] missing method: DELETE" >&2; exit 12; }

echo "[ok] bulk select UI markers present"
echo "[ok] bulk soft delete uses DELETE /assets/{id} via apiFetch"
echo "== gate_bulk_actions: passed =="
