#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/Users/ahuai/Documents/medexam"
FLUTTER_BIN="/Users/ahuai/development/flutter/bin/flutter"
API_HOST="0.0.0.0"
API_PORT="8000"
WEB_HOST="0.0.0.0"
WEB_PORT="5275"

detect_lan_ip() {
  local ip
  ip="$(ipconfig getifaddr en0 2>/dev/null || true)"
  if [[ -z "${ip}" ]]; then
    ip="$(ipconfig getifaddr en1 2>/dev/null || true)"
  fi
  if [[ -z "${ip}" ]]; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
  fi
  if [[ -z "${ip}" ]]; then
    ip="127.0.0.1"
  fi
  echo "${ip}"
}

cleanup_port() {
  local port="$1"
  local pids
  pids="$(lsof -tiTCP:"${port}" -sTCP:LISTEN || true)"
  if [[ -n "${pids}" ]]; then
    echo "Cleaning port ${port}: ${pids}"
    kill ${pids} 2>/dev/null || true
    sleep 1
    pids="$(lsof -tiTCP:"${port}" -sTCP:LISTEN || true)"
    if [[ -n "${pids}" ]]; then
      kill -9 ${pids} 2>/dev/null || true
      sleep 1
    fi
  fi

  pids="$(lsof -tiTCP:"${port}" -sTCP:LISTEN || true)"
  if [[ -n "${pids}" ]]; then
    echo "Port ${port} is still occupied by: ${pids}"
    echo "Please stop the old server with Ctrl+C, or run: lsof -tiTCP:${port} -sTCP:LISTEN | xargs kill -9"
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

LAN_IP="$(detect_lan_ip)"
API_BASE_URL="${API_BASE_URL:-http://${LAN_IP}:${API_PORT}}"
LOCAL_WEB_URL="http://127.0.0.1:${WEB_PORT}/"
LAN_WEB_URL="http://${LAN_IP}:${WEB_PORT}/"
LAN_ADMIN_URL="http://${LAN_IP}:${WEB_PORT}/#/admin"

cd "${PROJECT_DIR}/backend"
python3 -m uvicorn app.main:app --host "${API_HOST}" --port "${API_PORT}" &
API_PID="$!"
trap cleanup_api EXIT

echo
echo "MedExam local network server"
echo "Backend: http://${LAN_IP}:${API_PORT}"
echo "Student app (share this): ${LAN_WEB_URL}"
echo "Admin (share this): ${LAN_ADMIN_URL}"
echo "This Mac local URL: ${LOCAL_WEB_URL}"
echo "API_BASE_URL: ${API_BASE_URL}"
echo

cd "${PROJECT_DIR}/app"
"${FLUTTER_BIN}" build web --pwa-strategy=none \
  --dart-define="API_BASE_URL=${API_BASE_URL}"
python3 "${PROJECT_DIR}/scripts/serve_web.py" \
  --directory "${PROJECT_DIR}/app/build/web" \
  --host "${WEB_HOST}" \
  --port "${WEB_PORT}"
