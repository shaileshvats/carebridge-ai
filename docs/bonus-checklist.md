# Contest bonus checklist

Source: [Technology Bonuses](https://community.intersystems.com/post/technology-bonuses-intersystems-programming-contest-ai-agents-interoperability-workflows), re-checked 2026-11-07. The page says the list is subject to change.

| Bonus | Points | Requirement (quoted or summarised from the source) | CareBridge status |
|---|---|---|---|
| Workflow Engine | 2 | "include the usage of the Workflow Engine in your interoperability production" | **Met.** `CareBridge.ManualReview` (`EnsLib.Workflow.Operation`); review decisions return to `LabResultRouter.OnResponse` |
| Custom Interoperability Adapter | 2 | "develop your own custom inbound or outbound adapter and use it in production" | **Met.** `CareBridge.Adapter.DueWorkInboundAdapter` used by `CareBridge.RetryScheduler` |
| Docker container usage | 2 | "uses InterSystems IRIS running in a Docker container" | **Met.** `docker-compose.yml`, `Dockerfile` |
| ZPM/IPM package deployment | 2 | "build and publish the ZPM package for your application" | **Pending.** `module.xml` is built and verified with a clean install; publishing happens when the Open Exchange app (with "Publish in Package Manager" ticked) is approved |
| Video | 3 | Upload to "a storage service from which we can download it without registration". The organizer asked YouTube entrants to also "share a downloadable version" | **Ready.** No-login download, verified byte-identical: https://github.com/shaileshvats/carebridge-ai/raw/v1.0.0/docs/demo/carebridge-demo.mp4. Also on YouTube: https://www.youtube.com/watch?v=w-1bHYc1eEM. Both links are in the Open Exchange draft (Demo URL, YouTube URL) |
| First DC article | 2 | "a brand new article on Developer Community that describes the features of your project and how to work with it" | **Published** 2026-11-07: https://community.intersystems.com/post/carebridge-ai-building-governed-hospital-interoperability-agent-intersystems-iris-ai-hub. New-member posts are held for moderation before they are publicly visible |
| Second article | 1 | Another article or a translation | Not done |
| Online demo | 2 | "uploading your project to the cloud as an online demo" (a static recorded demo does not qualify) | **Not done.** It needs a paid VM able to run the EAP image, which isn't approved. The local reproduction path is in the README |
| Questionnaire | 1 | "Share your feedback in the questionnaire" | **Done** by the owner (2026-11-07) |
| Vector Search | 2 | Use vector search | Not used (not added just for points) |
| Embedded Python | 3 | Use Embedded Python | Not used |
| PEX (Java/.NET) | 3 | Use PEX with Java or .NET | Not used |
| Community Opportunity idea | 4 | Implement an Ideas Portal idea with "Community Opportunity" status | Not claimed |
| Bug reports (AI Hub / Embedded Python) | 2+1 | Reproducible bugs filed in the bug-report repos | None filed |

If the pending items are completed: Workflow 2 + adapter 2 + Docker 2 + IPM 2 + video 3 + article 2 = **13 points**, plus 1 for the questionnaire.
