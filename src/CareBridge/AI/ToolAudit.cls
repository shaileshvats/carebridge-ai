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
			Set tc.ResultSummary = $EXTRACT(..Unwrap(result), 1, 1000)
		} Else {
			Set tc.Error = $EXTRACT($SYSTEM.Status.GetErrorText(status), 1, 2000)
		}
		Do tc.%Save()
	} Catch {}
	Quit $$$OK
}

/// AI Hub hands the audit policy {"tool_name":..., "result_json":"<JSON string>"}, and our tools themselves
/// return JSON strings, so the useful result can be encoded twice. Unwrap to the tool's own JSON.
ClassMethod Unwrap(result) As %String
{
	Set v = result
	If $ISOBJECT(v) && v.%IsDefined("result_json") Set v = v."result_json"
	For i = 1:1:3 {
		Quit:$ISOBJECT(v)
		// Wrapping in an array lets one parser handle objects, arrays and JSON-encoded strings alike.
		Set parsed = ""
		Try { Set parsed = [].%FromJSON("["_v_"]").%Get(0) } Catch {}
		Quit:parsed=""
		Set v = parsed
	}
	Quit $SELECT($ISOBJECT(v):v.%ToJSON(), 1:v)
}

}
