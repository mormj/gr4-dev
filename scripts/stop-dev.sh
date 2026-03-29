#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="${ROOT_DIR}/var/run/control-plane.pid"

if [ ! -f "${PID_FILE}" ]; then
  echo "no control-plane pid file found"
  exit 0
fi

PID="$(cat "${PID_FILE}")"
if kill -0 "${PID}" >/dev/null 2>&1; then
  kill "${PID}"
  echo "stopped control-plane pid=${PID}"
else
  echo "stale pid file found for pid=${PID}; removing"
fi

rm -f "${PID_FILE}"
