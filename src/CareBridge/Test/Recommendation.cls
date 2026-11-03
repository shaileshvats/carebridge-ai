Class CareBridge.Test.Recommendation Extends %UnitTest.TestCase
{

Method TestValidRecommendation()
{
	Set text = "{""exception_type"":""UNKNOWN_ORDER"",""recommended_action"":""MANUAL_REVIEW"",""reason"":""Order not found."",""evidence"":[""ORDER_NOT_FOUND""],""requires_human_review"":true}"
	Set sc = ##class(CareBridge.Engine.Recommendation).Validate(text, "UNKNOWN_ORDER", .rec, .problems)
	Do $$$AssertStatusOK(sc)
	Do $$$AssertEquals(rec."recommended_action", "MANUAL_REVIEW")
}

Method TestFencedJsonIsAccepted()
{
	Set text = "Here you go:"_$CHAR(10)_"```json"_$CHAR(10)_"{""exception_type"":""DUPLICATE_RESULT"",""recommended_action"":""DUPLICATE_SUPPRESSED"",""reason"":""Already delivered."",""evidence"":[""DUPLICATE_CONTENT_DELIVERED""],""requires_human_review"":false}"_$CHAR(10)_"```"
	Do $$$AssertStatusOK(##class(CareBridge.Engine.Recommendation).Validate(text, "DUPLICATE_RESULT", .rec, .problems))
}

Method TestInvalidJsonRejected()
{
	Set sc = ##class(CareBridge.Engine.Recommendation).Validate("Sure! I would accept it.", "UNKNOWN_ORDER", .rec, .problems)
	Do $$$AssertStatusNotOK(sc)
	Do $$$AssertNotTrue($ISOBJECT(rec))
	Set sc = ##class(CareBridge.Engine.Recommendation).Validate("{""recommended_action"": ""ACCEPT""", "UNKNOWN_ORDER", .rec, .problems)
	Do $$$AssertStatusNotOK(sc, "Truncated JSON is rejected")
}

Method TestUnknownActionRejected()
{
	Set text = "{""exception_type"":""PATIENT_ORDER_CONFLICT"",""recommended_action"":""merge_patient_records"",""reason"":""Same person."",""evidence"":[""ORDER_PATIENT_MISMATCH""],""requires_human_review"":false}"
	Set sc = ##class(CareBridge.Engine.Recommendation).Validate(text, "PATIENT_ORDER_CONFLICT", .rec, .problems)
	Do $$$AssertStatusNotOK(sc, "merge_patient_records is not a permitted action")
}

Method TestExtraFieldsRejected()
{
	Set text = "{""exception_type"":""UNKNOWN_PATIENT"",""recommended_action"":""MANUAL_REVIEW"",""reason"":""x y z"",""evidence"":[""PATIENT_NOT_FOUND""],""requires_human_review"":true,""patient_update"":{""mrn"":""MRN100002""}}"
	Do $$$AssertStatusNotOK(##class(CareBridge.Engine.Recommendation).Validate(text, "UNKNOWN_PATIENT", .rec, .problems), "A patient_update field is refused")
}

Method TestWrongExceptionTypeRejected()
{
	Set text = "{""exception_type"":""DUPLICATE_RESULT"",""recommended_action"":""DUPLICATE_SUPPRESSED"",""reason"":""x y z"",""evidence"":[""DUPLICATE_CONTROL_ID""],""requires_human_review"":false}"
	Do $$$AssertStatusNotOK(##class(CareBridge.Engine.Recommendation).Validate(text, "UNKNOWN_ORDER", .rec, .problems))
}

Method TestEvidenceAndFlagTypesEnforced()
{
	Set t1 = "{""exception_type"":""UNKNOWN_ORDER"",""recommended_action"":""MANUAL_REVIEW"",""reason"":""x y z"",""evidence"":""ORDER_NOT_FOUND"",""requires_human_review"":true}"
	Do $$$AssertStatusNotOK(##class(CareBridge.Engine.Recommendation).Validate(t1, "UNKNOWN_ORDER", .rec, .problems), "evidence must be an array")
	Set t2 = "{""exception_type"":""UNKNOWN_ORDER"",""recommended_action"":""MANUAL_REVIEW"",""reason"":""x y z"",""evidence"":[],""requires_human_review"":true}"
	Do $$$AssertStatusNotOK(##class(CareBridge.Engine.Recommendation).Validate(t2, "UNKNOWN_ORDER", .rec, .problems), "evidence must not be empty")
	Set t3 = "{""exception_type"":""UNKNOWN_ORDER"",""recommended_action"":""MANUAL_REVIEW"",""reason"":""x y z"",""evidence"":[""ORDER_NOT_FOUND""],""requires_human_review"":""yes""}"
	Do $$$AssertStatusNotOK(##class(CareBridge.Engine.Recommendation).Validate(t3, "UNKNOWN_ORDER", .rec, .problems), "requires_human_review must be boolean")
}

}
