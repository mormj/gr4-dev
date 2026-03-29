#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
env_file="${root_dir}/.env"

gr4_prefix_dir="install"
if [[ -f "${env_file}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${env_file}"
  set +a
  gr4_prefix_dir="${GR4_PREFIX_DIR:-install}"
fi

prefix_dir="${root_dir}/${gr4_prefix_dir}"

if [[ ! -d "${prefix_dir}" ]]; then
  echo "install directory does not exist: ${prefix_dir}"
  exit 0
fi

assume_yes=0
if [[ "${1:-}" == "--yes" ]]; then
  assume_yes=1
fi

declare -a to_remove=()
shopt -s nullglob dotglob
for path in "${prefix_dir}"/*; do
  to_remove+=("${path}")
done
shopt -u nullglob dotglob

if [[ ${#to_remove[@]} -eq 0 ]]; then
  echo "nothing to remove under ${prefix_dir}"
  exit 0
fi

echo "Will remove all installed contents under:"
echo "  ${prefix_dir}"
printf '  - %s\n' "${to_remove[@]}"

if [[ ${assume_yes} -ne 1 ]]; then
  read -r -p "Continue? [y/N] " reply
  case "${reply}" in
    y|Y|yes|YES) ;;
    *) echo "aborted"; exit 1 ;;
  esac
fi

rm -rf -- "${to_remove[@]}"
echo "install directory wiped: ${prefix_dir}"
