# Project status

_Last updated: 2026-11-04 (IST), after the release QC_

## Working and verified

- **Environment:** AI Hub 2027.1.0AI.109.0 IRIS for Health community image (ARM64) loaded locally.
- **Docker:** `docker compose up -d --build` from a clean volume. The image installs CareBridge through IPM, the production autostarts and the healthcheck reports healthy.
- **Production:** HIS and LIS MLLP services, router, AI Hub investigator operation, EMR receiver, quarantine, reject notifier, Workflow review and a retry scheduler with a custom adapter.
- **AI Hub agent:** `CareBridge.ExceptionInvestigator` (`%AI.Agent`), with a six-tool read-only `%AI.ToolSet`, an audit policy and an authorization policy.
- **LIVE runs:**
  - Verified with Qwen3-4B-Instruct-2507 (LM Studio) through AI Hub's `openai` provider with `base_url`.
  - Three full runs, the last configured exactly as the README documents. Each: 11/11 scenarios with safe outcomes and 12/12 valid recommendations, about 44,000 prompt and 1,700 completion tokens, 6.7–8.3 s average per agent run.
  - Evidence: `docs/evidence/`.
- **IPM:** a clean install into a bare AI Hub container works in an interop namespace and is refused in a non-interop one (`docs/evidence/ipm-check-*.md`).
- **REPLAY:** 11/11 scenarios give the exact expected outcome, with no model call.
- **Policy gate:** agent and human decisions, every rule persisted.
- **Tests:** 37 unit tests and 8 integration tests (see docs/testing.md and tests/reports).
- **Dashboard:** overview, message explorer with an end-to-end trace, manual review (Workflow), agent activity and demo scenarios.
- **Video:** narrated, 3 min 24 s, recorded from the real application: `docs/demo/carebridge-demo.mp4`.
- **Docs:** README, architecture, AI agent, security, observability, installation, demo scenarios, testing, contest compliance, Open Exchange draft, DC article draft.

## Not done or not verified

- **Owner decisions:** licence, public repository, Open Exchange submission, IPM publication, article publication, YouTube upload. See OWNER_ACTIONS.md.
- **Online demo:** not deployed.
- **Hosted providers:** none tested, because no key was used. OpenAI, Anthropic and Gemini paths go through the same AI Hub provider code, but they are unverified here.
- **x64 image:** untested.
- **IRIS Agentic Dev:** not used.
- **Vector search / RAG bonus:** not implemented.
