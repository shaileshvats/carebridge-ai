# Screenshots

All of these come from the real running application on AI Hub Community 2027.1.0AI.109.0 (ARM64), on 2026-11-04, with synthetic data. None is a mock-up. Only the application viewport was captured: no browser address bar, credentials or local paths.

| # | File | Shows | Source |
|---|---|---|---|
| 1 | `overview-live.jpg` | Dashboard overview after a LIVE run: counts read from IRIS, exceptions by type, agent governance | Dashboard, LIVE mode (local Qwen3-4B-Instruct-2507) |
| 2 | `architecture-production.png` | Production architecture | Rendered from the Mermaid source in README.md (Mermaid 10.9.1) |
| 3 | `agent-tool-calls-live.jpg` | Exception detail: the agent run with model, tokens, reason, evidence and its two read-only tool calls with results | Message trace, LIVE run |
| 4a | `policy-gate-unsafe-action.jpg` | Policy gate rejecting an unsafe recommendation (ACCEPT on an identity conflict), with every rule | Message trace, REPLAY adversarial fixture |
| 4b | `human-decision-refused.jpg` | Human review: a reviewer's ACCEPT refused because the patient is still unregistered | Message trace, REPLAY |
| 5a | `agent-activity-live.jpg` | Agent activity: every run with mode, model, duration, reported tokens, tool count and policy verdict | Dashboard, LIVE runs |
| 5b | `message-trace-live.jpg` | One message's original HL7, findings and audit timeline | Message trace, LIVE run |
