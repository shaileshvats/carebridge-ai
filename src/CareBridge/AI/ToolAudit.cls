/// AI Hub audit policy: records every tool call the agent makes as a CareBridge.Data.ToolCall,
/// linked to the agent run that is in progress in this process.
Class CareBridge.AI.ToolAudit Extends %AI.Policy.Audit
{

Method %LogExecution(call As %DynamicObject, metadata As %DynamicObject, result As %DynamicObject, duration As %Integer, status As %Status) As %Status
{
	Try {
		Set runId = $GET(^||CareBridge.AgentRunId)
		Quit:runId=""
		Set tc = ##class(CareBridge.Data.ToolCall).%New()
		Do tc.AgentRunSetObjectId(runId)
		Set tc.Seq = $INCREMENT(^||CareBridge.ToolSeq)
		Set tc.ToolName = call.name
		Set tc.Arguments = $EXTRACT($SELECT($ISOBJECT(call.arguments):call.arguments.%ToJSON(), 1:call.arguments), 1, 4000)
		Set tc.DurationMs = duration
		Set tc.Success = $$$ISOK(status)
		If $$$ISOK(status) {
			Set tc.ResultSummary = $EXTRACT($SELECT($ISOBJECT(result):result.%ToJSON(), 1:result), 1, 1000)
		} Else {
			Set tc.Error = $EXTRACT($SYSTEM.Status.GetErrorText(status), 1, 2000)
		}
		Do tc.%Save()
	} Catch {}
	Quit $$$OK
}

}
