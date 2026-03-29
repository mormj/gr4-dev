#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ "$#" -ne 1 ]; then
  echo "usage: $0 <repo-name>"
  echo "example: $0 gr4-incubator"
  exit 1
fi

repo="$1"
exec "${ROOT_DIR}/scripts/build-all.sh" "${repo}"
