#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/dev-env.sh" >/dev/null

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <repo-name>"
  echo "example: $0 gr4-incubator"
  exit 1
fi

repo="$1"
target_dir="${GR4_BUILD_PATH}/${repo}"

if [ ! -d "${target_dir}" ]; then
  echo "nothing to clean: ${target_dir}"
  exit 0
fi

rm -rf -- "${target_dir}"
echo "removed build directory: ${target_dir}"
