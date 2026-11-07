# Contest application (prepared for the owner)

**Contest:** InterSystems Programming Contest: AI Agents in Interoperability Workflows
**Deadline (re-checked 2026-11-04):** submissions close Nov 8, 2026, 23:59 EST. Voting runs Nov 9–15, 2026, 23:59 EST.
**How to apply** ([docs](https://docs.openexchange.intersystems.com/contest/apply/)): publish the app on Open Exchange, then use **Apply** on the contest page or the app's Contest tab. An organizer said OEX approval isn't required before the deadline, but the app must work.

## Application summary (paste into the OEX description / contest application)

**CareBridge AI** is an InterSystems IRIS for Health interoperability production in which an **IRIS AI Hub agent makes routing decisions for hospital lab-result exceptions**, and a **deterministic policy gate controls what the production executes**.

- **What it does.**
  - A simulated LIS sends HL7 ORU^R01 results over MLLP, and a simulated HIS keeps the patient/order registry current with ADT and ORM.
  - The `LabResultRouter` business process stores each original immutably and validates it.
  - On an exception (unknown patient, unknown order, patient/order conflict, duplicate, missing field, receiver outage), it calls the `CareBridge.ExceptionInvestigator` business operation, which runs a `%AI.Agent` with six read-only tools.
  - The agent recommends one permitted action as strict JSON.
- **Why it is an interoperability use case.** The decision sits inside a real message flow: MLLP services and ACKs, a stateful business process waiting on an asynchronous human response, operations for delivery, quarantine and reject ACKs, the **Workflow Engine** for human tasks, and a **custom inbound adapter** for scheduled retries. All of it is visible in the Visual Trace and in an end-to-end audit trail.
- **How the agent participates.**
  - It investigates with tools (patient, order, history, duplicate status, findings), audited and authorized by AI Hub `%AI.Policy` classes.
  - It chooses among real alternatives: suppress a duplicate, reject back to the lab, retry within budget, quarantine, or escalate.
- **How policy enforcement works.** Every recommendation, from the agent or a human, is checked:
  - against the contract;
  - for evidence actually observed;
  - against the action matrix for the exception type;
  - for identity conflicts, which always go to a human;
  - against the retry budget and for duplicate delivery.

  Every rule result is stored. The agent can never ACCEPT a result that has an exception, and invalid output, timeouts or provider errors fall back to manual review.
- **Human review.** Workflow tasks offer only the policy-permitted actions. The reviewer's decision returns to the process and passes the same gate, re-checked against current state.
- **Reproducibility.**
  - Load the AI Hub image, then `docker compose up -d --build`.
  - REPLAY mode runs everything except the model's reply, so no key is needed. LIVE mode works with any AI Hub provider or a local OpenAI-compatible server.
  - 45 tests (37 unit, 8 integration), 11 scenarios and a release QC script, with evidence in the repository.
- **Tested on:** AI Hub Early Access Community **2027.1.0AI.109.0**, IRIS for Health, **ARM64** (Apple M2). Live AI was measured with a local Qwen3-4B-Instruct-2507 model through AI Hub's `openai` provider. x64, build 154 and hosted providers were not tested.

## Links

| Item | URL | Status |
|---|---|---|
| Source (AGPL-3.0) | https://github.com/shaileshvats/carebridge-ai | Public |
| Demo video | https://github.com/shaileshvats/carebridge-ai/raw/v1.0.0/docs/demo/carebridge-demo.mp4 (no-login download) | Ready; YouTube upload optional |
| IPM package | https://openexchange.intersystems.com/package/… (after OEX publication) | Owner submits |
| DC article | after publication | Draft ready |

## Screenshots to attach

- `docs/screenshots/agent-tool-calls-live.jpg`
- `docs/screenshots/policy-gate-unsafe-action.jpg`
- `docs/screenshots/human-decision-refused.jpg`
- `docs/screenshots/agent-activity-live.jpg`
- `docs/screenshots/overview-live.jpg`

## Technology bonuses this entry can claim (if the published list is unchanged)

| Bonus | Evidence |
|---|---|
| Workflow Engine | `CareBridge.ManualReview` (`EnsLib.Workflow.Operation`), Manual review page |
| Custom interoperability adapter | `CareBridge.Adapter.DueWorkInboundAdapter` |
| Docker container | `docker-compose.yml`, `Dockerfile` |
| IPM package | `module.xml` (after publication) |
| DC article | after publication |
| YouTube video | after upload |

## Eligibility and judging risks

- **Build:** the original announcement names build 154, and an organizer's IPM comment says IPM installs will be checked on 154. Build 154 is no longer downloadable, and a later organizer reply says judges will use the build each entry declares. The README declares **109**. The manifest allows `>=2026.3`, but 154 is untested.
- **Video:** the narration is a synthetic voice. That is disclosed in the video description and README.
- **AI assistance:** the code was written with an AI coding assistant. Organizers said disclosure is not required; the README and article disclose it anyway.
