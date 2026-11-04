# Limitations

What CareBridge AI does not do, and what has not been verified. If something is not listed under "Verified" in [testing.md](testing.md) or [evidence](evidence/), treat it as untested.

## Platform and environment

| Item | Status |
|---|---|
| AI Hub Community **2027.1.0AI.109.0**, IRIS for Health, **ARM64** (Apple M2, 16 GB, Docker 29) | Tested |
| x64 image of the same build | **Untested.** The tag is the same and nothing in the code is architecture-specific, but no run has been made |
| Build 154 (2026.3.0AI), named in the original announcement and in an organizer's IPM comment | **Untested.** It is no longer downloadable from the EAP portal. The manifest's `Version=">=2026.3"` admits it, but AI Hub APIs changed between builds |
| Plain IRIS (not for Health) community image | **Untested.** IPM is not bundled in that image, so `iris.script` would need the IPM installer step |
| Kubernetes, Windows, non-Docker installs | Untested |

## AI models

- LIVE mode was measured only with local models on one Mac:
  - **Qwen3-4B-Instruct-2507** in LM Studio: 2 full runs, all replies valid.
  - **qwen3:4b** in Ollama: works, but it didn't call tools and took 129–202 s per case.
- **Gemma 4 E4B** in LM Studio failed when tools were included in the request: the chat template raised a Jinja error. It can't be used for tool calling in that setup.
- **No hosted provider was tested** (OpenAI, Anthropic, Gemini, Bedrock), because no key was used. The code path is AI Hub's own provider abstraction, but it is unverified here. Behaviour and cost will differ.
- Local-model results say nothing about the accuracy of other models. A model may pick a different safe action. In LIVE runs Qwen often chose QUARANTINE where the scripted replies chose MANUAL_REVIEW. The policy gate bounds what can happen, not what the model prefers.
- With temperature unset, repeated LIVE runs may differ.

## Scope

- One workflow: HL7 v2 ORU^R01 lab results, with six exception types. Other message types are not routed. The HIS feed handles only ADT^A04/A08/A28 and ORM^O01 (NW and CA).
- The HL7 parser is deliberately minimal (fields CareBridge validates). It doesn't process escape sequences, multiple OBR groups, or repeating PID-3 beyond the first repetition.
- Patient matching is exact MRN only. There is no probabilistic matching, and the agent is forbidden to attempt it.
- The three "systems" (HIS, LIS, EMR) are simulations in the same container.

## Security and operations

- **Synthetic data only.** Not for real patient data, not clinically validated, and no HIPAA or other regulatory claim.
- The dashboard and REST API are **unauthenticated** demo web applications (role-limited to the CareBridge database and SQL read grants). Compose binds them to `127.0.0.1`.
- Reviewer identities (`reviewer.demo`, `lab.supervisor`) are synthetic Workflow users. There is no login.
- `iris.script` un-expires the image's default passwords, which is only appropriate for a development container.
- No public online demo is deployed.
- Demo **reset** deletes audit events. That is intended for demo data only; in normal operation audit events cannot be updated or deleted.

## Evidence

- Timings come from one laptop with other software running. They are indicative, not benchmarks.
- Token counts are exactly what AI Hub's `session.GetStats()` reported. Nothing is estimated or priced.
- REPLAY results show that the production and the policy gate behave correctly. They say nothing about model quality.

## Not used

- IRIS Agentic Dev was not used in this build.
- Vector search / AI Hub RAG, Embedded Python and PEX are not used.
