# YouTube upload (owner action)

- **File:** `docs/demo/carebridge-demo.mp4` (1280×800 H.264 with AAC narration, 3 min 24 s)
- **Captions file:** `docs/demo/carebridge-demo.srt` (upload as English subtitles)
- **Thumbnail:** `docs/demo/poster.jpg`
- **Visibility:** Public or Unlisted, as you prefer. The contest bonus asks for a video showing the product in action.

## Title
CareBridge AI: an IRIS AI Hub agent governed by a policy gate in a hospital HL7 workflow

## Description
CareBridge AI is my entry for the InterSystems Programming Contest "AI Agents in Interoperability Workflows".

A simulated laboratory sends HL7 v2 results to an InterSystems IRIS for Health interoperability production. When a result can't be routed safely (unknown patient, unknown order, wrong patient, duplicate, missing field, receiver down), an IRIS AI Hub agent investigates with six read-only tools and recommends an action. A deterministic policy gate decides whether that action may run. Human decisions go through the IRIS Workflow Engine and the same gate.

All footage is from the real running application, driven by a script in headless Chrome. Badges mark REPLAY (scripted agent replies) and LIVE (a local Qwen3-4B-Instruct model through AI Hub) segments. Waits are sped up. The narration is a synthetic voice. All data is synthetic.

Tested on AI Hub Early Access Community build 2027.1.0AI.109.0, IRIS for Health, ARM64.

Source (AGPL-3.0): https://github.com/shaileshvats/carebridge-ai

Chapters
0:00 CareBridge AI
0:08 The problem
0:20 Architecture
0:37 Dashboard and a clean result
1:00 LIVE: AI Hub agent investigates an unknown order
1:39 Adversarial test: unsafe recommendation blocked
2:06 Human review with the Workflow Engine
3:04 Agent activity and tokens
3:13 Install and test

## Tags
InterSystems, IRIS, IRIS for Health, AI Hub, interoperability, HL7, healthcare IT, AI agent, LLM, policy, Workflow Engine, Qwen, LM Studio, ObjectScript, Docker
