# Implementation plan

Priorities follow the build directive: P0 before P1 before P2.

| # | Item | Priority | Status |
|---|---|---|---|
| 1 | AI Hub 109 IRIS for Health image running locally (ARM64) | P0 | Done |
| 2 | Interoperability production: HIS/LIS MLLP services, router, operations | P0 | Done |
| 3 | AI Hub agent with read-only toolset, audit and authorization policies | P0 | Done; LIVE verified with local models |
| 4 | Deterministic policy gate (agent and human) | P0 | Done |
| 5 | End-to-end synthetic workflow, 11 scenarios | P0 | Done (REPLAY 11/11, LIVE 11/11) |
| 6 | Replay mode without an API key | P0 | Done |
| 7 | Tests: unit, integration, adversarial | P0 | Done (37 unit + 8 integration) |
| 8 | Docker Compose: clean build, healthcheck, volume, readiness script | P0 | Done |
| 9 | README | P0 | Done |
| 10 | Dashboard: overview, explorer, trace, review, agent activity, scenarios | P1 | Done |
| 11 | Observability: AgentRun, ToolCall, PolicyEvaluation, AuditEvent, usage report | P1 | Done |
| 12 | IPM module with SystemRequirements | P1 | Done (installed via `zpm load` in the build); publication is the owner's |
| 13 | GitHub repository | P1 | Private repo pushed; public after licence approval |
| 14 | Open Exchange listing | P1 | Draft ready; submission is the owner's |
| 15 | Developer Community article | P2 | Draft ready |
| 16 | Demo video | P2 | Script ready; recording pending |
| 17 | Online demo | P2 | Not started (needs hosting approval) |
| 18 | Vector search over past resolutions | P2 | Not started |
