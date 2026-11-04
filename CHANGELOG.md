# Changelog

## 1.0.0 (2026-11-04)

First public release, for the InterSystems Programming Contest "AI Agents in Interoperability Workflows".

### Added
- Interoperability production with:
  - HIS (ADT/ORM) and LIS (ORU) MLLP services
  - the `LabResultRouter` business process
  - the `CareBridge.ExceptionInvestigator` AI Hub agent (six read-only tools, audit and authorization policies)
  - a deterministic policy gate for agent and human decisions
  - EMR receiver, quarantine and LIS reject-ACK operations
  - Workflow Engine manual review
  - a retry scheduler using a custom inbound adapter
- REPLAY mode (scripted agent replies, no key) and LIVE mode (any AI Hub provider, or a local OpenAI-compatible server).
- Dashboard: overview, message explorer with an end-to-end trace, manual review, agent activity and demo scenarios.
- 11 scenarios (7 core, 4 adversarial or failure), 37 unit tests, 8 integration tests, the `scripts/qc.sh` release check and an agent usage report.
- Docker Compose setup and an IPM module with `SystemRequirements`.
- Narrated demo video, recorded from the running application.
- Licensed under AGPL-3.0-only.

### Fixed during development (before the first release)
- HL7 re-serialisation passed the wrong separators.
- The immutability check gave false positives on stream properties.
- The idempotency index was unique, which made a resent control id unregistrable.
- Reserved SQL words broke the trace queries.
- The retry due time was computed incorrectly, so retries ran immediately.
