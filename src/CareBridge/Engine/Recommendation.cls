/// The product contract for an agent recommendation, and its strict validator.
/// Contract (all fields required, no others except an optional numeric "confidence"):
/// {
///   "exception_type": "UNKNOWN_ORDER",
///   "recommended_action": "MANUAL_REVIEW",
///   "reason": "The referenced order could not be located.",
///   "evidence": ["ORDER_NOT_FOUND", "PATIENT_FOUND"],
///   "requires_human_review": true
/// }
Class CareBridge.Engine.Recommendation Extends %RegisteredObject
{

/// Permitted outcomes. Anything else is rejected before policy evaluation.
Parameter ACTIONS = "ACCEPT,RETRY,QUARANTINE,MANUAL_REVIEW,DUPLICATE_SUPPRESSED,REJECT";

Parameter EXCEPTIONTYPES = "UNKNOWN_PATIENT,UNKNOWN_ORDER,DUPLICATE_RESULT,MISSING_REQUIRED_FIELDS,PATIENT_ORDER_CONFLICT,DOWNSTREAM_UNAVAILABLE";

Parameter ALLOWEDKEYS = "exception_type,recommended_action,reason,evidence,requires_human_review,confidence";

ClassMethod IsAction(action As %String) As %Boolean
{
	Quit (action '= "") && ($LISTFIND($LISTFROMSTRING(..#ACTIONS), action) > 0)
}

/// Extract the first JSON object from model text (tolerates ```json fences and surrounding prose).
/// Returns "" if no parseable object is found.
ClassMethod ExtractJSON(text As %String) As %DynamicObject
{
	Set start = $FIND(text, "{")
	Quit:start=0 ""
	// Try progressively shorter candidates ending at each closing brace, last first.
	Set end = $LENGTH(text)
	While end >= start {
		If $EXTRACT(text, end) = "}" {
			Set candidate = $EXTRACT(text, start - 1, end)
			Try {
				Set obj = {}.%FromJSON(candidate)
				If $CLASSNAME(obj) = "%Library.DynamicObject" Return obj
			} Catch {}
		}
		Set end = end - 1
	}
	Quit ""
}

/// Validate model output against the contract.
/// Returns a %Status; on success rec holds the normalised recommendation.
ClassMethod Validate(text As %String, expectedType As %String, Output rec As %DynamicObject, Output problems As %DynamicArray) As %Status
{
	Set rec = "", problems = []
	Set obj = ..ExtractJSON(text)
	If '$ISOBJECT(obj) {
		Do problems.%Push("Output is not a JSON object")
		Quit $$$ERROR($$$GeneralError, "INVALID_JSON")
	}
	Set iter = obj.%GetIterator()
	While iter.%GetNext(.key, .val) {
		If '$LISTFIND($LISTFROMSTRING(..#ALLOWEDKEYS), key) {
			Do problems.%Push("Unexpected field: "_key)
		}
	}
	Set action = obj.%Get("recommended_action")
	If '..IsAction(action) Do problems.%Push("recommended_action is not one of "_..#ACTIONS_": "_$EXTRACT(action, 1, 60))
	Set type = obj.%Get("exception_type")
	If type '= expectedType Do problems.%Push("exception_type "_$EXTRACT(type, 1, 60)_" does not match the case ("_expectedType_")")
	Set reason = obj.%Get("reason")
	If (reason = "") || ($LENGTH(reason) > 600) Do problems.%Push("reason must be 1-600 characters")
	Set ev = obj.%Get("evidence")
	If '$ISOBJECT(ev) || ($CLASSNAME(ev) '= "%Library.DynamicArray") || (ev.%Size() = 0) || (ev.%Size() > 12) {
		Do problems.%Push("evidence must be a non-empty array of up to 12 codes")
	} Else {
		Set it2 = ev.%GetIterator()
		While it2.%GetNext(.k, .code) {
			If ($ISOBJECT(code)) || (code = "") || ($LENGTH(code) > 80) Do problems.%Push("evidence items must be short code strings")
		}
	}
	If obj.%GetTypeOf("requires_human_review") '= "boolean" Do problems.%Push("requires_human_review must be a boolean")
	If obj.%IsDefined("confidence") && (obj.%GetTypeOf("confidence") '= "number") Do problems.%Push("confidence must be a number")
	If problems.%Size() > 0 Quit $$$ERROR($$$GeneralError, "CONTRACT_VIOLATION")
	Set rec = {
		"exception_type": (type),
		"recommended_action": (action),
		"reason": (reason),
		"evidence": (ev),
		"requires_human_review": (obj.%Get("requires_human_review"))
	}
	Do rec.%Set("requires_human_review", obj.%Get("requires_human_review"), "boolean")
	If obj.%IsDefined("confidence") Do rec.%Set("confidence", obj.%Get("confidence"), "number")
	Quit $$$OK
}

}
