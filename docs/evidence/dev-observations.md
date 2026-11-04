# Development observations (not reproduced by saved evidence files)

These came up during development on 2026-11-04 (same Mac, same AI Hub build). Their database rows were later cleared by demo resets, so there is no per-run JSON. They are reported in the article as observations, not measurements.

| Observation | Detail |
|---|---|
| Gemma 4 E4B (LM Studio) with tools | Every request that included tools failed, both through AI Hub and with a direct `curl` to LM Studio's `/v1/chat/completions`. LM Studio's error said: `Error rendering prompt with jinja template: "Cannot call something that is not a function: got UndefinedValue".` Plain chat without tools worked. |
| Gemma 4 12B (LM Studio) | Not loaded. LM Studio refused: about 7.61 GB needed, and loading "would likely overload your system" while IRIS and another model were running on the 16 GB machine. |
| qwen3:4b (Ollama 0.17.7) through AI Hub | Two investigations. A direct agent call took 129 s, with 1,267 prompt and 2,982 completion tokens, valid on the first attempt. A full production run took 202 s, with 3,076 / 3,839 tokens and two attempts (the first reply failed the contract). AI Hub's session stats showed `total_tool_calls: 0`: the model reasoned at length and never called a tool. |
| Qwen3-4B-Instruct-2507, first direct test | 13.7 s, two tool calls (`LookupOrder`, `LookupPatient`), with 4,755 prompt and 163 completion tokens. |

The full LIVE runs with Qwen3-4B-Instruct-2507 are saved as `agent-usage-*.json`, and the third is also in the QC log.
