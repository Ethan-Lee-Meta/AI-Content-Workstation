#!/usr/bin/env bash
set -euo pipefail

echo "== gate_bulk_actions: start =="

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "[err] not inside a git repo"; exit 1; }
cd "$ROOT" || exit 1

F="apps/web/app/library/LibraryClient.js"
API="apps/web/app/_lib/api.js"

[ -f "$F" ] || { echo "[err] missing: $F" >&2; exit 2; }
[ -f "$API" ] || { echo "[err] missing: $API" >&2; exit 3; }

# Must keep existing P0 markers
grep -Fq 'data-testid="filters-bar"' "$F" || { echo "[err] missing filters-bar marker" >&2; exit 4; }
grep -Fq 'data-testid="asset-grid"' "$F" || { echo "[err] missing asset-grid marker" >&2; exit 5; }
grep -Fq 'data-testid="bulk-action-bar"' "$F" || { echo "[err] missing bulk-action-bar marker" >&2; exit 6; }

# New bulk markers
grep -Fq 'data-testid="bulk-item-checkbox"' "$F" || { echo "[err] missing bulk item checkbox marker" >&2; exit 7; }
grep -Fq 'data-testid="bulk-select-all"' "$F" || { echo "[err] missing bulk-select-all marker" >&2; exit 8; }
grep -Fq 'data-testid="bulk-clear-selection"' "$F" || { echo "[err] missing bulk-clear-selection marker" >&2; exit 9; }
grep -Fq 'data-testid="bulk-soft-delete"' "$F" || { echo "[err] missing bulk-soft-delete marker" >&2; exit 10; }
grep -Fq 'data-testid="bulk-selected-count"' "$F" || { echo "[err] missing bulk-selected-count marker" >&2; exit 11; }

# Ensure bulk delete uses softDeleteAsset() helper
grep -Fq 'softDeleteAsset(' "$F" || { echo "[err] missing softDeleteAsset() usage in LibraryClient" >&2; exit 12; }

# Ensure helper exists in api.js
grep -Fq 'export async function softDeleteAsset' "$API" || { echo "[err] missing softDeleteAsset export in api.js" >&2; exit 13; }
grep -Fq 'method: "DELETE"' "$API" || { echo "[err] softDeleteAsset must attempt DELETE" >&2; exit 14; }

echo "[ok] bulk select UI markers present"
echo "[ok] bulk soft delete uses softDeleteAsset() helper"
echo "== gate_bulk_actions: passed =="
