# Contest compliance

Contest: **InterSystems Programming Contest: AI Agents in Interoperability Workflows**. Submissions close Nov 8, 2026, 23:59 EST; voting runs Nov 9–15.
Sources:

- [Contest announcement and comments](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows)
- [Technology bonuses](https://community.intersystems.com/post/technology-bonuses-intersystems-programming-contest-ai-agents-interoperability-workflows)
- [What experts look for](https://community.intersystems.com/post/what-experts-look-contest-entries)

## Requirements

| Requirement | How CareBridge meets it | Status |
|---|---|---|
| IRIS interoperability workflow that uses an IRIS AI Hub agent for a decision-making task | `CareBridge.Production`. The `CareBridge.ExceptionInvestigator` `%AI.Agent` decides the routing outcome for exceptions, governed by the policy gate | Done, verified on build 109 |
| Use the AI Hub Community build | 2027.1.0AI.109.0 IRIS for Health community image. An organizer comment names 109 as the newest release and asks entrants to state their build | Done |
| Fully functional, original | 11 scenarios run through the production; 37 unit and 8 integration tests | Done |
| Starts with `docker compose up` | `docker compose up -d --build` after loading the EAP image (README) | Done |
| Don't push the AI Hub image or derived images | Built locally as `carebridge-ai:local`; nothing pushed | Done |
| Source on GitHub or GitLab, open source | Repository prepared. Licence and public visibility wait for the owner's approval | **Owner action** |
| English README with installation and a demo or workflow description | README.md, docs/ | Done |
| README states the EAP image, build, load and retag steps, LLM provider and key variable, start and check commands | README "Install" and "Configure live AI"; docs/installation.md | Done |
| Published on IPM, with `SystemRequirements Version=">=2026.3" Interoperability="enabled"` | `module.xml` declares it. Installed with `zpm load` during the Docker build. Publication goes through Open Exchange ("Publish in Package Manager") | Manifest done; **owner submits** |
| Submitted to Open Exchange and applied to the contest | Listing text prepared in docs/open-exchange.md | **Owner action** |

## Technology bonuses (from the published list, which may change)

| Bonus | Points | Status in CareBridge |
|---|---|---|
| Workflow Engine | 2 | Used: manual review is `EnsLib.Workflow.Operation` / `TaskRequest`, and decisions come back through `OnResponse` |
| Custom interoperability adapter | 2 | Used: `CareBridge.Adapter.DueWorkInboundAdapter` |
| Docker container | 2 | Used |
| IPM package | 2 | Manifest ready; counts once published |
| Online demo | 2 | Not deployed (needs hosting; a static recording does not qualify) |
| First DC article | 2 | Draft in docs/article/; publish needs the owner |
| YouTube video | 3 | Needs recording and upload |
| Vector Search | 2 | Not used |
| Embedded Python | 3 | Not used |
| PEX (Java/.NET) | 3 | Not used |
| Community Opportunity idea | 4 | Not claimed |
| Bug reports | 2–3 | None filed |
| Questionnaire | 1 | Owner |

Bonuses were adopted only where they are part of the design: Workflow for human tasks, the adapter for retries. Nothing was added just to collect points.

## Recommended DC article topics (from the announcement)

| Topic | Where the evidence is |
|---|---|
| AI Hub experience | docs/article/dev-community-article.md, from the actual build log (OutputToString, IPM mapping, reserved words, LM Studio template failure) |
| Models and costs | Token counts from `AgentRun`. Local models cost nothing. Hosted-provider cost is not claimed because none was used |
| Observability and tracing | docs/observability.md |
| IRIS Agentic Dev | Not used, and the article says so: the session used the IPM shell and `iris session` directly |
