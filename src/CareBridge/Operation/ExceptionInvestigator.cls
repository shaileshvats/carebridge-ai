/// Business Operation that runs the CareBridge.ExceptionInvestigator AI Hub agent for one case and
/// records the run (mode, provider, model, timing, tokens, tool calls, raw and validated output).
/// Mode LIVE calls the real agent; REPLAY uses CareBridge.Engine.ReplayAgent. The active mode is
/// ^CareBridge.Config("AgentMode"), else env CAREBRIDGE_AGENT_MODE, else the DefaultMode setting.
Class CareBridge.Operation.ExceptionInvestigator Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

Property DefaultMode As %String(VALUELIST = ",REPLAY,LIVE") [ InitialExpression = "REPLAY" ];

Parameter SETTINGS = "DefaultMode:Basic";

ClassMethod ActiveMode(default As %String = "REPLAY") As %String
{
	Set m = $GET(^CareBridge.Config("AgentMode"))
	If m = "" Set m = $ZCONVERT($SYSTEM.Util.GetEnviron("CAREBRIDGE_AGENT_MODE"), "U")
	Quit $SELECT((m = "LIVE") || (m = "REPLAY"):m, 1:default)
}

/// 1 if the AI Hub classes and the compiled agent are present in this instance.
ClassMethod LiveAvailable() As %Boolean
{
	Quit ##class(%Dictionary.CompiledClass).%ExistsId("%AI.Agent") && ##class(%Dictionary.CompiledClass).%ExistsId("CareBridge.ExceptionInvestigator")
}

Method Investigate(pRequest As CareBridge.Msg.InvestigationRequest, Output pResponse As CareBridge.Msg.InvestigationResponse) As %Status
{
	Set pResponse = ##class(CareBridge.Msg.InvestigationResponse).%New()
	Set mode = ..ActiveMode(..DefaultMode)
	Set input = {}.%FromJSON(pRequest.InputPayload)

	Set run = ##class(CareBridge.Data.AgentRun).%New()
	Set run.CorrelationId = pRequest.CorrelationId
	Do run.ExceptionCaseSetObjectId(pRequest.CaseId)
	Set run.Mode = mode
	Set run.InputPayload = pRequest.InputPayload
	Set run.StartedAt = $ZDATETIME($ZTIMESTAMP, 3)
	Set sc = run.%Save()
	Quit:$$$ISERR(sc) sc
	Set ^||CareBridge.AgentRunId = run.%Id(), ^||CareBridge.ToolSeq = 0
	Set t0 = $ZHOROLOG

	If mode = "LIVE" {
		If ..LiveAvailable() {
			Set result = $CLASSMETHOD("CareBridge.AI.Investigator", "Run", run, input)
		} Else {
			Set result = {"outcome":"NOT_AVAILABLE", "error":"IRIS AI Hub classes are not available in this instance", "attempts":0, "problems":[], "rawOutput":"", "provider":"", "model":""}
		}
	} Else {
		Set result = ##class(CareBridge.Engine.ReplayAgent).Run(run, input, pRequest.Scenario)
	}

	Kill ^||CareBridge.AgentRunId
	Set run.EndedAt = $ZDATETIME($ZTIMESTAMP, 3)
	Set run.DurationMs = ($ZHOROLOG - t0) * 1000 \ 1
	Set run.Provider = result.provider
	Set run.Model = result.model
	Set run.Attempts = result.attempts
	Set run.Outcome = result.outcome
	Set run.RawOutput = $EXTRACT(result.rawOutput, 1, 30000)
	Set run.Error = $EXTRACT($SELECT(result.%IsDefined("error"):result.error, result.problems.%Size()>0:result.problems.%ToJSON(), 1:""), 1, 4000)
	If result.%IsDefined("promptTokens") && (result.promptTokens '= "") Set run.PromptTokens = result.promptTokens
	If result.%IsDefined("completionTokens") && (result.completionTokens '= "") Set run.CompletionTokens = result.completionTokens
	If $ISOBJECT(result.recommendation) {
		Set run.Recommendation = result.recommendation.%ToJSON()
		Set run.RecommendedAction = result.recommendation."recommended_action"
	} ElseIf result.rawOutput '= "" {
		// Keep what the model asked for even when the reply failed the contract (shown in the trace).
		Set raw = ##class(CareBridge.Engine.Recommendation).ExtractJSON(result.rawOutput)
		If $ISOBJECT(raw) Set run.RecommendedAction = $EXTRACT(raw.%Get("recommended_action"), 1, 40)
	}
	Set sc = run.%Save()
	Quit:$$$ISERR(sc) sc

	Set pResponse.AgentRunId = run.%Id()
	Set pResponse.Outcome = result.outcome
	Set pResponse.Mode = mode
	If $ISOBJECT(result.recommendation) {
		Set pResponse.Recommendation = run.Recommendation
		Set pResponse.RecommendedAction = run.RecommendedAction
	}
	Quit $$$OK
}

XData MessageMap
{
<MapItems>
	<MapItem MessageType="CareBridge.Msg.InvestigationRequest">
		<Method>Investigate</Method>
	</MapItem>
</MapItems>
}

}
