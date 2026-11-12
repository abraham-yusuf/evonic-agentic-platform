#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# entrypoint.sh — Clean server startup for Docker
# Guarantees the DB dir and shared/ dir exist with correct ownership before
# the Python server starts. Idempotent — safe to run multiple times.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

DATA_DIR="${EVONIC_DATA_DIR:-/home/evonic}"
SHARED_DIR="${SHARED_DB_DIR:-${DATA_DIR}/shared}"

echo "[entrypoint] Initialising Evonic data directory..."
mkdir -p \
    "${SHARED_DIR}/db" \
    "${DATA_DIR}/logs" \
    "${DATA_DIR}/state"

# Verify bubblewrap if SANDBOX_BACKEND=bwrap
if [[ "${SANDBOX_BACKEND:-bwrap}" == "bwrap" ]]; then
    if command -v bwrap &>/dev/null; then
        echo "[entrypoint] bubblewrap (bwrap) found — sandbox backend: bwrap ✓"
    else
        echo "[entrypoint] WARNING: SANDBOX_BACKEND=bwrap but bwrap not found."
        echo "[entrypoint] Tool sandbox (bash/runpy) will be unavailable."
        echo "[entrypoint] Install bubblewrap: apt-get install bubblewrap"
    fi
fi

echo "[entrypoint] Starting Evonic server on ${HOST:-0.0.0.0}:${PORT:-8080}..."

# Launch the Flask server directly (avoids CLI overhead)
exec python app.py
