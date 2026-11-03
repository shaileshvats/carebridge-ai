# Demo video script

Target length is about 4 minutes. Every shot is real application footage, driven by `tools/video/record.mjs` in headless Chrome against the running container. The captions double as the transcript.

| Time | Shot | Caption (transcript) |
|---|---|---|
| 0:00 | Title card | CareBridge AI: hospital interoperability and exception management. Synthetic data only. |
| 0:08 | Title card: the problem | A lab result can be valid HL7 and still be unsafe to route: unknown patient, unknown order, wrong patient, duplicate, missing field, receiver down. |
| 0:20 | Architecture card | The LIS and HIS send HL7 over MLLP into an IRIS interoperability production. On an exception, an IRIS AI Hub agent investigates; a deterministic policy gate decides what the production may do. |
| 0:40 | Dashboard overview (REPLAY) | Every number on the dashboard is read from IRIS. REPLAY mode: real production, real tools, real policy gate; only the agent's reply is scripted. |
| 0:50 | Scenarios → run *valid-result* | A clean ORU^R01 arrives over MLLP. No exception, so no agent: it is delivered to the EMR. |
| 1:05 | Message trace of the valid result | Every message gets a correlation id, an immutable copy and an audit timeline. |
| 1:15 | Switch to LIVE (local Qwen3-4B via AI Hub) | LIVE mode: the AI Hub agent calls a local model through the openai provider. No API cost. |
| 1:25 | Run *unknown-order* | The patient exists, but the order number does not. |
| 1:40 | Trace: agent run, tool calls | The agent looked up the order and the patient with read-only tools… |
| 1:55 | Trace: recommendation + policy rules | …and recommended an action, with evidence. The policy gate checks the contract, the evidence, the action matrix, identity and retry rules. |
| 2:15 | Switch to REPLAY, run *unsafe-action* | Adversarial fixture: a "model" proposes merging patient records, then accepting. |
| 2:30 | Trace: contract rejections + policy rejection | The contract validator rejects the merge; the gate rejects ACCEPT. The case goes to a person. |
| 2:45 | Run *unknown-patient* → Manual review | Unknown patients are never guessed. The case becomes a Workflow Engine task. |
| 3:00 | Reviewer chooses ACCEPT | A reviewer tries to accept… |
| 3:10 | Trace: HUMAN decision rejected | …but the policy gate refuses: the patient is still not registered. |
| 3:20 | Register patient from HIS, accept again | The HIS sends the registration (ADT^A04). The same decision is now approved and the result is delivered. |
| 3:40 | Agent activity | Every agent run: mode, model, duration, tokens as reported by AI Hub, tool calls, policy verdict. |
| 3:55 | End card | Docker Compose, IPM package, 37 unit + 8 integration tests. github.com/shaileshvats/carebridge-ai |
