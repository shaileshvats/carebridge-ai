# Testing

All tests are ObjectScript `%UnitTest` classes in `src/CareBridge/Test`. They run inside the container against the real namespace. `CareBridge.Test.Runner` executes them without loading files from disk and writes a JSON report.

```bash
scripts/run-tests.sh          # unit tests
scripts/run-tests.sh --all    # unit + integration (the production must be running; resets demo data)
scripts/demo.sh               # every demo scenario through the production
```

The report is written to `tests/reports/latest.json`, with one row per test: class, test, PASS/FAIL, duration and failure messages. It also records the IRIS version, agent mode and timestamps.

## Suites

| Class | Kind | Covers |
|---|---|---|
| `CareBridge.Test.HL7Parser` | Unit | ER7 field extraction, LF and MLLP framing, non-HL7 input, content hash ignores control id but not values |
| `CareBridge.Test.Recommendation` | Unit | Contract: valid output, fenced JSON, invalid and truncated JSON, unknown action (`merge_patient_records`), extra fields (`patient_update`), wrong exception type, evidence and flag types |
| `CareBridge.Test.Validator` | Unit | Valid result; unknown patient and order; patient/order conflict; demographic mismatch; missing PID-3 and OBX-5; duplicate control id; duplicate delivered content; instruction-like NTE flagged |
| `CareBridge.Test.PolicyGate` | Unit | Grounded permitted action approved; agent cannot ACCEPT; ungrounded evidence rejected; identity conflict needs a human; retry budget; TIMEOUT, INVALID_OUTPUT and PROVIDER_ERROR fall back safely; inconsistent `requires_human_review`; evaluation persisted; human note, permitted action and current patient state |
| `CareBridge.Test.Safety` | Unit | Raw message immutable; audit append-only; agent input excludes free text, names and values; permitted actions match policy; replay fixtures cover every exception type; receiver refuses duplicate content |
| `CareBridge.Test.Integration` | Integration (MLLP → production) | Valid result delivered with no agent call; exception invokes agent, tools and policy with a complete audit; duplicate delivered once; missing field rejected to the LIS; conflict becomes a Workflow task; retry after a downstream failure, honouring the delay; adversarial recommendations blocked; human review before and after late registration |

## Failure tests and where they are covered

| Failure | Covered by |
|---|---|
| AI provider timeout | `PolicyGate:TestNoRecommendationFallsBackSafely` (TIMEOUT); router treats a missing response as TIMEOUT |
| Malformed AI output | `Recommendation:TestInvalidJsonRejected`; `malformed-output` scenario; `Integration:TestAdversarialRecommendationsAreBlocked` |
| Missing context / fields | `Validator:TestMissingPatientIdentifier`, `TestMissingObservationValue`; `missing-field` scenario |
| Duplicate delivery | `Safety:TestDeliveredContentIsUnique`; `Integration:TestDuplicateIsSuppressedAndDeliveredOnce` |
| Downstream receiver unavailable, repeated retry | `Integration:TestRetryAfterDownstreamFailure`; `persistent-outage` scenario (retry budget enforced) |
| Prompt injection in HL7 text | `Validator:TestInstructionTextIsFlaggedNotObeyed`; `Safety:TestAgentInputExcludesFreeTextNamesAndValues`; `prompt-injection` scenario |
| IRIS restart | Verified 2026-11-04: `docker compose restart` → `scripts/wait-ready.sh`; production autostarted, all 23 messages and 21 agent runs still present |

## Results

See [tests/reports/test-report.md](../tests/reports/test-report.md) for the latest recorded run (date, build and per-test results).
