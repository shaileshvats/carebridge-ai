# Blockers

| Blocker | Impact | Workaround / next step |
|---|---|---|
| Licence not yet approved by the owner | The repository can't be made public, so the contest's open-source requirement isn't met yet | Owner approves Apache-2.0 (or another OSI licence); then add LICENSE and make the repo public |
| Open Exchange, IPM publication and the contest application need the owner's accounts | Not submitted | Listing text is ready in docs/open-exchange.md |
| No public online demo | No online-demo bonus | Needs a host that can run the EAP image (paid VM), and owner approval to spend |
| Gemma 4 E4B in LM Studio fails with tools (chat template error) | That model can't be used for live tool calling | Use Qwen3-4B-Instruct-2507 (verified) or any hosted AI Hub provider |
| IRIS Agentic Dev plugin not installed | Not used for this build | Its Claude Code plugin installs through interactive `/plugin` commands, which weren't available in this session |
