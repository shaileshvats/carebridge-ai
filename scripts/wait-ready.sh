#!/usr/bin/env bash
# Wait until the CareBridge API reports a running production (no fixed sleeps).
set -euo pipefail
URL="${1:-http://localhost:52773/api/carebridge/health}"
for i in $(seq 1 120); do
  if curl -fsS "$URL" 2>/dev/null | grep -q '"productionRunning":1'; then echo "CareBridge is ready"; exit 0; fi
  sleep 2
done
echo "CareBridge did not become ready in time" >&2; exit 1
