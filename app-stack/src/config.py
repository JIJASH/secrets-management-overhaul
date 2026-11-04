# ANTI-PATTERN #1 (intentional, Step 1 baseline): hardcoded fallback credentials.
# These dummy values exist so Gitleaks has something to find. They are removed in later steps.
# Prefixes are deliberately non-vendor so GitHub Push Protection does not block the push.

STRIPE_SECRET_KEY = "dmy_stripe_live_7Hq2Lx9VbN4mT8kR3wZp6YcF1dJs5Ga0"
S3_SECRET_KEY = "sw3dmyQk8vR2nL7xT4pZ9cB6mH1jF5gD0aS3eW8u"
JWT_SIGNING_SECRET = "jwt-dmy-9f3c7a1e5b8d2f6a4c0e7b3d9a1f5c8e2b6d4a0f"

# Used when neither CONFIG_FILE_PATH nor an env var provides a value.
FALLBACKS = {
    "DB_HOST": "localhost",
    "DB_PORT": "5432",
    "DB_NAME": "appdb",
    "STRIPE_API_KEY": STRIPE_SECRET_KEY,
    "S3_SECRET_KEY": S3_SECRET_KEY,
    "JWT_SECRET": JWT_SIGNING_SECRET,
}
