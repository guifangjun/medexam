#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: ./scripts/build_web_public.sh https://your-api.example.com"
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_BASE_URL="$1"
FLUTTER_BIN="${FLUTTER_BIN:-/Users/ahuai/development/flutter/bin/flutter}"

cd "${PROJECT_DIR}/app"
"${FLUTTER_BIN}" build web --release --pwa-strategy=none \
  --dart-define="API_BASE_URL=${API_BASE_URL}"

echo "Built public web app with API_BASE_URL=${API_BASE_URL}"
echo "Output: ${PROJECT_DIR}/app/build/web"
