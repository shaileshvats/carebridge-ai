/// Runs CareBridge.ExceptionInvestigator for one case (LIVE mode), with bounded corrective retries
/// for output that does not match the recommendation contract.
Class CareBridge.AI.Investigator Extends %RegisteredObject
{

Parameter MAXATTEMPTS = 3;

/// Returns {outcome, recommendation, rawOutput, attempts, problems, promptTokens, completionTokens, provider, model}
ClassMethod Run(run As CareBridge.Data.AgentRun, input As %DynamicObject) As %DynamicObject
{
	Set out = {"outcome":"PROVIDER_ERROR", "recommendation":"", "rawOutput":"", "attempts":0, "problems":[]}
	Set cfg = ##class(CareBridge.ExceptionInvestigator).ProviderSettings()
	Set out.provider = cfg.provider, out.model = cfg.model
	Try {
		Set agent = ##class(CareBridge.ExceptionInvestigator).%New()
		$$$ThrowOnError(agent.%Init())
		Do agent.ToolManager.SetAuditPolicy(##class(CareBridge.AI.ToolAudit).%New())
		Do agent.ToolManager.SetAuthPolicy(##class(CareBridge.AI.ToolGuard).%New())
		Set sessionCfg = {"max_iterations":8, "max_tokens":700}
		Set temp = ##class(CareBridge.ExceptionInvestigator).Setting("LLMTemperature", "CAREBRIDGE_LLM_TEMPERATURE", "")
		If temp '= "" Do sessionCfg.%Set("temperature", +temp, "number")
		Set session = agent.CreateSession(sessionCfg)
		Set prompt = ##class(CareBridge.Engine.ContextBuilder).Prompt(input)
		For attempt = 1:1:..#MAXATTEMPTS {
			Set out.attempts = attempt
			Set response = agent.Chat(session, prompt)
			Set text = response.Content
			Set out.rawOutput = text
			Set sc = ##class(CareBridge.Engine.Recommendation).Validate(text, input.exceptionType, .rec, .problems)
			Set out.problems = problems
			If $$$ISOK(sc) {
				Set out.outcome = "OK", out.recommendation = rec
				Quit
			}
			Set out.outcome = "INVALID_OUTPUT"
			Set prompt = "Your reply was rejected by the CareBridge contract validator: "_problems.%ToJSON()_
				". Reply again with only the JSON object, using only permittedActions and evidenceCodesObserved."
		}
		Set stats = session.GetStats()
		If $ISOBJECT(stats) {
			Set out.promptTokens = stats."total_prompt_tokens"
			Set out.completionTokens = stats."total_completion_tokens"
		}
	} Catch ex {
		Set msg = ex.DisplayString()
		Set out.error = msg
		Set out.outcome = $SELECT(($ZCONVERT(msg, "L") [ "timeout") || ($ZCONVERT(msg, "L") [ "timed out"):"TIMEOUT", 1:"PROVIDER_ERROR")
	}
	Quit out
}

}
