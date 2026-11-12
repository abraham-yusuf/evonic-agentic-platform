#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# push-kit.sh — Push Evonic Sandbox + OCI Kit to GHCR
# Run ONCE from your local machine (with Docker installed)
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

GITHUB_TOKEN="${GITHUB_TOKEN:-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}"
REGISTRY="ghcr.io"
OWNER="abraham-yusuf"
SANDBOX_IMG="evonic-agentic-platform"
KIT_IMG="evonic-agentic-kit"

echo "═══════════════════════════════════════════════════════════════"
echo "  Evonic Docker Kits — Push to GHCR"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ── Step 1: Login to GHCR ───────────────────────────────────────────
echo "🔐 Step 1: Login to GHCR..."
docker login "$REGISTRY" -u "$OWNER" -p "$GITHUB_TOKEN"
echo "   ✓ Logged in as $OWNER"
echo ""

# ── Step 2: Build & Push Sandbox Image ──────────────────────────────
echo "📦 Step 2: Build & push sandbox image..."
DOCKERFILE="/tmp/evonic-dockerkit/Dockerfile"

if [[ ! -f "$DOCKERFILE" ]]; then
    echo "   ⚠️  Dockerfile not found. Expected path: $DOCKERFILE"
    echo "   Copy /workspace/evonic-docker-kit/Dockerfile to /tmp/evonic-dockerkit/"
    exit 1
fi

# Build multi-arch sandbox image
docker build \
  --platform linux/amd64 \
  --target runtime \
  --build-arg UID=1000 --build-arg GID=1000 \
  -t "${REGISTRY}/${OWNER}/${SANDBOX_IMG}:latest" \
  . 2>&1 | tail -5 || true

docker push "${REGISTRY}/${OWNER}/${SANDBOX_IMG}:latest"
echo "   ✓ Pushed: ${REGISTRY}/${OWNER}/${SANDBOX_IMG}:latest"
echo ""

# ── Step 3: Build & Push OCI Kit ────────────────────────────────────
echo "📚 Step 3: Build & push OCI kit..."

# OCI kit = empty container with spec.yaml inside
mkdir -p /tmp/evonic-oci-kit
cp spec.yaml /tmp/evonic-oci-kit/
cat > /tmp/evonic-oci-kit/.dockerignore << 'EOF'
*
!spec.yaml
EOF

docker build \
  --platform linux/amd64 \
  -t "${REGISTRY}/${OWNER}/${KIT_IMG}:v1" \
  /tmp/evonic-oci-kit/ 2>&1 | tail -3

docker push "${REGISTRY}/${OWNER}/${KIT_IMG}:v1"
echo "   ✓ Pushed: ${REGISTRY}/${OWNER}/${KIT_IMG}:v1"
echo ""

# ── Step 4: Done ────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ PUSH COMPLETE!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  📦 Sandbox Image: ${REGISTRY}/${OWNER}/${SANDBOX_IMG}:latest"
echo "  📚 OCI Kit:       ${REGISTRY}/${OWNER}/${KIT_IMG}:v1"
echo ""
echo "  Use in Docker Agentic Platform:"
echo "    sbx --cloud run evonic --name my-evonic \\"
echo "        --kit ${REGISTRY}/${OWNER}/${KIT_IMG}:v1"
echo ""
echo "  Or use sandbox image directly:"
echo "    sbx --cloud run --template ${REGISTRY}/${OWNER}/${SANDBOX_IMG}:latest"
echo ""
