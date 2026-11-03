# Decisions

Each entry: the decision, why, and what it rules out. Newest last.

## D1. Target build: AI Hub Community 2027.1.0AI.109.0, IRIS for Health, ARM64 and x64
The organizer's latest clarification on the contest announcement says build 109 "is the newest release" and that judges will use the build each entry declares. The EAP portal (checked 2026-11-04) lists only 2027.1 builds; the 2026.3.0AI builds were removed. We use `irishealth_arm64-community-2027.1.0AI.109.0` on the owner's M2 Mac; the x64 file has the same tag. Community images include a private web server, so the dashboard and REST API are served by IRIS itself.

## D2. The image is never pushed anywhere
Organizers asked that the AI Hub image and anything built on it stay off public registries. Compose builds `carebridge-ai:local` from a Dockerfile whose `FROM` is the locally loaded image; `.gitignore` excludes `*.tar.gz` and `*.key`.

## D3. Custom ObjectScript business process instead of BPL
The router needs a loop (investigate, policy, execute, possibly re-deliver and investigate again), an async Workflow call whose answer must pass the policy gate, and precise audit writes at each step. A code-based `Ens.BusinessProcess` keeps that readable and unit-testable. Every hop is still a real Interoperability message (visible in the Visual Trace).

## D4. The agent runs inside a Business Operation
`CareBridge.ExceptionInvestigator` (the `%AI.Agent` subclass) is invoked by the `CareBridge.ExceptionInvestigator` business operation. That gives the agent call its own queue, timeout, message trace entry and settings, and keeps the process free of provider details.

## D5. The agent never gets ACCEPT
The policy gate's agent matrix does not contain ACCEPT for any exception type. A result with an open exception reaches the clinical record only through a human decision (Workflow Engine) that also passes the gate. This is stricter than "the agent may accept with high confidence"; confidence is not evidence.

## D6. Evidence must be grounded
Every evidence code in a recommendation must appear in the case's deterministic findings. This blocks invented evidence, including evidence suggested by injected text.

## D7. Free text and result values never reach the model
`ContextBuilder` sends identifiers, codes, presence flags and findings only. NTE text is reduced to `freeTextPresent`, names are omitted, OBX values are replaced by `hasValue`. Prompt injection in HL7 notes therefore cannot reach a live model; the replay `prompt-injection` fixture still tests the gate as if it had.

## D8. Replay mode is a deterministic agent adapter, not a mock workflow
REPLAY executes the same production, the same read-only lookups (recorded tool plan, real results), the same contract validator and the same policy gate. Only the model's reply text is recorded. The dashboard and every AgentRun row label the mode.

## D9. Manual review uses the Interoperability Workflow Engine
`CareBridge.ManualReview` is an `EnsLib.Workflow.Operation`; review tasks are `EnsLib.Workflow.TaskRequest`s for the role of the same name. The decision returns to the router's `OnResponse`, so human decisions are governed exactly like agent ones. (This is also a listed contest technology bonus, but it was chosen because it is the platform's own mechanism for handing work to people.)

## D10. Retries use a custom inbound adapter
`CareBridge.Adapter.DueWorkInboundAdapter` polls the work queue for due RETRY items and claims each before dispatch. This keeps delayed retries inside the production (no sleeping process) and survives restarts because the queue is persistent.

## D11. Live AI defaults to a local OpenAI-compatible endpoint during development
AI Hub's `openai` provider accepts `base_url`, so development used Gemma 4 E4B in LM Studio on the owner's Mac (no API cost). Judges can set any AI Hub provider and key in `.env`. No key is ever committed; `/mode` never returns the key.

## D12. Single database for the namespace
`CAREBRIDGE` holds code and data, so the IPM `${dbrole}` grants the web applications exactly the access they need, and the database lives on a Docker volume.

## D13. Licence: pending owner approval
The contest requires an open-source repository. OSI-approved licences (including Apache-2.0 and MIT) allow commercial use and resale; none of them prevents someone selling the work. Apache-2.0 is proposed for its explicit patent grant. No LICENSE file is published until the owner approves (see OWNER_ACTIONS.md).
