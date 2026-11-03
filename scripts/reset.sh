#!/usr/bin/env bash
# Delete demo data and restore the synthetic registry (production keeps running).
set -euo pipefail
curl -fsS -X POST http://localhost:52773/api/carebridge/reset && echo
