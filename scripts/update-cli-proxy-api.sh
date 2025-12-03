#!/bin/bash

set -euo pipefail

# Fetch and rebuild the CLIProxyAPI binary from the upstream repo, then drop it
# into src/Sources/Resources/cli-proxy-api for bundling.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIPROXY_REPO_URL=${CLIPROXY_REPO_URL:-"https://github.com/secondsky/CLIProxyAPI.git"}
CLIPROXY_REF=${CLIPROXY_REF:-"main"}
WORKDIR="${REPO_ROOT}/.tmp/cliproxyapi"
OUT_PATH="${REPO_ROOT}/src/Sources/Resources/cli-proxy-api"

echo "🔄 Updating cli-proxy-api from ${CLIPROXY_REPO_URL}@${CLIPROXY_REF}";

rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}"

echo "⬇️  Cloning..."
git clone --depth 1 --branch "${CLIPROXY_REF}" "${CLIPROXY_REPO_URL}" "${WORKDIR}" >/dev/null

cd "${WORKDIR}"

COMMIT_HASH=$(git rev-parse --short HEAD)

echo "🔨 Building cli-proxy-api (darwin/arm64)..."
GOOS=darwin GOARCH=arm64 go build -o bin/cli-proxy-api ./cmd/... >/dev/null

echo "📦 Installing to ${OUT_PATH}"
cp bin/cli-proxy-api "${OUT_PATH}"
chmod +x "${OUT_PATH}"

SIZE=$(ls -lh "${OUT_PATH}" | awk '{print $5}')
echo "✅ Updated cli-proxy-api (${SIZE}) from commit ${COMMIT_HASH}"

echo "🧹 Cleaning up"
rm -rf "${WORKDIR}"

echo "Done."
