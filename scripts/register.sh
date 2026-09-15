#!/usr/bin/env bash
# =====================================================================
# TEMAN: Script ini bagian dari tugas Service Discovery.
# Dipakai API (atau discovery service) untuk mendaftarkan instance
# ke registry saat container start.
# =====================================================================
set -euo pipefail

DISCOVERY_URL="${DISCOVERY_URL:-http://discovery:8500/register}"
SERVICE_NAME="${SERVICE_NAME:-api}"
SERVICE_HOST="${SERVICE_HOST:-$(hostname -i)}"
SERVICE_PORT="${SERVICE_PORT:-8000}"

curl -sf -X POST "$DISCOVERY_URL" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$SERVICE_NAME\",\"host\":\"$SERVICE_HOST\",\"port\":$SERVICE_PORT}"

echo "registered $SERVICE_NAME @ $SERVICE_HOST:$SERVICE_PORT"