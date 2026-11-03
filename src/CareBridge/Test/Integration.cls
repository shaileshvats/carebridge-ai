/// End-to-end tests through the running production: messages are sent over MLLP and the results are
/// read back from what the production persisted. Runs in REPLAY mode so outcomes are deterministic.
Class CareBridge.Test.Integration Extends %UnitTest.TestCase
{

Property SavedMode As %String;

Method OnBeforeAllTests() As %Status
{
	Set ..SavedMode = $GET(^CareBridge.Config("AgentMode"))
	Set ^CareBridge.Config("AgentMode") = "REPLAY"
	Set sc = ##class(CareBridge.Setup.Installer).StartProduction()
	Quit:$$$ISERR(sc) sc
	Quit ##class(CareBridge.Setup.Installer).Reset()
}

Method OnAfterAllTests() As %Status
{
	Set ^CareBridge.Config("AgentMode") = ..SavedMode
	Quit $$$OK
}

Method Run(name As %String) As %DynamicObject
{
	Set r = ##class(CareBridge.Demo.Runner).RunScenario(name)
	Do $$$AssertEquals(r.outcome, r.expect, name_": expected "_r.expect_", got "_r.outcome)
	Quit r
}

Method Corr(r As %DynamicObject) As %String
{
	Quit r.messages.%Get(r.messages.%Size() - 1).final.correlationId
}

Method Events(corr As %String) As %List
{
	Set l = ""
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT EventType FROM CareBridge_Data.AuditEvent WHERE CorrelationId = ? ORDER BY ID", corr)
	While rs.%Next() { Set l = l_$LB(rs.EventType) }
	Quit l
}

Method Count(sql As %String, args...) As %Integer
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, sql, args...)
	Quit:'rs.%Next() 0
	Quit rs.%GetData(1)
}

Method TestValidResultIsDeliveredWithoutAgent()
{
	Set corr = ..Corr(..Run("valid-result"))
	Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM CareBridge_Data.DeliveredResult WHERE CorrelationId = ?", corr), 1)
	Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM CareBridge_Data.AgentRun WHERE CorrelationId = ?", corr), 0, "No exception, no agent")
	Set ev = ..Events(corr)
	For e = "RECEIVED", "VALIDATED", "DELIVERED", "COMPLETED" { Do $$$AssertTrue($LISTFIND(ev, e), "audit has "_e) }
}

Method TestExceptionInvokesAgentAndPolicy()
{
	Set corr = ..Corr(..Run("unknown-order"))
	Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM CareBridge_Data.AgentRun WHERE CorrelationId = ? AND Outcome = 'OK'", corr), 1)
	Do $$$AssertTrue(..Count("SELECT COUNT(*) FROM CareBridge_Data.ToolCall WHERE AgentRun->CorrelationId = ?", corr) > 0, "Tool calls traced")
	Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM CareBridge_Data.PolicyEvaluation WHERE CorrelationId = ? AND Approved = 1", corr), 1)
	Set ev = ..Events(corr)
	For e = "RECEIVED", "VALIDATION_FAILED", "EXCEPTION_RAISED", "AGENT_INVOKED", "AGENT_RESPONDED", "POLICY_EVALUATED", "REVIEW_REQUESTED" { Do $$$AssertTrue($LISTFIND(ev, e), "audit has "_e) }
	Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM CareBridge_Data.DeliveredResult WHERE CorrelationId = ?", corr), 0, "Nothing delivered")
}

Method TestDuplicateIsSuppressedAndDeliveredOnce()
{
	Set r = ..Run("duplicate-result")
	Set first = r.messages.%Get(0).final.correlationId, second = ..Corr(r)
	Set hash = ##class(CareBridge.Data.MessageRecord).OpenByCorrelation(first).ContentHash
	Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM CareBridge_Data.DeliveredResult WHERE ContentHash = ?", hash), 1, "Exactly one copy downstream")
	Do $$$AssertEquals(r.messages.%Get(0).final.outcome, "ACCEPT")
	Do $$$AssertTrue(second '= first)
}

Method TestMissingFieldIsRejectedToLIS()
{
	Set corr = ..Corr(..Run("missing-field"))
	Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM CareBridge_Data.QueueItem WHERE CorrelationId = ? AND Queue = 'REJECT_NOTICE'", corr), 1)
}

Method TestConflictGoesToWorkflow()
{
	Set corr = ..Corr(..Run("patient-order-conflict"))
	Set c = ##class(CareBridge.Engine.Lookup).LatestCase(corr)
	Do $$$AssertEquals(c.Status, "AWAITING_REVIEW")
	Do $$$AssertTrue($ISOBJECT(##class(CareBridge.Engine.Review).FindTask(c.%Id())), "Workflow task exists")
}

Method TestRetryAfterDownstreamFailure()
{
	Set corr = ..Corr(..Run("downstream-timeout"))
	Set rec = ##class(CareBridge.Data.MessageRecord).OpenByCorrelation(corr)
	Do $$$AssertEquals(rec.DeliveryAttempts, 2, "Failed once, delivered on retry")
	Set ev = ..Events(corr)
	For e = "DELIVERY_FAILED", "RETRY_SCHEDULED", "RETRY_DUE", "RETRY_STARTED", "DELIVERED" { Do $$$AssertTrue($LISTFIND(ev, e), "audit has "_e) }
}

Method TestAdversarialRecommendationsAreBlocked()
{
	For name = "prompt-injection", "unsafe-action", "malformed-output" {
		Set corr = ..Corr(..Run(name))
		Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM CareBridge_Data.DeliveredResult WHERE CorrelationId = ?", corr), 0, name_": nothing delivered")
		Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM CareBridge_Data.PolicyEvaluation WHERE CorrelationId = ? AND Source = 'AGENT' AND Approved = 0", corr), 1, name_": policy rejected the agent")
	}
}

Method TestHumanReviewAfterLateRegistration()
{
	Set corr = ..Corr(..Run("unknown-patient"))
	Set c = ##class(CareBridge.Engine.Lookup).LatestCase(corr)
	// Before registration, a human ACCEPT is refused by policy and a new task is issued.
	Set res = ##class(CareBridge.Engine.Review).Decide(c.%Id(), "ACCEPT", "Patient confirmed at the ward", "reviewer.demo")
	Do $$$AssertNotTrue(res.%IsDefined("error"), $SELECT(res.%IsDefined("error"):res.error, 1:""))
	Do ..WaitFor(corr, "MANUAL_REVIEW", 2)
	Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM CareBridge_Data.PolicyEvaluation WHERE CorrelationId = ? AND Source = 'HUMAN' AND Approved = 0", corr), 1)
	// The HIS registers the patient; the same decision is now allowed.
	Do ##class(CareBridge.Demo.Runner).RunFollowUp("unknown-patient")
	Set res = ##class(CareBridge.Engine.Review).Decide(c.%Id(), "ACCEPT", "Registration now complete in HIS", "lab.supervisor")
	Do $$$AssertNotTrue(res.%IsDefined("error"))
	Set final = ..WaitFor(corr, "ACCEPTED", 20)
	Do $$$AssertEquals(final, "ACCEPTED")
	Do $$$AssertEquals(##class(CareBridge.Data.MessageRecord).OpenByCorrelation(corr).DecidedBy, "HUMAN")
}

Method WaitFor(corr As %String, status As %String, seconds As %Integer) As %String
{
	Set deadline = $ZHOROLOG + seconds
	For {
		Set s = ##class(CareBridge.Data.MessageRecord).OpenByCorrelation(corr).Status
		Quit:(s=status)||($ZHOROLOG>deadline)
		Hang 0.5
	}
	Quit s
}

}
