/// Usage evidence from persisted agent runs: per-run rows and totals per mode and model.
/// Token counts are exactly what AI Hub reported; nothing is estimated or priced.
Class CareBridge.Demo.Report Extends %RegisteredObject
{

ClassMethod AgentUsage() As %DynamicObject
{
	Set out = {"generatedAt":($ZDATETIME($ZTIMESTAMP, 3)), "iris":($ZVERSION), "runs":[], "totals":[]}
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT a.ID, a.CorrelationId, m.Scenario, a.Mode, a.Provider, a.Model, a.StartedAt, a.DurationMs, a.PromptTokens, a.CompletionTokens, a.Attempts, a.Outcome, a.RecommendedAction, p.Approved, p.FinalAction, (SELECT COUNT(*) FROM CareBridge_Data.ToolCall t WHERE t.AgentRun = a.ID) AS ToolCalls FROM CareBridge_Data.AgentRun a LEFT JOIN CareBridge_Data.MessageRecord m ON m.CorrelationId = a.CorrelationId LEFT JOIN CareBridge_Data.PolicyEvaluation p ON p.AgentRun = a.ID ORDER BY a.ID")
	While rs.%Next() {
		Set r = {"run":(rs.ID), "correlationId":(rs.CorrelationId), "scenario":(rs.Scenario), "mode":(rs.Mode), "provider":(rs.Provider), "model":(rs.Model), "startedAt":(rs.StartedAt), "durationMs":(rs.DurationMs), "promptTokens":(rs.PromptTokens), "completionTokens":(rs.CompletionTokens), "attempts":(rs.Attempts), "toolCalls":(rs.ToolCalls), "outcome":(rs.Outcome), "recommended":(rs.RecommendedAction), "finalAction":(rs.FinalAction)}
		Do r.%Set("policyApproved", rs.Approved, "boolean")
		Do out.runs.%Push(r)
	}
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(Mode) AS Mode, %EXACT(Provider) AS Provider, %EXACT(Model) AS Model, COUNT(*) AS Runs, SUM(PromptTokens) AS PromptTokens, SUM(CompletionTokens) AS CompletionTokens, AVG(DurationMs) AS AvgMs, MAX(DurationMs) AS MaxMs, SUM(CASE WHEN Outcome = 'OK' THEN 1 ELSE 0 END) AS ValidRuns FROM CareBridge_Data.AgentRun GROUP BY %EXACT(Mode), %EXACT(Provider), %EXACT(Model)")
	While rs.%Next() {
		Do out.totals.%Push({"mode":(rs.Mode), "provider":(rs.Provider), "model":(rs.Model), "runs":(rs.Runs), "validRuns":(rs.ValidRuns), "promptTokens":(rs.PromptTokens), "completionTokens":(rs.CompletionTokens), "avgDurationMs":(rs.AvgMs\1), "maxDurationMs":(rs.MaxMs)})
	}
	Quit out
}

/// Write the report to a file (used by scripts/usage-report.sh).
ClassMethod Export(file As %String) As %Status
{
	Set f = ##class(%Stream.FileCharacter).%New()
	Set f.Filename = file
	Do f.Write(..AgentUsage().%ToJSON())
	Quit f.%Save()
}

}
