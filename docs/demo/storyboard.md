# Storyboard

The video is recorded by `tools/video/record.mjs` (headless Chrome driving the real dashboard), encoded by `tools/video/encode.swift`, and narrated by `tools/video/narrate.py` using macOS `say` (a synthetic voice).

| # | Segment | Source | Mode badge |
|---|---|---|---|
| 1 | Title, problem and architecture cards | `tools/video/cards.html` | none |
| 2 | Overview → run *valid-result* → message trace | Live dashboard | REPLAY |
| 3 | Switch to LIVE → *unknown-order* → findings, agent run with tool calls, policy rules | Live dashboard, local Qwen3-4B through AI Hub | LIVE |
| 4 | Back to REPLAY → *unsafe-action* → refused attempts, policy rejection | Live dashboard, adversarial fixture | REPLAY · adversarial |
| 5 | *unknown-patient* → Workflow task → ACCEPT refused → HIS registration → ACCEPT approved → delivered | Live dashboard | REPLAY |
| 6 | Agent activity | Live dashboard | none |
| 7 | End card | `cards.html` | none |

Waiting for the agent or the retry scheduler is sped up in the recording. The encoder labels sped-up frames in the corner badge.

To reproduce:

```bash
node tools/video/record.mjs /tmp/cb-frames /tmp/cb-manifest.json
python3 tools/video/narrate.py /tmp/cb-manifest.json /tmp/cb-vo
swiftc -O tools/video/encode.swift -o /tmp/encode
/tmp/encode /tmp/cb-vo/manifest-narrated.json /tmp/silent.mp4 1280 800
afconvert -f m4af -d aac -b 32000 /tmp/cb-vo/narration.wav /tmp/cb-vo/narration.m4a
swiftc -O tools/video/mux.swift -o /tmp/mux
/tmp/mux /tmp/silent.mp4 /tmp/cb-vo/narration.m4a docs/demo/carebridge-demo.mp4
```
