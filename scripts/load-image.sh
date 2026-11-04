#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Shailesh Vats
# Load the AI Hub image you downloaded from the EAP portal and tag it with the name the Dockerfile expects.
# Usage: scripts/load-image.sh ~/Downloads/irishealth_arm64-community-2027.1.0AI.109.0-docker.tar.gz
set -euo pipefail
TARBALL="${1:?path to the downloaded *-docker.tar.gz}"
TAG="${2:-irishealth-community:2027.1.0AI.109.0}"
LOADED=$(docker image load -i "$TARBALL" | sed -n 's/^Loaded image: //p' | tail -1)
[ -n "$LOADED" ] || { echo "Could not determine the loaded image name; run 'docker images' and tag it manually." >&2; exit 1; }
docker tag "$LOADED" "$TAG"
echo "Loaded $LOADED and tagged it $TAG"
