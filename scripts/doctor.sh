#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${ROOT_DIR}/repos.yaml"

ok() { echo "[ok]   $*"; }
warn() { echo "[warn] $*"; }
fail() { echo "[fail] $*"; }

status=0

check_cmd() {
  local c="$1"
  if command -v "$c" >/dev/null 2>&1; then
    ok "command present: $c"
  else
    fail "missing command: $c"
    status=1
  fi
}

parse_manifest_name_dest() {
  awk '
    /^[[:space:]]*-[[:space:]]+name:[[:space:]]*/ {
      if (have_name || have_dest) {
        if (!(have_name && have_dest)) {
          print "error: incomplete repo entry in repos.yaml (name/dest required)" > "/dev/stderr";
          exit 2;
        }
        print name "|" dest;
      }
      name=$0; sub(/^[^:]*:[[:space:]]*/, "", name); gsub(/^["\x27]|["\x27]$/, "", name);
      dest="";
      have_name=1; have_dest=0;
      next;
    }
    /^[[:space:]]*dest:[[:space:]]*/ {
      dest=$0; sub(/^[^:]*:[[:space:]]*/, "", dest); gsub(/^["\x27]|["\x27]$/, "", dest);
      have_dest=1;
      next;
    }
    END {
      if (have_name || have_dest) {
        if (!(have_name && have_dest)) {
          print "error: incomplete repo entry in repos.yaml (name/dest required)" > "/dev/stderr";
          exit 2;
        }
        print name "|" dest;
      }
    }
  ' "${MANIFEST}"
}

echo "gr4-dev doctor"
echo "workspace: ${ROOT_DIR}"

check_cmd git
check_cmd bash
check_cmd awk

if [ -f "${MANIFEST}" ]; then
  ok "repos.yaml present"
else
  fail "repos.yaml missing"
  status=1
fi

if [ -f "${ROOT_DIR}/.env" ]; then
  ok ".env present"
elif [ -f "${ROOT_DIR}/.env.example" ]; then
  warn ".env missing; copy .env.example to .env"
else
  warn ".env and .env.example both missing"
fi

for d in src build install var/logs scripts; do
  if [ -d "${ROOT_DIR}/${d}" ]; then
    ok "directory exists: ${d}"
  else
    warn "directory missing: ${d}"
  fi
done

if [ -f "${MANIFEST}" ]; then
  while IFS='|' read -r repo_name repo_dest; do
    [ -n "${repo_name}" ] || continue
    if [ -d "${ROOT_DIR}/${repo_dest}/.git" ]; then
      ok "repo present: ${repo_dest} (${repo_name})"
    else
      warn "repo missing: ${repo_dest} (${repo_name}) (run ./bootstrap.sh)"
    fi
  done < <(parse_manifest_name_dest)
fi

exit "${status}"
