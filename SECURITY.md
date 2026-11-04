# Security policy

CareBridge AI is a demonstration with synthetic data. Do not connect it to real patient systems or use it with real patient data.

## Reporting a vulnerability

Please report security problems privately through GitHub's **Report a vulnerability** button on this repository's Security tab (private vulnerability reporting). Don't open a public issue. Include steps to reproduce and the build you used. Expect an acknowledgement within a few days. This is a single-maintainer project with no formal SLA.

## Supported versions

| Version | Supported |
|---|---|
| 1.x on AI Hub Community 2027.1.0AI.109.0 | Yes |
| Anything else | Best effort |

## What to know before deploying

- The dashboard and REST API are **unauthenticated** demo applications. Compose publishes every port on `127.0.0.1` only. Before exposing anything, put `/carebridge/` and `/api/carebridge/` behind authentication, never expose `/csp/sys/` or port 1972, and set `CAREBRIDGE_LOCK_MODE=1`.
- `iris.script` un-expires the image's default passwords for development convenience. Don't use the image as-is outside a development machine.
- Model keys belong in `.env`, which is git-ignored. The API reports whether a key is configured but never its value.

Design-level controls are described in [docs/security.md](docs/security.md): agent containment, the policy gate, data minimisation, immutability and the append-only audit.
