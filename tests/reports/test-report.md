# Test report

- **Run:** 2026-11-04 05:34:05 → 2026-11-04 05:35:16 (UTC)
- **Environment:** IRIS for UNIX (Ubuntu Server LTS for ARM64 Containers) 2027.1.0AI (Build 109U) Fri Oct 30 2026 16:32:20 EDT
- **Agent mode during tests:** REPLAY (integration tests force REPLAY for determinism)
- **Result:** 45 passed, 0 failed

| Class | Test | Expected | Result | Duration (s) | Failures |
|---|---|---|---|---|---|
| HL7Parser | TestAcceptsLineFeedsAndMLLPFraming | Fields parsed / framing tolerated / non-HL7 rejected / hash semantics | PASS | 0.002 |  |
| HL7Parser | TestContentHashIgnoresControlIdButNotValues | Fields parsed / framing tolerated / non-HL7 rejected / hash semantics | PASS | 0.001 |  |
| HL7Parser | TestParsesCoreFields | Fields parsed / framing tolerated / non-HL7 rejected / hash semantics | PASS | 0.001 |  |
| HL7Parser | TestRejectsNonHL7 | Fields parsed / framing tolerated / non-HL7 rejected / hash semantics | PASS | 0.000 |  |
| Recommendation | TestEvidenceAndFlagTypesEnforced | Contract enforced exactly | PASS | 0.001 |  |
| Recommendation | TestExtraFieldsRejected | Contract enforced exactly | PASS | 0.000 |  |
| Recommendation | TestFencedJsonIsAccepted | Contract enforced exactly | PASS | 0.000 |  |
| Recommendation | TestInvalidJsonRejected | Contract enforced exactly | PASS | 0.000 |  |
| Recommendation | TestUnknownActionRejected | Contract enforced exactly | PASS | 0.000 |  |
| Recommendation | TestValidRecommendation | Contract enforced exactly | PASS | 0.000 |  |
| Recommendation | TestWrongExceptionTypeRejected | Contract enforced exactly | PASS | 0.000 |  |
| Validator | TestDemographicMismatchIsIdentityConflict | Correct findings and primary exception type | PASS | 0.067 |  |
| Validator | TestDuplicateContentAlreadyDelivered | Correct findings and primary exception type | PASS | 0.001 |  |
| Validator | TestDuplicateControlId | Correct findings and primary exception type | PASS | 0.000 |  |
| Validator | TestInstructionTextIsFlaggedNotObeyed | Correct findings and primary exception type | PASS | 0.000 |  |
| Validator | TestMissingObservationValue | Correct findings and primary exception type | PASS | 0.000 |  |
| Validator | TestMissingPatientIdentifier | Correct findings and primary exception type | PASS | 0.000 |  |
| Validator | TestPatientOrderConflict | Correct findings and primary exception type | PASS | 0.000 |  |
| Validator | TestUnknownOrder | Correct findings and primary exception type | PASS | 0.000 |  |
| Validator | TestUnknownPatient | Correct findings and primary exception type | PASS | 0.000 |  |
| Validator | TestValidResultHasNoException | Correct findings and primary exception type | PASS | 0.000 |  |
| PolicyGate | TestAgentCannotAccept | Unsafe or unsupported actions refused; safe fallback | PASS | 0.024 |  |
| PolicyGate | TestApprovesGroundedPermittedAction | Unsafe or unsupported actions refused; safe fallback | PASS | 0.001 |  |
| PolicyGate | TestEvaluationIsPersisted | Unsafe or unsupported actions refused; safe fallback | PASS | 0.001 |  |
| PolicyGate | TestHumanAcceptRechecksPatientExists | Unsafe or unsupported actions refused; safe fallback | PASS | 0.000 |  |
| PolicyGate | TestHumanNeedsNoteAndPermittedAction | Unsafe or unsupported actions refused; safe fallback | PASS | 0.001 |  |
| PolicyGate | TestHumanReviewFlagMustBeConsistent | Unsafe or unsupported actions refused; safe fallback | PASS | 0.001 |  |
| PolicyGate | TestIdentityConflictRequiresHuman | Unsafe or unsupported actions refused; safe fallback | PASS | 0.000 |  |
| PolicyGate | TestNoRecommendationFallsBackSafely | Unsafe or unsupported actions refused; safe fallback | PASS | 0.001 |  |
| PolicyGate | TestRetryLimitEnforced | Unsafe or unsupported actions refused; safe fallback | PASS | 0.001 |  |
| PolicyGate | TestUngroundedEvidenceRejected | Unsafe or unsupported actions refused; safe fallback | PASS | 0.000 |  |
| Safety | TestAgentInputExcludesFreeTextNamesAndValues | Immutability, append-only audit, data minimisation | PASS | 0.001 |  |
| Safety | TestAuditIsAppendOnly | Immutability, append-only audit, data minimisation | PASS | 0.017 |  |
| Safety | TestDeliveredContentIsUnique | Immutability, append-only audit, data minimisation | PASS | 0.069 |  |
| Safety | TestOriginalMessageIsImmutable | Immutability, append-only audit, data minimisation | PASS | 0.048 |  |
| Safety | TestPermittedActionsMatchPolicy | Immutability, append-only audit, data minimisation | PASS | 0.001 |  |
| Safety | TestReplayFixturesCoverEveryExceptionType | Immutability, append-only audit, data minimisation | PASS | 0.002 |  |
| Integration | TestAdversarialRecommendationsAreBlocked | End-to-end behaviour through the running production | PASS | 12.245 |  |
| Integration | TestConflictGoesToWorkflow | End-to-end behaviour through the running production | PASS | 5.131 |  |
| Integration | TestDuplicateIsSuppressedAndDeliveredOnce | End-to-end behaviour through the running production | PASS | 11.131 |  |
| Integration | TestExceptionInvokesAgentAndPolicy | End-to-end behaviour through the running production | PASS | 5.201 |  |
| Integration | TestHumanReviewAfterLateRegistration | End-to-end behaviour through the running production | PASS | 9.162 |  |
| Integration | TestMissingFieldIsRejectedToLIS | End-to-end behaviour through the running production | PASS | 2.085 |  |
| Integration | TestRetryAfterDownstreamFailure | End-to-end behaviour through the running production | PASS | 22.806 |  |
| Integration | TestValidResultIsDeliveredWithoutAgent | End-to-end behaviour through the running production | PASS | 2.081 |  |
