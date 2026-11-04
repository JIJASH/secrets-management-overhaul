"""Legacy demo app. Credentials come from CONFIG_FILE_PATH (JSON) > env vars > config.py fallbacks.

`kill -HUP <pid>` (or `docker kill -s HUP <container>`) reloads credentials without restarting the server.
"""
import json
import logging
import os
import signal
from contextlib import closing

import psycopg2
import uvicorn
from fastapi import FastAPI
from fastapi.responses import JSONResponse

import config

log = logging.getLogger("app")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

KEYS = (
    "DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD",
    "REGISTRY_URL", "REGISTRY_USER", "REGISTRY_AUTH_TOKEN",
    "S3_ENDPOINT", "S3_ACCESS_KEY", "S3_SECRET_KEY",
    "STRIPE_API_KEY", "JWT_SECRET",
)


def load_credentials():
    data, source = {}, "env"
    path = os.getenv("CONFIG_FILE_PATH")
    if path:
        with open(path) as f:
            data = json.load(f)
        source = f"file:{path}"
    creds = {k: data.get(k) or os.getenv(k) or config.FALLBACKS.get(k) for k in KEYS}
    return creds, source


CREDS, SOURCE = load_credentials()


def reload_credentials(*_):
    global CREDS, SOURCE
    try:
        # Single reference swap: in-flight requests keep the dict they already read.
        CREDS, SOURCE = load_credentials()
        log.info("SIGHUP: credentials reloaded from %s (db_user=%s)", SOURCE, CREDS["DB_USER"])
    except Exception as e:  # keep serving with the old credentials
        log.error("SIGHUP: reload failed, keeping previous credentials: %s", e)


def mask(value):
    if not value:
        return None
    return value[:2] + "****" + value[-2:] if len(value) > 4 else "****"


app = FastAPI(title="legacy-app")


@app.get("/health")
def health():
    c = CREDS
    try:
        with closing(psycopg2.connect(
            host=c["DB_HOST"], port=c["DB_PORT"], dbname=c["DB_NAME"],
            user=c["DB_USER"], password=c["DB_PASSWORD"], connect_timeout=3,
        )) as conn, conn.cursor() as cur:
            cur.execute("SELECT current_user, now();")
            user, ts = cur.fetchone()
    except psycopg2.Error as e:
        return JSONResponse(status_code=503, content={"status": "error", "error": str(e).strip()})
    return {
        "status": "ok",
        "active_db_user": user,
        "timestamp": ts.isoformat(),
        "db_password_preview": mask(c["DB_PASSWORD"]),
        "credential_source": SOURCE,
    }


@app.get("/storage-check")
def storage_check():
    # Simulated: reports what the app *would* authenticate with; no network calls.
    c = CREDS
    return {
        "status": "simulated",
        "docker_registry": {
            "url": c["REGISTRY_URL"],
            "user": c["REGISTRY_USER"],
            "auth_token_loaded": bool(c["REGISTRY_AUTH_TOKEN"]),
            "auth_token_preview": mask(c["REGISTRY_AUTH_TOKEN"]),
        },
        "s3_store": {
            "endpoint": c["S3_ENDPOINT"],
            "access_key": c["S3_ACCESS_KEY"],
            "secret_key_loaded": bool(c["S3_SECRET_KEY"]),
            "secret_key_preview": mask(c["S3_SECRET_KEY"]),
        },
        "credential_source": SOURCE,
    }


if __name__ == "__main__":
    assert mask("abcdefgh") == "ab****gh" and mask("abc") == "****" and mask(None) is None
    signal.signal(signal.SIGHUP, reload_credentials)  # uvicorn only traps SIGINT/SIGTERM
    uvicorn.run(app, host="0.0.0.0", port=8000)
