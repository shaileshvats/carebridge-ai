# Observability and tracing

Every message can be followed from receipt to final action through one correlation id (`CB-YYYYMMDD-nnnnnn`), which is printed on every row that concerns it.

## What is recorded

| Record | Written by | Content |
|---|---|---|
| `AuditEvent` | Router, operations, policy gate, reviewers | RECEIVED, VALIDATED / VALIDATION_FAILED, EXCEPTION_RAISED, AGENT_INVOKED, AGENT_RESPONDED / AGENT_FAILED, POLICY_EVALUATED, ACTION_EXECUTING, DELIVERED / DELIVERY_FAILED, RETRY_SCHEDULED / RETRY_DUE / RETRY_STARTED, QUARANTINED, REJECT_NOTICE_SENT, REVIEW_REQUESTED, REVIEW_DECISION, COMPLETED |
| `AgentRun` | `CareBridge.ExceptionInvestigator` operation | agent name, mode, provider, model, start and end, duration, attempts, prompt and completion tokens (when reported), sanitised input, raw output, validated recommendation, outcome, errors |
| `ToolCall` | `CareBridge.AI.ToolAudit` (AI Hub `%AI.Policy.Audit`), `ToolGuard` denials, replay adapter | tool, arguments, result (first 1000 characters), duration, success, ALLOWED/DENIED |
| `PolicyEvaluation` | Policy gate | source (AGENT or HUMAN), recommended action, every rule with pass/fail and detail, final action |
| Interoperability message trace | IRIS | every hop as a real message; `MessageRecord.SessionId` links to the Visual Trace |

## Where to see it

- Dashboard → **Message explorer** → a message: original HL7, findings, context, every agent run (tool calls, input, raw output), every policy evaluation, the audit timeline and execution.
- Dashboard → **Agent activity**: one row per agent run, with mode, provider and model, duration, tokens, tool count, outcome and the policy verdict.
- Management Portal → Interoperability → Message Viewer / Visual Trace for the session id.

## Tokens and cost

Token counts come from `%AI.Agent.Session.GetStats()` (`total_prompt_tokens`, `total_completion_tokens`). If the provider does not report them, the fields stay empty and the dashboard shows "not reported". CareBridge does not estimate tokens or price them. Replay runs have no tokens.

## AI Hub native tracing

The AI Hub build used here provides audit and authorization policy hooks on tool execution, and session statistics; CareBridge uses both. CareBridge did not find a separate trace store or monitoring UI for agents in this build. Its trace is therefore application-level, kept in IRIS tables and linked to the Interoperability message trace.
