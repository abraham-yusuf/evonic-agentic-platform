#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# build.sh — Build the Evonic Docker image for Agentic Platform
#
# Usage:
#   ./build.sh              # default: latest, no layer cache
#   ./build.sh --no-cache   # full rebuild from scratch
#   ./build.sh --push IMAGE # tag and push to registry
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

BUILD_ARGS="--target runtime"
NO_CACHE=""
REGISTRY=""
IMAGE_NAME="evonic-agentic-platform:latest"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-cache)
      NO_CACHE="--no-cache"
      shift
      ;;
    --push)
      REGISTRY="$2"
      shift 2
      ;;
    *)
      IMAGE_NAME="$1"
      shift
      ;;
  esac
done

# Resolve UID/GID of the host user for correct file ownership
HOST_UID="${UID:-$(id -u)}"
HOST_GID="${GID:-$(id -g)}"

echo "▶  Building Evonic Docker Kit"
echo "   Image    : $IMAGE_NAME"
echo "   UID/GID  : $HOST_UID / $HOST_GID"
echo "   No-cache : ${NO_CACHE:-no}"

docker build \
  $NO_CACHE \
  $BUILD_ARGS \
  --build-arg UID="$HOST_UID" \
  --build-arg GID="$HOST_GID" \
  -t "$IMAGE_NAME" \
  .

if [[ -n "$REGISTRY" ]]; then
  docker tag "$IMAGE_NAME" "$REGISTRY/$IMAGE_NAME"
  docker push "$REGISTRY/$IMAGE_NAME"
  echo "✓  Pushed to $REGISTRY/$IMAGE_NAME"
else
  echo "✓  Build complete. Image: $IMAGE_NAME"
  echo ""
  echo "  Next steps:"
  echo "    1. cp .env.example .env    # fill in your API keys"
  echo "    2. docker compose up --build"
fi
