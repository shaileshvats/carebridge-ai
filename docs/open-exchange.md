# Open Exchange listing (draft for the owner to submit)

**Name:** CareBridge AI

**Short description (one line):**
Hospital lab-result interoperability where an IRIS AI Hub agent investigates HL7 exceptions and a deterministic policy gate governs every action.

**Repository:** https://github.com/shaileshvats/carebridge-ai *(make public first)*

**Category:** Technology Example / Solution
**InterSystems technology:** InterSystems IRIS for Health, Interoperability, AI Hub, IPM, Docker
**Industry:** Healthcare
**Tags:** AI, Interoperability, HL7, Healthcare, Workflow, Docker, IPM, Contest
**Contest:** InterSystems Programming Contest: AI Agents in Interoperability Workflows
**Build:** AI Hub Early Access Community 2027.1.0AI.109.0 (IRIS for Health). Tested on ARM64 (Apple M2); the x64 image has the same tag but is untested
**Publish in Package Manager:** yes (package name `carebridge-ai`)
**Licence URL:** *(the LICENSE file once the owner approves one)*
**Demo / video / article links:** *(add when published)*

## Long description

A laboratory sends an HL7 ORU^R01 result. CareBridge receives it on an MLLP business service and registers an immutable copy with a correlation id. It then validates the result against the synthetic HIS registry. Clean results are delivered to the simulated clinical record system.

When something is wrong, the `CareBridge.ExceptionInvestigator` IRIS AI Hub agent investigates with six read-only tools and recommends one of the permitted actions:

- **Unknown patient or unknown order.** The agent may hold, reject or escalate the result, but must not guess an identity.
- **Duplicate.** The agent may suppress it.
- **Missing required field.** The agent may reject it back to the laboratory with an MSA|AR ACK.
- **Patient/order conflict.** The case always goes to a human.
- **Downstream outage.** The agent may retry within the retry budget.

A deterministic policy gate validates every recommendation before anything happens. It checks:

- the output contract
- that every evidence code was actually observed
- the action matrix (the agent can never ACCEPT)
- identity rules, the retry budget and duplicate delivery

Human reviewers work through the Interoperability **Workflow Engine**. Their decisions pass through the same gate and are re-checked against current state.

Every step is audited and visible in the dashboard: findings, the agent's tool calls, token counts, raw output, each policy rule, and the timeline. It also appears in the Visual Trace.

**Features**

- Real production: HL7 TCP services for HIS and LIS, a business process, five business operations, the Workflow Engine, and a custom inbound adapter for scheduled retries.
- AI Hub agent built from a `%AI.Agent` subclass, a `%AI.ToolSet`, `%AI.Tool` and two `%AI.Policy` classes (audit and authorization).
- REPLAY mode with no API key. Only the model's reply is recorded; everything else runs for real.
- LIVE mode with any AI Hub provider, or a local OpenAI-compatible server (LM Studio or Ollama).
- 11 demo scenarios, including prompt injection, unsafe actions, malformed output and a persistent outage.
- 37 unit tests and 8 integration tests through the running production.
- `docker compose up` setup, and an IPM module with `SystemRequirements`.
- Synthetic data only.

**Installation:** see the README. Load the EAP image, then run `docker compose up -d --build`.
