/// The deterministic policy gate between a recommendation (agent or human) and execution.
/// It is authoritative: the agent's confidence is never a reason to approve.
/// Every evaluation is persisted as a CareBridge.Data.PolicyEvaluation, approved or not.
Class CareBridge.Engine.PolicyGate Extends %RegisteredObject
{

/// Actions the AGENT may recommend, per exception type. ACCEPT is never delegated to the agent:
/// a result with an open exception reaches the clinical record only through a human decision.
Parameter AGENTMATRIX = "UNKNOWN_PATIENT=MANUAL_REVIEW,QUARANTINE,REJECT;UNKNOWN_ORDER=MANUAL_REVIEW,QUARANTINE,REJECT;DUPLICATE_RESULT=DUPLICATE_SUPPRESSED,MANUAL_REVIEW;MISSING_REQUIRED_FIELDS=REJECT,QUARANTINE,MANUAL_REVIEW;PATIENT_ORDER_CONFLICT=MANUAL_REVIEW;DOWNSTREAM_UNAVAILABLE=RETRY,QUARANTINE,MANUAL_REVIEW";

/// Actions a HUMAN reviewer may choose, per exception type (further state checks still apply).
Parameter HUMANMATRIX = "UNKNOWN_PATIENT=ACCEPT,QUARANTINE,REJECT;UNKNOWN_ORDER=ACCEPT,QUARANTINE,REJECT;DUPLICATE_RESULT=ACCEPT,DUPLICATE_SUPPRESSED,REJECT;MISSING_REQUIRED_FIELDS=QUARANTINE,REJECT;PATIENT_ORDER_CONFLICT=ACCEPT,QUARANTINE,REJECT;DOWNSTREAM_UNAVAILABLE=RETRY,QUARANTINE,REJECT";

/// Findings that make patient identity ambiguous; only a human may resolve these.
Parameter IDENTITYFINDINGS = "ORDER_PATIENT_MISMATCH,PATIENT_DEMOGRAPHICS_MISMATCH";

/// Safe action when a recommendation is rejected, malformed or missing.
Parameter FALLBACK = "MANUAL_REVIEW";

ClassMethod MaxDeliveryAttempts() As %Integer
{
	Quit +$GET(^CareBridge.Config("MaxDeliveryAttempts"), 3)
}

ClassMethod Permitted(matrix As %String, exceptionType As %String) As %List
{
	For i = 1:1:$LENGTH(matrix, ";") {
		Set entry = $PIECE(matrix, ";", i)
		If $PIECE(entry, "=", 1) = exceptionType Quit
		Set entry = ""
	}
	Quit $LISTFROMSTRING($PIECE($GET(entry), "=", 2))
}

/// Evaluate an agent recommendation.
/// rec: validated recommendation object, or "" when the agent produced none (timeout, malformed output, ...).
/// agentOutcome: OK / INVALID_OUTPUT / TIMEOUT / PROVIDER_ERROR / NOT_AVAILABLE.
ClassMethod EvaluateAgent(rec As %DynamicObject, agentOutcome As %String, case As CareBridge.Data.ExceptionCase, record As CareBridge.Data.MessageRecord, agentRunId As %String = "") As %DynamicObject
{
	Set rules = []
	Set type = case.ExceptionType
	Set findings = [].%FromJSON(case.Findings)
	Set observed = ##class(CareBridge.Engine.Validator).Codes(findings)
	Set action = $SELECT($ISOBJECT(rec):rec."recommended_action", 1:"")

	Do ..Rule(rules, "AGENT_OUTPUT_VALID", $ISOBJECT(rec) && (agentOutcome = "OK"), $SELECT($ISOBJECT(rec):"Recommendation matched the contract", 1:"No usable recommendation ("_agentOutcome_")"))
	If $ISOBJECT(rec) {
		Do ..Rule(rules, "ACTION_IN_ENUM", ##class(CareBridge.Engine.Recommendation).IsAction(action), action)
		Do ..Rule(rules, "EXCEPTION_TYPE_MATCHES", rec."exception_type" = type, rec."exception_type"_" vs "_type)
		Set ev = rec.evidence, ungrounded = ""
		Set iter = ev.%GetIterator()
		While iter.%GetNext(.k, .code) {
			If '$LISTFIND(observed, code) Set ungrounded = ungrounded_$SELECT(ungrounded="":"", 1:", ")_code
		}
		Do ..Rule(rules, "EVIDENCE_PRESENT", ev.%Size() > 0, ev.%Size()_" item(s)")
		Do ..Rule(rules, "EVIDENCE_GROUNDED", ungrounded = "", $SELECT(ungrounded="":"Every evidence code was observed by validation", 1:"Not observed: "_ungrounded))
		Set permitted = ..Permitted(..#AGENTMATRIX, type)
		Do ..Rule(rules, "ACTION_PERMITTED_FOR_EXCEPTION", $LISTFIND(permitted, action) > 0, "Agent may choose "_$LISTTOSTRING(permitted, "/")_" for "_type)
		Set identity = ..HasAny(observed, ..#IDENTITYFINDINGS)
		Do ..Rule(rules, "IDENTITY_CONFLICT_NEEDS_HUMAN", 'identity || (action = "MANUAL_REVIEW"), $SELECT(identity:"Identity conflict present", 1:"No identity conflict"))
		Do ..Rule(rules, "HUMAN_REVIEW_FLAG_CONSISTENT", '(rec."requires_human_review") || '$LISTFIND($LB("ACCEPT","RETRY","DUPLICATE_SUPPRESSED"), action), "requires_human_review="_$SELECT(rec."requires_human_review":"true", 1:"false"))
		Do ..AddStateRules(rules, action, record, observed)
	}
	Quit ..Decide(rules, action, "AGENT", case, record, agentRunId)
}

/// Evaluate a human reviewer's decision. The same state rules apply; the matrix is the human one.
ClassMethod EvaluateHuman(action As %String, note As %String, reviewer As %String, case As CareBridge.Data.ExceptionCase, record As CareBridge.Data.MessageRecord) As %DynamicObject
{
	Set rules = []
	Set type = case.ExceptionType
	Set observed = ##class(CareBridge.Engine.Validator).Codes([].%FromJSON(case.Findings))
	Do ..Rule(rules, "ACTION_IN_ENUM", ##class(CareBridge.Engine.Recommendation).IsAction(action), action)
	Set permitted = ..Permitted(..#HUMANMATRIX, type)
	Do ..Rule(rules, "ACTION_PERMITTED_FOR_EXCEPTION", $LISTFIND(permitted, action) > 0, "Reviewer may choose "_$LISTTOSTRING(permitted, "/")_" for "_type)
	Do ..Rule(rules, "REVIEW_NOTE_PRESENT", $LENGTH($ZSTRIP(note, "<>W")) >= 5, "A review note of at least 5 characters is required")
	Do ..Rule(rules, "REVIEWER_IDENTIFIED", reviewer '= "", reviewer)
	Do ..Rule(rules, "CASE_AWAITING_REVIEW", case.Status = "AWAITING_REVIEW", "Case status "_case.Status)
	If action = "ACCEPT" {
		// Re-check identity against the registry as it is now (the HIS may have sent the missing ADT/ORM).
		Set parsed = ##class(CareBridge.Engine.HL7Parser).Parse(record.RawText())
		Set patientNow = $ISOBJECT(##class(CareBridge.Data.Patient).MRNIdxOpen(parsed.pid.mrn))
		Do ..Rule(rules, "PATIENT_EXISTS_AT_DECISION", patientNow, "MRN "_parsed.pid.mrn_$SELECT(patientNow:" is", 1:" is still not")_" in the registry")
	}
	Do ..AddStateRules(rules, action, record, observed)
	Quit ..Decide(rules, action, "HUMAN", case, record, "", note)
}

/// Rules that depend on current state, shared by agent and human evaluation.
ClassMethod AddStateRules(rules As %DynamicArray, action As %String, record As CareBridge.Data.MessageRecord, observed As %List)
{
	If action = "ACCEPT" {
		Set corr = record.CorrelationId, hash = record.ContentHash
		&sql(SELECT COUNT(*) INTO :n FROM CareBridge_Data.DeliveredResult WHERE CorrelationId = :corr OR (ContentHash = :hash AND :hash <> ''))
		Do ..Rule(rules, "NO_DUPLICATE_DELIVERY", (SQLCODE = 0) && (n = 0), $SELECT(n>0:"Identical content already delivered", 1:"Not previously delivered"))
		Do ..Rule(rules, "REQUIRED_FIELDS_PRESENT", '..HasPrefix(observed, "MISSING_FIELD:") && '$LISTFIND(observed, "UNPARSEABLE_MESSAGE"), "A result with missing required fields cannot be delivered")
	}
	If action = "RETRY" {
		Set max = ..MaxDeliveryAttempts()
		Do ..Rule(rules, "RETRY_LIMIT", record.DeliveryAttempts < max, record.DeliveryAttempts_" of "_max_" attempts used")
	}
}

ClassMethod Decide(rules As %DynamicArray, action As %String, source As %String, case As CareBridge.Data.ExceptionCase, record As CareBridge.Data.MessageRecord, agentRunId As %String = "", note As %String = "") As %DynamicObject
{
	Set failed = ""
	Set iter = rules.%GetIterator()
	While iter.%GetNext(.k, .r) {
		If 'r.passed Set failed = failed_$SELECT(failed="":"", 1:", ")_r.rule
	}
	Set approved = (failed = "")
	If approved {
		Set final = action
		Set summary = source_" recommendation "_action_" approved"
	} ElseIf source = "AGENT" {
		Set final = ..#FALLBACK
		Set summary = "Agent recommendation "_$SELECT(action="":"(none)", 1:action)_" rejected ("_failed_"); routed to "_final
	} Else {
		// A rejected human decision changes nothing: the case stays in review.
		Set final = ""
		Set summary = "Reviewer decision "_action_" rejected ("_failed_"); case stays in review"
	}
	Set eval = ##class(CareBridge.Data.PolicyEvaluation).%New()
	Set eval.CorrelationId = record.CorrelationId
	Set eval.ExceptionCase = case
	If agentRunId '= "" Do eval.AgentRunSetObjectId(agentRunId)
	Set eval.Source = source
	Set eval.RecommendedAction = action
	Set eval.Approved = approved
	Set eval.FinalAction = final
	Set eval.Rules = rules.%ToJSON()
	Set eval.Summary = summary
	Set sc = eval.%Save()
	Do ##class(CareBridge.Data.AuditEvent).Log(record.CorrelationId, "POLICY_EVALUATED", "policy-gate", summary)
	Set out = {"approved":(approved), "finalAction":(final), "summary":(summary), "rules":(rules), "evaluationId":(eval.%Id())}
	Do out.%Set("approved", approved, "boolean")
	Quit out
}

ClassMethod Rule(rules As %DynamicArray, name As %String, passed As %Boolean, detail As %String = "")
{
	Set r = {"rule":(name), "detail":(detail)}
	Do r.%Set("passed", ''passed, "boolean")
	Do rules.%Push(r)
}

ClassMethod HasAny(observed As %List, csv As %String) As %Boolean
{
	For i = 1:1:$LENGTH(csv, ",") {
		If $LISTFIND(observed, $PIECE(csv, ",", i)) Return 1
	}
	Quit 0
}

ClassMethod HasPrefix(observed As %List, prefix As %String) As %Boolean
{
	Set ptr = 0
	While $LISTNEXT(observed, ptr, code) {
		If $EXTRACT(code, 1, $LENGTH(prefix)) = prefix Return 1
	}
	Quit 0
}

}
