#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Shailesh Vats
# Run unit tests, or unit + integration tests with --all. Writes tests/reports/latest.json.
set -euo pipefail
cd "$(dirname "$0")/.."
INTEGRATION=0; [ "${1:-}" = "--all" ] && INTEGRATION=1
mkdir -p tests/reports
docker compose exec -T iris iris session IRIS -U CAREBRIDGE <<EOS
set r=##class(CareBridge.Test.Runner).Run($INTEGRATION,"/home/irisowner/carebridge/test-report.json")
halt
EOS
docker compose cp iris:/home/irisowner/carebridge/test-report.json tests/reports/latest.json >/dev/null
python3 -c "import json;r=json.load(open('tests/reports/latest.json'));print(f\"{r['passed']} passed, {r['failed']} failed\");exit(1 if r['failed'] else 0)"
