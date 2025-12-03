#!/bin/bash

set -euo pipefail

# Fetch and rebuild the CLIProxyAPI binary from the upstream repo, apply any
# local patches we need, then drop it into src/Sources/Resources/cli-proxy-api
# for bundling.

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

# Apply local patches (documented)
# 1) Add xhigh reasoning_effort for Codex Max (router-for-me/CLIProxyAPI#355)
TARGET_FILE="internal/translator/openai/openai/responses/openai_openai-responses_request.go"
if [ -f "$TARGET_FILE" ] && ! grep -q 'reasoning_effort", "xhigh"' "$TARGET_FILE"; then
  echo "🩹 Applying patch: add xhigh reasoning_effort (PR 355)"
  patch -p1 -l <<'PR355'
diff --git a/internal/translator/openai/openai/responses/openai_openai-responses_request.go b/internal/translator/openai/openai/responses/openai_openai-responses_request.go
index 69bc9f7..efaa8a1 100644
--- a/internal/translator/openai/openai/responses/openai_openai-responses_request.go
+++ b/internal/translator/openai/openai/responses/openai_openai-responses_request.go
@@ -199,6 +199,8 @@ func ConvertOpenAIResponsesRequestToOpenAIChatCompletions(modelName string, inpu
  		case "medium":
  			out, _ = sjson.Set(out, "reasoning_effort", "medium")
  		case "high":
  			out, _ = sjson.Set(out, "reasoning_effort", "high")
+ 		case "xhigh":
+ 			out, _ = sjson.Set(out, "reasoning_effort", "xhigh")
  		default:
  			out, _ = sjson.Set(out, "reasoning_effort", "auto")
  		}
  	}

PR355
else
  echo "ℹ️  Patch already present or target file missing; skipping patch"
fi

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
