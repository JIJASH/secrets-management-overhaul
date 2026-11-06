#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sops exec-env "${PROJECT_ROOT}/bootstrap/infisical.enc.env" \
  "docker compose -f ${PROJECT_ROOT}/bootstrap/docker-compose.infisical.yml stop"
echo "[INFO] Infisical stack stopped cleanly."

