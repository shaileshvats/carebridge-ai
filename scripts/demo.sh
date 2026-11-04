#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Shailesh Vats
# Run every demo scenario through the production and print the result table.
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose exec -T iris iris session IRIS -U CAREBRIDGE <<'EOS'
do ##class(CareBridge.Demo.Runner).Demo()
halt
EOS
