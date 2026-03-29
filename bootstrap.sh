#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${ROOT_DIR}/repos.yaml"

if ! command -v git >/dev/null 2>&1; then
  echo "error: git is required" >&2
  exit 1
fi

if ! command -v awk >/dev/null 2>&1; then
  echo "error: awk is required" >&2
  exit 1
fi

if [ ! -f "${MANIFEST}" ]; then
  echo "error: missing ${MANIFEST}" >&2
  exit 1
fi

# Parse a minimal YAML shape:
# repos:
#   - name: ...
#     url: ...
#     dest: ...
#     ref: ...
parse_manifest() {
  awk '
    /^[[:space:]]*-[[:space:]]+name:[[:space:]]*/ {
      if (have_name || have_url || have_dest || have_ref) {
        if (!(have_name && have_url && have_dest && have_ref)) {
          print "error: incomplete repo entry in repos.yaml" > "/dev/stderr";
          exit 2;
        }
        print name "|" url "|" dest "|" ref;
      }
      name=$0; sub(/^[^:]*:[[:space:]]*/, "", name); gsub(/^["\x27]|["\x27]$/, "", name);
      url=""; dest=""; ref="";
      have_name=1; have_url=0; have_dest=0; have_ref=0;
      next;
    }
    /^[[:space:]]*url:[[:space:]]*/ {
      url=$0; sub(/^[^:]*:[[:space:]]*/, "", url); gsub(/^["\x27]|["\x27]$/, "", url);
      have_url=1;
      next;
    }
    /^[[:space:]]*dest:[[:space:]]*/ {
      dest=$0; sub(/^[^:]*:[[:space:]]*/, "", dest); gsub(/^["\x27]|["\x27]$/, "", dest);
      have_dest=1;
      next;
    }
    /^[[:space:]]*ref:[[:space:]]*/ {
      ref=$0; sub(/^[^:]*:[[:space:]]*/, "", ref); gsub(/^["\x27]|["\x27]$/, "", ref);
      have_ref=1;
      next;
    }
    END {
      if (have_name || have_url || have_dest || have_ref) {
        if (!(have_name && have_url && have_dest && have_ref)) {
          print "error: incomplete repo entry in repos.yaml" > "/dev/stderr";
          exit 2;
        }
        print name "|" url "|" dest "|" ref;
      }
    }
  ' "${MANIFEST}"
}

mkdir -p "${ROOT_DIR}/src" "${ROOT_DIR}/build" "${ROOT_DIR}/install" "${ROOT_DIR}/var/logs" "${ROOT_DIR}/var/run"

while IFS='|' read -r name url dest relref; do
  [ -n "${name}" ] || continue

  repo_path="${ROOT_DIR}/${dest}"
  repo_dir="$(dirname "${repo_path}")"

  echo "==> ${name} (${url}) @ ${relref}"
  mkdir -p "${repo_dir}"

  if [ ! -d "${repo_path}/.git" ]; then
    echo "    cloning into ${dest}"
    git clone "${url}" "${repo_path}"
  else
    echo "    repo exists at ${dest}; fetching updates"
    git -C "${repo_path}" fetch --all --tags --prune
  fi

  # Ensure remotes/tags are up to date even after clone.
  git -C "${repo_path}" fetch --all --tags --prune

  # Prefer remote branch refs so "main" resolves to latest origin/main.
  if git -C "${repo_path}" rev-parse --verify --quiet "origin/${relref}^{commit}" >/dev/null; then
    target="origin/${relref}"
  elif git -C "${repo_path}" rev-parse --verify --quiet "${relref}^{commit}" >/dev/null; then
    target="${relref}"
  elif git -C "${repo_path}" rev-parse --verify --quiet "refs/tags/${relref}^{commit}" >/dev/null; then
    target="refs/tags/${relref}"
  else
    echo "error: could not resolve ref '${relref}' for ${name}" >&2
    exit 1
  fi

  git -C "${repo_path}" checkout --detach "${target}"
  commit="$(git -C "${repo_path}" rev-parse --short HEAD)"
  echo "    checked out ${target} (${commit})"
done < <(parse_manifest)

echo "bootstrap complete"
