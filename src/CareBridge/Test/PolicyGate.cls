Class CareBridge.Test.PolicyGate Extends %UnitTest.TestCase
{

Property H As %String [ InitialExpression = "CareBridge.Test.Helper" ];

Method OnBeforeAllTests() As %Status
{
	Do ##class(CareBridge.Setup.Installer).ConfigDefaults()
	Quit ##class(CareBridge.Setup.Installer).Seed()
}

Method OnAfterAllTests() As %Status
{
	Do ##class(CareBridge.Test.Helper).Cleanup()
	Quit $$$OK
}

Method Agent(text As %String, rec As %DynamicObject, outcome As %String = "OK", attempts As %Integer = 0, type As %String = "") As %DynamicObject
{
	Set r = $CLASSMETHOD(..H, "Record", text, attempts)
	Set c = $CLASSMETHOD(..H, "Case", r, type)
	Quit ##class(CareBridge.Engine.PolicyGate).EvaluateAgent(rec, outcome, c, r)
}

Method TestApprovesGroundedPermittedAction()
{
	Set v = ..Agent($CLASSMETHOD(..H, "ORU", "MRN100002", "ORD-7777", "93", , , "19620721"), $CLASSMETHOD(..H, "Rec", "UNKNOWN_ORDER", "MANUAL_REVIEW", ["ORDER_NOT_FOUND","PATIENT_FOUND"], 1))
	Do $$$AssertTrue(v.approved)
	Do $$$AssertEquals(v.finalAction, "MANUAL_REVIEW")
}

Method TestAgentCannotAccept()
{
	Set v = ..Agent($CLASSMETHOD(..H, "ORU", "MRN100002", "ORD-7777", "93", , , "19620721"), $CLASSMETHOD(..H, "Rec", "UNKNOWN_ORDER", "ACCEPT", ["PATIENT_FOUND"]))
	Do $$$AssertNotTrue(v.approved)
	Do $$$AssertEquals(v.finalAction, "MANUAL_REVIEW", "Falls back to manual review")
}

Method TestUngroundedEvidenceRejected()
{
	Set v = ..Agent($CLASSMETHOD(..H, "ORU", "MRN100002", "ORD-7777", "93", , , "19620721"), $CLASSMETHOD(..H, "Rec", "UNKNOWN_ORDER", "QUARANTINE", ["ORDER_NOT_FOUND","PRE_APPROVED"]))
	Do $$$AssertNotTrue(v.approved)
	Do $$$AssertEquals(v.finalAction, "MANUAL_REVIEW")
}

Method TestIdentityConflictRequiresHuman()
{
	Set v = ..Agent($CLASSMETHOD(..H, "ORU", "MRN100002", "ORD-1001", "93", , , "19620721"), $CLASSMETHOD(..H, "Rec", "PATIENT_ORDER_CONFLICT", "REJECT", ["ORDER_PATIENT_MISMATCH"]))
	Do $$$AssertNotTrue(v.approved, "Only MANUAL_REVIEW is allowed for identity conflicts")
	Do $$$AssertEquals(v.finalAction, "MANUAL_REVIEW")
}

Method TestRetryLimitEnforced()
{
	Set text = $CLASSMETHOD(..H, "ORU", "MRN100001", "ORD-1001", "96")
	Set rec = $CLASSMETHOD(..H, "Rec", "DOWNSTREAM_UNAVAILABLE", "RETRY", ["DOWNSTREAM_UNAVAILABLE"])
	// The router adds DOWNSTREAM_UNAVAILABLE to the findings; emulate that here.
	Set r = $CLASSMETHOD(..H, "Record", text, 1)
	Set c = $CLASSMETHOD(..H, "Case", r, "DOWNSTREAM_UNAVAILABLE")
	Set c.Findings = [{"code":"DOWNSTREAM_UNAVAILABLE"}].%ToJSON()
	Do c.%Save()
	Set ok = ##class(CareBridge.Engine.PolicyGate).EvaluateAgent(rec, "OK", c, r)
	Do $$$AssertTrue(ok.approved, "Retry allowed with attempts left")
	Set r.DeliveryAttempts = 3
	Do r.%Save()
	Set no = ##class(CareBridge.Engine.PolicyGate).EvaluateAgent(rec, "OK", c, r)
	Do $$$AssertNotTrue(no.approved, "Retry refused once the budget is spent")
	Do $$$AssertEquals(no.finalAction, "MANUAL_REVIEW")
}

Method TestNoRecommendationFallsBackSafely()
{
	For outcome = "TIMEOUT", "INVALID_OUTPUT", "PROVIDER_ERROR" {
		Set v = ..Agent($CLASSMETHOD(..H, "ORU", "MRN100002", "ORD-7777", "93", , , "19620721"), "", outcome)
		Do $$$AssertNotTrue(v.approved)
		Do $$$AssertEquals(v.finalAction, "MANUAL_REVIEW", outcome_" never leads to an automatic action")
	}
}

Method TestHumanReviewFlagMustBeConsistent()
{
	Set first = $CLASSMETHOD(..H, "Record", $CLASSMETHOD(..H, "ORU", "MRN100001", "ORD-1001", "97"))
	Set d = ##class(CareBridge.Data.DeliveredResult).%New()
	Set d.CorrelationId = first.CorrelationId, d.ContentHash = first.ContentHash
	Do d.%Save()
	Set v = ..Agent($CLASSMETHOD(..H, "ORU", "MRN100001", "ORD-1001", "97"), $CLASSMETHOD(..H, "Rec", "DUPLICATE_RESULT", "DUPLICATE_SUPPRESSED", ["DUPLICATE_CONTENT_DELIVERED"], 1))
	Do $$$AssertNotTrue(v.approved, "requires_human_review=true contradicts an automatic action")
}

Method TestEvaluationIsPersisted()
{
	Set v = ..Agent($CLASSMETHOD(..H, "ORU", "MRN100002", "ORD-7777", "93", , , "19620721"), $CLASSMETHOD(..H, "Rec", "UNKNOWN_ORDER", "MANUAL_REVIEW", ["ORDER_NOT_FOUND"], 1))
	Set e = ##class(CareBridge.Data.PolicyEvaluation).%OpenId(v.evaluationId)
	Do $$$AssertTrue($ISOBJECT(e))
	Do $$$AssertEquals(e.Source, "AGENT")
	Do $$$AssertTrue([].%FromJSON(e.Rules).%Size() > 3)
}

Method TestHumanNeedsNoteAndPermittedAction()
{
	Set r = $CLASSMETHOD(..H, "Record", $CLASSMETHOD(..H, "ORU", "MRN100002", "ORD-7777", "93", , , "19620721"))
	Set c = $CLASSMETHOD(..H, "Case", r)
	Set c.Status = "AWAITING_REVIEW"
	Do c.%Save()
	Set v = ##class(CareBridge.Engine.PolicyGate).EvaluateHuman("ACCEPT", "", "reviewer.demo", c, r)
	Do $$$AssertNotTrue(v.approved, "A note is required")
	Do $$$AssertEquals(v.finalAction, "", "A refused human decision executes nothing")
	Set v = ##class(CareBridge.Engine.PolicyGate).EvaluateHuman("DUPLICATE_SUPPRESSED", "not a duplicate though", "reviewer.demo", c, r)
	Do $$$AssertNotTrue(v.approved, "Action not offered for UNKNOWN_ORDER")
	Set v = ##class(CareBridge.Engine.PolicyGate).EvaluateHuman("ACCEPT", "Order confirmed by phone with the ward", "reviewer.demo", c, r)
	Do $$$AssertTrue(v.approved)
}

Method TestHumanAcceptRechecksPatientExists()
{
	Set r = $CLASSMETHOD(..H, "Record", $CLASSMETHOD(..H, "ORU", "MRN888888", "ORD-8888", "93"))
	Set c = $CLASSMETHOD(..H, "Case", r)
	Set c.Status = "AWAITING_REVIEW"
	Do c.%Save()
	Set v = ##class(CareBridge.Engine.PolicyGate).EvaluateHuman("ACCEPT", "Looks like our patient", "reviewer.demo", c, r)
	Do $$$AssertNotTrue(v.approved, "Cannot accept a result for a patient the registry does not have")
}

}
