# Step 1: Secret Sprawl Audit & Vulnerable Baseline

## Goal

Stand up a deliberately insecure "before" state, measure its secret sprawl with Gitleaks, and
use it as the baseline every later step is compared against.

Run it: `scripts/run-baseline-audit.sh` → findings land in `docs/step1-gitleaks-report.json`
(secrets redacted).

## Baseline vulnerabilities

| # | Where | What | Why it is a problem |
|---|-------|------|---------------------|
| 1 | `app-stack/src/config.py` | Hardcoded fallback Stripe key, S3 secret, JWT signing secret | Lives in every clone, image layer and fork forever; silently used if config is missing, so misconfiguration ships with a known secret. |
| 2 | `app-stack/.env.legacy` | Plaintext Postgres password, registry auth token, SeaweedFS/S3 secret, committed to git | Anyone with read access to the repo has prod-equivalent credentials; git history keeps them after "deletion". |
| 3 | `.github/workflows/deploy.legacy.yml` | DB password hardcoded in workflow `env:`; static `DOCKER_PASSWORD` passed via `-p`; long-lived `SSH_PRIVATE_KEY` written to disk | Static, never-rotated, broadly scoped credentials. One leaked runner log or compromised action exposes all of them. |
| 4 | Runtime | Same DB user/password shared by app, CI and deploy host | No per-workload identity, no audit trail of who used which credential, no blast-radius limit. |

## Why static `.env` files fail security standards

- **No access control or audit:** a file has no notion of who read it, when, or why
  (fails least-privilege and audit-logging expectations in SOC 2 CC6/CC7, ISO 27001 A.5.15–5.18, PCI DSS 8.x).
- **No rotation:** rotating means editing files on every host and redeploying; in practice it never
  happens. PCI DSS and CIS benchmarks expect periodic and on-compromise rotation.
- **No expiry:** credentials stay valid until someone remembers to revoke them; a leak is permanent until noticed.
- **Copies multiply:** the same value ends up in git history, Docker build context, CI logs, backups and
  laptops. Revocation cannot reach all copies.
- **Plaintext at rest:** no encryption beyond disk encryption, readable by any process with file access.

## What later steps change

The app already supports the target model: it reads credentials from `CONFIG_FILE_PATH` (a JSON file a
secrets agent can render) before env vars, and reloads them on `SIGHUP` without restarting the HTTP
server. That makes short-lived, dynamically issued credentials possible without app downtime.

## Note on committing the baseline

The pre-commit Gitleaks hook will (correctly) block committing these files. For the baseline commit
only, use `SKIP=gitleaks git commit ...`. The `secret-scan` workflow is expected to fail until the
leaks are removed.
