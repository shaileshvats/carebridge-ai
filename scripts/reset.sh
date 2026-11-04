#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Shailesh Vats
# Delete demo data and restore the synthetic registry (production keeps running).
set -euo pipefail
curl -fsS -X POST http://localhost:52773/api/carebridge/reset && echo
