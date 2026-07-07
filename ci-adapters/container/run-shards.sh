#!/usr/bin/env bash
# Container adapter for the visual/e2e suite — no CI vendor, just Docker.
# Runs N shards on the pinned Playwright image (byte-identical to a local bless), then merges the
# blob reports into one HTML report. Usage: SHARD_TOTAL=4 bash ci-adapters/container/run-shards.sh
set -euo pipefail

IMAGE="${PLAYWRIGHT_IMAGE:-mcr.microsoft.com/playwright:vX.Y.Z-jammy}"   # [CONFIGURE] = context.md
SHARD_TOTAL="${SHARD_TOTAL:-4}"                                          # [CONFIGURE] shard count
WORKDIR="$(pwd)"

rm -rf all-blob-reports && mkdir -p all-blob-reports

for i in $(seq 1 "$SHARD_TOTAL"); do
  echo "▶️  shard $i/$SHARD_TOTAL"
  docker run --rm -v "$WORKDIR":/work -w /work \
    -e CI=1 -e SHARD_INDEX="$i" -e SHARD_TOTAL="$SHARD_TOTAL" \
    "$IMAGE" sh -c 'npm ci && npm run test:e2e:ci'
  cp -r blob-report/* all-blob-reports/ 2>/dev/null || true
done

echo "🔀 merging blob reports"
docker run --rm -v "$WORKDIR":/work -w /work "$IMAGE" sh -c 'npm run test:e2e:merge'
echo "✅ report → playwright-report/  ·  bless baselines in the same image: $IMAGE"
