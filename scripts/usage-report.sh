#!/usr/bin/env bash
# Export agent usage (per run and totals, as reported by AI Hub) to docs/evidence/agent-usage-<UTC timestamp>.json
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p docs/evidence
OUT="docs/evidence/agent-usage-$(date -u +%Y%m%dT%H%M%SZ).json"
docker compose exec -T iris iris session IRIS -U CAREBRIDGE <<'EOS' >/dev/null
do ##class(CareBridge.Demo.Report).Export("/home/irisowner/carebridge/agent-usage.json")
halt
EOS
docker compose cp iris:/home/irisowner/carebridge/agent-usage.json "$OUT" >/dev/null
python3 -m json.tool "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
echo "$OUT"
python3 -c "import json,sys;d=json.load(open('$OUT'));[print(t) for t in d['totals']]"
