# Security and privacy

CareBridge AI is a contest demonstration with synthetic data. It is not certified for clinical use and makes no HIPAA or other regulatory compliance claim.

## Data
- Every patient, order and result value is fictional. Patients are named `SYNTHETIC^<word>`; MRNs follow the `MRN1000nn` and `MRN9xxxxx` patterns.
- No real hospital, LIS or EMR is ever contacted. The three "systems" are MLLP clients and production components inside one container.

## What reaches a model provider (LIVE mode only)
Per investigation, the agent receives the sanitised case built by `CareBridge.Engine.ContextBuilder`:
- message identifiers, codes and flags
- validation findings
- the permitted actions

It does not receive names, result values or free text. Tool results add only:
- birth date and sex (to check identity)
- order numbers and test codes
- message statuses

REPLAY mode sends nothing anywhere. With a local OpenAI-compatible server (LM Studio, Ollama), nothing leaves the machine.

## Secrets
- Keys come from environment variables (`.env`, git-ignored). `.env.example` contains placeholders only.
- `GET /api/carebridge/mode` returns the provider, model and endpoint, plus a `keyConfigured` boolean, never the key.
- No key, token or password is written to any CareBridge table or log.

## Agent containment
- The agent has six read-only tools (`CareBridge.AI.InvestigationTools`). None accepts SQL, paths or commands.
- `CareBridge.AI.ToolGuard` (an AI Hub authorization policy) denies any other tool name and records the attempt.
- Model output is untrusted. It is parsed as data, validated against a strict contract and then evaluated by the deterministic policy gate. Invalid output, timeouts and provider errors lead to manual review, never to an automatic action.
- Prompt injection: free text in HL7 messages is never sent to the model. Instruction-like text is flagged (`SUSPICIOUS_FREE_TEXT`) and treated as data.

## Integrity
- The original message is immutable after receipt (`MessageRecord.%OnBeforeSave`).
- Audit events cannot be updated, and cannot be deleted outside an explicit demo reset.
- The EMR receiver refuses a second copy of identical content (unique index), so no retry or duplicate can deliver twice.

## Web exposure
- Compose publishes ports on `127.0.0.1` only.
- The dashboard and REST API are unauthenticated demo applications limited to the `CAREBRIDGE` database role. The Management Portal uses the image's default credentials. A public deployment should expose only `/carebridge/` and `/api/carebridge/` through a reverse proxy, never `/csp/sys/` or the superserver, and set `CAREBRIDGE_LOCK_MODE=1`.
- The container unexpires default passwords for local development (`iris.script`). Do not use this image as-is outside a development machine.

## Reporting
Please report security issues privately to the repository owner rather than in a public issue.
