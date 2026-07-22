#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/Users/ahuai/Documents/medexam"
FLUTTER_BIN="/Users/ahuai/development/flutter/bin/flutter"
API_HOST="127.0.0.1"
API_PORT="8000"
WEB_PORT="5275"

cleanup_port() {
  local port="$1"
  local pids
  pids="$(lsof -ti "tcp:${port}" || true)"
  if [[ -n "${pids}" ]]; then
    echo "Cleaning port ${port}: ${pids}"
    kill ${pids} 2>/dev/null || true
    sleep 1
    pids="$(lsof -ti "tcp:${port}" || true)"
    if [[ -n "${pids}" ]]; then
      kill -9 ${pids} 2>/dev/null || true
      sleep 1
    fi
  fi

  pids="$(lsof -ti "tcp:${port}" || true)"
  if [[ -n "${pids}" ]]; then
    echo "Port ${port} is still occupied by: ${pids}"
    echo "Please stop the old server with Ctrl+C, or run: lsof -ti tcp:${port} | xargs kill -9"
    exit 1
  fi
}

cleanup_api() {
  if [[ -n "${API_PID:-}" ]]; then
    kill "${API_PID}" 2>/dev/null || true
  fi
}

cleanup_port "${API_PORT}"
cleanup_port "${WEB_PORT}"

cd "${PROJECT_DIR}/backend"
python3 -m uvicorn app.main:app --host "${API_HOST}" --port "${API_PORT}" &
API_PID="$!"
trap cleanup_api EXIT

echo "Backend: http://${API_HOST}:${API_PORT}"
echo "Student app: http://127.0.0.1:${WEB_PORT}/"
echo "Admin: http://127.0.0.1:${WEB_PORT}/#/admin"

cd "${PROJECT_DIR}/app"
"${FLUTTER_BIN}" build web
python3 "${PROJECT_DIR}/scripts/serve_web.py" \
  --directory "${PROJECT_DIR}/app/build/web" \
  --host 127.0.0.1 \
  --port "${WEB_PORT}"
