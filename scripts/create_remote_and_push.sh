#!/usr/bin/env bash
set -euo pipefail

REPO_NAME="${1:-$(basename "$(git rev-parse --show-toplevel)")}" 
VIS="${2:-private}"       # private|public
BRANCH="${3:-$(git branch --show-current)}"
AUTO_CONFIRM="${AUTO_CONFIRM:-0}"

confirm() {
  [[ "$AUTO_CONFIRM" == "1" ]] && return 0
  read -r -p "$* [y/N]: " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]]
}

# sanity checks
git rev-parse --is-inside-work-tree >/dev/null || { echo "[err] not a git repo"; exit 1; }
if [[ -z "$BRANCH" ]]; then echo "[err] cannot detect current branch; pass as 3rd arg"; exit 1; fi

echo "== prepare .gitignore and remove cached build artifacts =="
for p in "apps/web/node_modules/" "apps/web/.next/"; do
  if ! grep -qxF "$p" .gitignore 2>/dev/null; then
    echo "$p" >> .gitignore
    git add .gitignore
    echo "[info] appended $p to .gitignore"
  fi
done

git rm -r --cached apps/web/node_modules apps/web/.next >/dev/null 2>&1 || true
if git status --porcelain | grep -qE "^\s*M\s+.gitignore|^\s*D\s+apps/web/"; then
  git commit -m "chore: remove build artifacts before remote push" || true
else
  echo "[info] no cleanup changes to commit"
fi

# remote check
if git remote get-url origin >/dev/null 2>&1; then
  ORIGIN_URL="$(git remote get-url origin)"
  echo "[warn] origin exists: $ORIGIN_URL"
  if ! confirm "Remove and recreate origin to point to new repo?"; then
    echo "Aborting per user choice."
    exit 0
  fi
  git remote remove origin
fi

# Use gh if available (preferred)
if command -v gh >/dev/null 2>&1; then
  echo "[info] gh found; creating repo and pushing..."
  gh repo create "$REPO_NAME" --"$VIS" --source=. --remote=origin --push --confirm
  echo "[ok] created and pushed via gh"
  git remote -v
  exit 0
fi

# Fallback: use GitHub API with GITHUB_TOKEN
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "[err] gh not found and GITHUB_TOKEN not set. Install gh or export GITHUB_TOKEN and re-run."
  exit 1
fi

echo "[info] creating GitHub repo via API..."
LOGIN="$(curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | python -c "import sys,json; print(json.load(sys.stdin).get('login',''))")"
if [[ -z "$LOGIN" ]]; then echo "[err] cannot determine GitHub login from token"; exit 1; fi

resp="$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Content-Type: application/json" -d "{\"name\": \"$REPO_NAME\", \"private\": $( [[ "$VIS" == "private" ]] && echo true || echo false ) }" https://api.github.com/user/repos)"
url="$(echo "$resp" | python -c "import sys,json; d=json.load(sys.stdin); print(d.get('html_url',''))")"
msg="$(echo "$resp" | python -c "import sys,json; d=json.load(sys.stdin); print(d.get('message',''))")"
if [[ -z "$url" ]]; then
  echo "[err] repo creation failed: $msg"
  echo "$resp" | sed -n '1,200p'
  exit 1
fi

git remote add origin "https://github.com/$LOGIN/$REPO_NAME.git"
git push -u origin "$BRANCH"
echo "[ok] created $url and pushed branch $BRANCH"
git remote -v
