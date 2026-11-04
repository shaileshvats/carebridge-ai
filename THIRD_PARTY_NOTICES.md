# Third-party notices

CareBridge AI is licensed under the GNU Affero General Public License v3.0 only (AGPL-3.0-only); see [LICENSE](LICENSE). The licence covers the original CareBridge AI code and documentation in this repository. It does not change the licence of anything listed below.

## Included or adapted material

| Material | Where | Licence |
|---|---|---|
| Docker build pattern (start IRIS, merge a CPF, run a terminal script, `zpm load`) adapted from [intersystems-community/ai-hub-dev-template](https://github.com/intersystems-community/ai-hub-dev-template) | `Dockerfile`, `merge.cpf`, `iris.script` | MIT (notice below) |
| Contributor Covenant 2.1 | `CODE_OF_CONDUCT.md` | CC BY 4.0, attribution included in the file |
| GNU AGPL-3.0 licence text | `LICENSE` | Verbatim copying permitted by the Free Software Foundation |

### MIT licence of ai-hub-dev-template

```
MIT License

Copyright (c) 2019 InterSystems Developer Community

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Required at runtime, not included in this repository

| Component | Licence | Notes |
|---|---|---|
| InterSystems IRIS for Health Community Edition with AI Hub (Early Access build 2027.1.0AI.109.0) | Proprietary InterSystems terms (Early Access Program) | You download it yourself from the EAP portal. It is never redistributed, and no image built on it is published. CareBridge classes extend IRIS and AI Hub classes such as `Ens.BusinessProcess` and `%AI.Agent`; those platform classes are not covered by the AGPL. |
| ObjectScript Package Manager (IPM), shipped inside the IRIS for Health image | MIT | Used to install the module |
| Optional: a local model server (LM Studio, Ollama) and model weights such as Qwen3-4B-Instruct-2507 | Each under its own licence (Qwen3 weights: Apache-2.0) | Not included; configured by the user |
| Optional: a hosted LLM provider (OpenAI, Anthropic, Gemini, …) | Provider terms | Not included; configured by the user with their own key |

The tools in `tools/video` (Chrome DevTools recorder, AVFoundation encoder and muxer, narration script) were written for this project's owner and are licensed under AGPL-3.0-only with the rest of the repository.
