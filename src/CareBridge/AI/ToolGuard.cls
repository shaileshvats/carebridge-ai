/// AI Hub authorization policy: the agent may call only the six read-only investigation tools.
/// Anything else (a tool injected by configuration drift, an MCP tool, a hallucinated name) is denied and recorded.
Class CareBridge.AI.ToolGuard Extends %AI.Policy.Authorization
{

Parameter ALLOWED = "LookupPatient,LookupOrder,OrdersForPatient,MessageHistory,DuplicateStatus,ValidationFindings";

Method %CanExecute(toolref As %String, call As %DynamicObject, metadata As %DynamicObject) As %Status
{
	Set name = call.name
	// Tool names may be qualified (e.g. "CareBridgeInvestigation.LookupPatient"); compare the last segment.
	Set short = $PIECE($TRANSLATE(name, ":/", ".."), ".", *)
	If $LISTFIND($LISTFROMSTRING(..#ALLOWED), short) Quit $$$OK
	Try {
		Set runId = $GET(^||CareBridge.AgentRunId)
		If runId '= "" {
			Set tc = ##class(CareBridge.Data.ToolCall).%New()
			Do tc.AgentRunSetObjectId(runId)
			Set tc.Seq = $INCREMENT(^||CareBridge.ToolSeq)
			Set tc.ToolName = name
			Set tc.Authorization = "DENIED"
			Set tc.Success = 0
			Set tc.Error = "Not in the CareBridge read-only allowlist"
			Do tc.%Save()
		}
	} Catch {}
	Quit $$$ERROR($$$GeneralError, "CareBridge: tool "_name_" is not permitted")
}

}
