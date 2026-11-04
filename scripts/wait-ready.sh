#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Shailesh Vats
# Wait until the CareBridge API reports a running production (no fixed sleeps).
set -euo pipefail
URL="${1:-http://localhost:52773/api/carebridge/health}"
for i in $(seq 1 120); do
  if curl -fsS "$URL" 2>/dev/null | grep -q '"productionRunning":1'; then echo "CareBridge is ready"; exit 0; fi
  sleep 2
done
echo "CareBridge did not become ready in time" >&2; exit 1
