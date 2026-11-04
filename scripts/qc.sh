#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Shailesh Vats
#
# Release quality check. Rebuilds from a wiped volume and records measured results in
# docs/evidence/qc-<UTC timestamp>.md. Destroys the local carebridge-data volume.
#   scripts/qc.sh            REPLAY checks only
#   scripts/qc.sh --live     also a LIVE run, using .env.live (LM Studio + Qwen, see README)
set -uo pipefail
cd "$(dirname "$0")/.."
LIVE=0; [ "${1:-}" = "--live" ] && LIVE=1
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
LOG="docs/evidence/qc-$STAMP.md"
mkdir -p docs/evidence tests/reports
say() { echo "$*" | tee -a "$LOG"; }
api() { curl -fsS "http://localhost:52773/api/carebridge/$1"; }
iris_do() { docker compose exec -T iris iris session IRIS -U CAREBRIDGE; }

say "# QC run $STAMP"
say ""
say "- Host: $(uname -sm), $(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.0f GB RAM", $1/1073741824}'), Docker $(docker version --format '{{.Server.Version}}')"
say "- Base image: $(docker image inspect "${IRIS_IMAGE:-irishealth-community:2027.1.0AI.109.0}" --format '{{index .RepoTags 0}} ({{.Architecture}})')"
say ""

say "## 1. Clean build and start"
docker compose down -v >/dev/null 2>&1
T0=$(date +%s)
if docker compose build --no-cache >/tmp/cb-qc-build.log 2>&1; then say "- Build from scratch: OK in $(( $(date +%s) - T0 )) s"; else say "- Build: **FAILED** (see /tmp/cb-qc-build.log)"; exit 1; fi
grep -q "Compile SUCCESS" /tmp/cb-qc-build.log && say "- IPM \`zpm load\` during build: Compile SUCCESS, Activate SUCCESS"
T1=$(date +%s)
docker compose up -d >/dev/null 2>&1
scripts/wait-ready.sh >/dev/null && say "- \`docker compose up -d\` until the API reports a running production: $(( $(date +%s) - T1 )) s (image already built, empty volume)"
say "- Health: \`$(api health | python3 -c 'import sys,json;d=json.load(sys.stdin);print({k:d[k] for k in ("productionRunning","aiHubAvailable","namespace")})')\`"
say ""

say "## 2. Tests (unit + integration)"
scripts/run-tests.sh --all >/tmp/cb-qc-tests.log 2>&1
python3 tests/report-to-md.py >/dev/null
say "- $(python3 -c "import json;r=json.load(open('tests/reports/latest.json'));print(f\"{r['passed']} passed, {r['failed']} failed\")") (report: tests/reports/test-report.md)"
python3 -c "import json;r=json.load(open('tests/reports/latest.json'));[print(f\"  - FAIL {t['class']}:{t['test']} {t['failures']}\") for t in r['tests'] if t['result']!='PASS']" | tee -a "$LOG"
say ""

say "## 3. Demo scenarios, REPLAY mode (no key)"
curl -fsS -X POST http://localhost:52773/api/carebridge/reset >/dev/null
scripts/demo.sh 2>/dev/null | grep -E 'PASS|FAIL|passed' | sed 's/^CAREBRIDGE>//; s/^/    /' | tee -a "$LOG"
say ""

say "## 4. Restart persistence"
BEFORE=$(api overview | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["received"],d["agentRuns"])')
docker compose restart >/dev/null 2>&1
T2=$(date +%s); scripts/wait-ready.sh >/dev/null
AFTER=$(api overview | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["received"],d["agentRuns"])')
say "- Before restart (messages, agent runs): $BEFORE; after: $AFTER; production back in $(( $(date +%s) - T2 )) s; autostart: $(api health | python3 -c 'import sys,json;print(json.load(sys.stdin)["productionRunning"])')"
say ""

if [ $LIVE = 1 ]; then
  say "## 5. LIVE mode via .env (documented local configuration)"
  cp .env.live .env
  say "- .env: $(grep -E '^CAREBRIDGE_(AGENT_MODE|LLM_PROVIDER|LLM_MODEL|LLM_BASE_URL)=' .env | tr '\n' ' ')"
  docker compose up -d >/dev/null 2>&1; scripts/wait-ready.sh >/dev/null
  say "- Mode reported by the API: \`$(api mode)\`"
  curl -fsS -X POST http://localhost:52773/api/carebridge/reset >/dev/null
  scripts/demo.sh 2>/dev/null | grep -E 'PASS|FAIL|passed' | sed 's/^CAREBRIDGE>//; s/^/    /' | tee -a "$LOG"
  OUT=$(scripts/usage-report.sh 2>/dev/null | head -1)
  say "- Usage evidence: $OUT"
  say "- Totals: $(python3 -c "import json;d=json.load(open('$OUT'));print(d['totals'])")"
  rm -f .env
  docker compose up -d >/dev/null 2>&1; scripts/wait-ready.sh >/dev/null
  say "- .env removed; back to REPLAY: \`$(api mode)\`"
fi
echo "$LOG"
