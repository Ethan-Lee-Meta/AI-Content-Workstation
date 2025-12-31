#!/usr/bin/env bash
set -euo pipefail

echo "== gate_trash_ui: start =="

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "[err] not inside a git repo"; exit 1; }
cd "$ROOT" || exit 1

P="apps/web/app/trash/page.js"
C="apps/web/app/trash/TrashClient.js"

[ -f "$P" ] || { echo "[err] missing: $P" >&2; exit 2; }
[ -f "$C" ] || { echo "[err] missing: $C" >&2; exit 3; }

# Stable markers
grep -Fq 'data-testid="trash-view"' "$C" || { echo "[err] missing trash-view marker" >&2; exit 4; }
grep -Fq 'data-testid="trash-list"' "$C" || { echo "[err] missing trash-list marker" >&2; exit 5; }
grep -Fq 'data-testid="trash-empty-btn"' "$C" || { echo "[err] missing trash-empty-btn marker" >&2; exit 6; }
grep -Fq 'data-testid="trash-empty-report"' "$C" || { echo "[err] missing trash-empty-report marker" >&2; exit 7; }

# Must use include_deleted=true to load trash list
grep -Fq 'include_deleted: true' "$C" || { echo "[err] missing include_deleted: true in trash list fetch" >&2; exit 8; }

# Must call /trash/empty and require confirmation
grep -Fq 'apiFetch("/trash/empty"' "$C" || grep -Fq "apiFetch('/trash/empty'" "$C" || { echo "[err] missing apiFetch(/trash/empty) call" >&2; exit 9; }
grep -Fq 'method: "POST"' "$C" || grep -Fq "method: 'POST'" "$C" || { echo "[err] missing method: POST for /trash/empty" >&2; exit 10; }
grep -Fq 'window.confirm' "$C" || { echo "[err] missing confirmation (window.confirm) for empty trash" >&2; exit 11; }

echo "[ok] trash view markers present"
echo "[ok] include_deleted=true used for trash listing"
echo "[ok] empty trash uses POST /trash/empty with confirmation"
echo "== gate_trash_ui: passed =="
