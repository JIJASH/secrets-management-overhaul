#!/usr/bin/env bash
set -euo pipefail

# Automatically resolve the project root even if called from inside bootstrap/
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGE_KEY_FILE="${HOME}/.config/sops/age/keys.txt"
ENC_ENV_FILE="${PROJECT_ROOT}/bootstrap/infisical.enc.env"
COMPOSE_FILE="${PROJECT_ROOT}/bootstrap/docker-compose.infisical.yml"

if [[ ! -f "${AGE_KEY_FILE}" ]]; then
  echo "[ERROR] Age private key not found at ${AGE_KEY_FILE}"
  exit 1
fi

echo "[INFO] Decrypting Secret Zero in-memory via SOPS + Age and starting Infisical..."
sops exec-env "${ENC_ENV_FILE}" "docker compose -f ${COMPOSE_FILE} up -d"

echo "[INFO] Waiting for Infisical API at http://localhost:8080/api/status ..."
for i in {1..30}; do
  if curl -s http://localhost:8080/api/status | grep -q '"message":"Ok"'; then
    echo "[SUCCESS] Infisical Vault is UP and healthy at http://localhost:8080 !"
    exit 0
  fi
  sleep 2
done

echo "[WARN] Infisical is still running DB migrations. Check 'docker logs -f infisical-core'."
EOF
