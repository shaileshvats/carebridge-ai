#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Shailesh Vats
#
# Installs the CareBridge IPM module into a fresh container started from the bare AI Hub image
# (no Dockerfile, no CareBridge build) and records the result in docs/evidence/ipm-check-<UTC>.md:
#   1. a namespace WITHOUT interoperability must refuse the module (SystemRequirements),
#   2. an interoperability namespace must install it, start the production and route a real message.
set -uo pipefail
cd "$(dirname "$0")/.."
IMAGE="${IRIS_IMAGE:-irishealth-community:2027.1.0AI.109.0}"
NAME=carebridge-ipm-check
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
LOG="docs/evidence/ipm-check-$STAMP.md"
say() { echo "$*" | tee -a "$LOG"; }
sess() { docker exec -i "$NAME" iris session IRIS -U "$1"; }

docker rm -f "$NAME" >/dev/null 2>&1
docker run -d --name "$NAME" "$IMAGE" >/dev/null
until docker exec "$NAME" iris qlist 2>/dev/null | grep -q running; do sleep 2; done

# Module sources only: what IPM would fetch from the repository.
docker exec -u root "$NAME" mkdir -p /tmp/pkg
docker cp module.xml "$NAME":/tmp/pkg/module.xml
docker cp src "$NAME":/tmp/pkg/src
docker cp web "$NAME":/tmp/pkg/web
docker exec -u root "$NAME" chown -R irisowner:irisowner /tmp/pkg
docker exec -u irisowner "$NAME" bash -c 'mkdir -p /tmp/db/ipmtest /tmp/db/nointerop && cat > /tmp/ns.cpf <<EOF
[Actions]
CreateDatabase:Name=IPMTEST,Directory=/tmp/db/ipmtest
CreateNamespace:Name=IPMTEST,Globals=IPMTEST,Routines=IPMTEST,Interop=1
CreateDatabase:Name=NOINTEROP,Directory=/tmp/db/nointerop
CreateNamespace:Name=NOINTEROP,Globals=NOINTEROP,Routines=NOINTEROP,Interop=0
EOF
iris merge IRIS /tmp/ns.cpf' >/dev/null 2>&1

say "# IPM install check $STAMP"
say ""
say "- Image: $IMAGE ($(docker image inspect "$IMAGE" --format '{{.Architecture}}')), fresh container, no CareBridge build"
IPMV=$(sess HSLIB <<'EOF' 2>&1 | grep -o 'zpm.*0\.[0-9.]*' | head -1
do ##class(%IPM.Main).Shell("enable -map -globally")
do ##class(%IPM.Main).Shell("version")
halt
EOF
)
say "- IPM: $(echo "$IPMV" | sed 's/\x1b\[[0-9;]*m//g')"
say ""

say "## 1. Namespace without interoperability (expected: refused)"
OUT=$(sess NOINTEROP <<'EOF' 2>&1
do ##class(%IPM.Main).Shell("load /tmp/pkg/ -v")
write "CLASSES=",##class(%Dictionary.CompiledClass).%ExistsId("CareBridge.Production"),!
halt
EOF
)
echo "$OUT" | sed 's/\x1b\[[0-9;]*m//g' | grep -i -E 'interop|requirement|ERROR' | head -3 | sed 's/^/    /' | tee -a "$LOG"
echo "$OUT" | grep -q 'CLASSES=0' && say "- Result: refused, nothing installed" || say "- Result: **NOT refused** (unexpected)"
say ""

say "## 2. Interoperability namespace (expected: installs and routes a message)"
OUT=$(sess IPMTEST <<'EOF' 2>&1
do ##class(%IPM.Main).Shell("load /tmp/pkg/ -v")
write "START=",##class(CareBridge.Setup.Installer).StartProduction(),!
set r=##class(CareBridge.Demo.Runner).RunScenario("valid-result",60) write "SCENARIO=",r.outcome,!
set r=##class(CareBridge.Demo.Runner).RunScenario("unknown-order",60) write "SCENARIO2=",r.outcome,!
halt
EOF
)
echo "$OUT" | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'Compile (SUCCESS|FAILURE)|Activate (SUCCESS|FAILURE)|CareBridge installed|START=|SCENARIO' | sed 's/^/    /' | tee -a "$LOG"
WEB=$(docker exec "$NAME" bash -c 'exec 3<>/dev/tcp/127.0.0.1/52773; printf "GET /api/carebridge/health HTTP/1.0\r\n\r\n" >&3; cat <&3' | tail -1)
say "- Web application /api/carebridge/health inside the container: \`$WEB\`"
say ""
docker rm -f "$NAME" >/dev/null
echo "$LOG"
