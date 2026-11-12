# ─────────────────────────────────────────────────────────────────────────────
# Evonic Agentic AI Platform — Production Docker Image
# ─────────────────────────────────────────────────────────────────────────────
# Base: Python 3.12 slim-bookworm (stable, glibc, widest binary compat)
FROM python:3.12-slim-bookworm AS builder

# Build arguments
ARG UID=1000
ARG GID=1000

# ── Stage 1: Build venv ──────────────────────────────────────────────────────
FROM builder AS venv

WORKDIR /build

# Install build dependencies (needed for compiled deps like Pillow/opencv)
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
        libgl1-mesa-glx \
        libglib2.0-0 \
        libsm6 \
        libxext6 \
        libxrender1 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for layer caching
COPY requirements.txt .

# Create venv and install all deps (including optionals, skip docs)
RUN python -m venv /opt/evonic-venv \
    && /opt/evonic-venv/bin/pip install --upgrade pip \
    && /opt/evonic-venv/bin/pip install \
        --no-cache-dir \
        --no-warn-script-location \
        -r requirements.txt

# ── Stage 2: Runtime image ────────────────────────────────────────────────────
FROM python:3.12-slim-bookworm

# Prevent interactive apt prompts
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# ── Build args → env ─────────────────────────────────────────────────────────
ARG UID=1000
ARG GID=1000

# ── System runtime dependencies ──────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        # Core utils
        git curl wget vim nano jq sqlite3 file tzdata \
        # OpenCV / Pillow runtime deps (headless = no display, just codec libs)
        libgl1-mesa-glx libglib2.0-0 libsm6 libxext6 libxrender1 \
        libjpeg62-turbo \
        # Python runtime linking
        libpq5 \
        # Optional: bubblewrap for SANDBOX_BACKEND=bwrap (Linux-only)
        bubblewrap \
        # Optional: SSH connector
        openssh-client \
    && rm -rf /var/lib/apt/links/* \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user matching host UID/GID (for file ownership sanity)
RUN groupadd --gid ${GID} evonic \
    && useradd --uid ${UID} --gid ${GID} --create-home --shell /bin/bash evonic

# Copy pre-built venv from builder stage
COPY --from=venv /opt/evonic-venv /opt/evonic-venv

# Copy application source
COPY --chown=${UID}:${GID} . .

# ── Run-time environment ──────────────────────────────────────────────────────
ENV PATH="/opt/evonic-venv/bin:$PATH" \
    EVONIC_DATA_DIR=/home/evonic/data \
    FLASK_ENV=production

WORKDIR /home/evonic

# Prepare writable dirs for the evonic user
RUN mkdir -p data logs state .evonic_shared \
    && chown -R ${UID}:${GID} /home/evonic

# Switch to non-root user
# Health check via entrypoint
COPY --chown=${UID}:${GID} entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER evonic

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -sf http://localhost:8080/ || exit 1

EXPOSE 8080 8081

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["python", "app.py"]
