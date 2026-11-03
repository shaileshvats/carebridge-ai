# The AI Hub agent: CareBridge.ExceptionInvestigator

## What it decides

When deterministic validation raises an exception, the agent investigates it and recommends one routing outcome. The outcome is chosen from the actions the policy allows for that exception type:

| Exception type | Actions the agent may recommend | What a person may choose afterwards |
|---|---|---|
| UNKNOWN_PATIENT | MANUAL_REVIEW, QUARANTINE, REJECT | ACCEPT (only if the patient now exists), QUARANTINE, REJECT |
| UNKNOWN_ORDER | MANUAL_REVIEW, QUARANTINE, REJECT | ACCEPT, QUARANTINE, REJECT |
| DUPLICATE_RESULT | DUPLICATE_SUPPRESSED, MANUAL_REVIEW | ACCEPT (only if not already delivered), DUPLICATE_SUPPRESSED, REJECT |
| MISSING_REQUIRED_FIELDS | REJECT, QUARANTINE, MANUAL_REVIEW | QUARANTINE, REJECT |
| PATIENT_ORDER_CONFLICT | MANUAL_REVIEW | ACCEPT, QUARANTINE, REJECT |
| DOWNSTREAM_UNAVAILABLE | RETRY (within the retry budget), QUARANTINE, MANUAL_REVIEW | RETRY, QUARANTINE, REJECT |

These are real choices: hold a message, send it back to the lab, suppress it, retry it, or find an owner for it. The agent never gets ACCEPT. A result with an open exception reaches the clinical record only after a person decides and the policy gate approves.

## Implementation

`CareBridge.ExceptionInvestigator` extends `%AI.Agent`:

- `Parameter TOOLSETS = "CareBridge.AI.InvestigationToolSet"`.
- `XData INSTRUCTIONS` holds the rules and the output contract.
- `%OnInit()` creates the provider with `%AI.Provider.Create(provider, settings)` from environment variables.

`CareBridge.AI.Investigator.Run()` runs one case:

1. `%New()`, then `%Init()`.
2. Attach the audit policy (`CareBridge.AI.ToolAudit`) and the authorization policy (`CareBridge.AI.ToolGuard`) to `ToolManager`.
3. `CreateSession({"max_iterations":8, "max_tokens":700})`, then `Chat(session, prompt)`.
4. Validate the reply against the contract. If it fails, send one corrective message per attempt, up to 3 attempts in the same session.
5. Read `session.GetStats()` for `total_prompt_tokens` and `total_completion_tokens`.

## Tools (read-only)

| Tool | Returns |
|---|---|
| `LookupPatient(mrn)` | found, birth date, sex, evidence code. Never names. |
| `LookupOrder(placerOrderNumber)` | found, the order's MRN, test code, status |
| `OrdersForPatient(mrn)` | the patient's orders, for context only |
| `MessageHistory(correlationId)` | recent messages for the same patient or order, with outcomes |
| `DuplicateStatus(correlationId)` | whether the control id was seen before, whether the same content was delivered, whether this is a correction |
| `ValidationFindings(correlationId)` | the recorded findings, delivery attempts used, the maximum allowed |

There is no tool that writes, executes SQL text, reads files, runs commands or calls out of the namespace. `ToolGuard` denies anything else, and records the denial as a `ToolCall` marked DENIED.

## Input (minimum necessary)

`CareBridge.Engine.ContextBuilder` sends:

- the exception type
- message identifiers: control id, MRN, placer and filler order numbers, test code, result status
- observation codes, with `hasValue` flags instead of values
- the deterministic findings and the list of observed evidence codes
- delivery attempts and the retry budget
- `permittedActions`

It does not send patient names or result values. It also does not send free-text notes; NTE text becomes `freeTextPresent: true`.

## Output contract

```json
{
  "exception_type": "UNKNOWN_ORDER",
  "recommended_action": "MANUAL_REVIEW",
  "reason": "The referenced order could not be located.",
  "evidence": ["ORDER_NOT_FOUND", "PATIENT_FOUND"],
  "requires_human_review": true
}
```

`CareBridge.Engine.Recommendation.Validate` requires all five fields with the right types. It allows no extra fields except a numeric `confidence`, which is informational and never used. It also requires an action from the enum and an `exception_type` that matches the case.

## Modes

| Mode | What runs |
|---|---|
| LIVE | The real `%AI.Agent`, with a provider and model from `.env`. |
| REPLAY | `CareBridge.Engine.ReplayAgent` stands in for the model. It runs a scripted tool plan against the real lookups, then puts a scripted, hand-written reply through the same validator and policy gate. No key is needed. |

Set the mode with `CAREBRIDGE_AGENT_MODE`, or from the dashboard unless `CAREBRIDGE_LOCK_MODE` is set. Every `AgentRun` records its mode, provider and model.

## Provider configuration

| Variable | Meaning |
|---|---|
| `CAREBRIDGE_LLM_PROVIDER` | Any AI Hub provider name: `openai`, `anthropic`, `gemini`, … (default `openai`) |
| `CAREBRIDGE_LLM_MODEL` | Model id |
| `CAREBRIDGE_LLM_BASE_URL` | Optional OpenAI-compatible endpoint, e.g. LM Studio `http://host.docker.internal:1234/v1` |
| `CAREBRIDGE_LLM_API_KEY` | Key. Falls back to `OPENAI_API_KEY`, `ANTHROPIC_API_KEY` or `GEMINI_API_KEY` |
| `CAREBRIDGE_LLM_TIMEOUT` | Seconds per model request (default 120) |
| `CAREBRIDGE_LLM_TEMPERATURE` | Optional; left unset by default because some models reject an explicit temperature |

The key is passed to `%AI.Provider.Create` and is never stored, logged or returned by the API.
