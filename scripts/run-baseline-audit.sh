#!/usr/bin/env bash
# Step 1 baseline audit: boot the legacy stack, hit its endpoints, scan the repo with Gitleaks.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE="$ROOT/app-stack/docker-compose.legacy.yml"
REPORT="$ROOT/docs/step1-gitleaks-report.json"

echo "==> Booting legacy stack (waiting for healthchecks)"
docker compose -f "$COMPOSE" up -d --build --wait --wait-timeout 120

echo "==> GET /health"
curl -fsS http://localhost:8000/health; echo
echo "==> GET /storage-check"
curl -fsS http://localhost:8000/storage-check; echo

echo "==> Running Gitleaks (--no-git) over the repo"
rm -f "$REPORT"
set +e
docker run --rm -u "$(id -u):$(id -g)" -v "$ROOT:/repo" zricethezav/gitleaks:latest \
  detect --no-git --source /repo --config /repo/.gitleaks.toml \
  --redact --report-format json --report-path /repo/docs/step1-gitleaks-report.json
rc=$?
set -e
# Gitleaks exits 1 when leaks are found; anything else non-zero is a real error.
if [ "$rc" -gt 1 ]; then echo "Gitleaks failed (exit $rc)"; exit "$rc"; fi

echo "==> Leak summary ($REPORT)"
python3 - "$REPORT" <<'EOF'
import json, sys, collections
leaks = json.load(open(sys.argv[1]))
print(f"Total findings: {len(leaks)}")
for (f, r), n in sorted(collections.Counter((l["File"], l["RuleID"]) for l in leaks).items()):
    print(f"  {n:>2}  {r:<22} {f}")
EOF
