/// Builds the minimal, sanitised input the ExceptionInvestigator agent receives.
/// Names and free text are not sent; NTE text is reduced to a flag. Identifiers are synthetic.
Class CareBridge.Engine.ContextBuilder Extends %RegisteredObject
{

ClassMethod Build(case As CareBridge.Data.ExceptionCase, record As CareBridge.Data.MessageRecord) As %DynamicObject
{
	Set parsed = ##class(CareBridge.Engine.HL7Parser).Parse(record.RawText())
	Set obs = []
	Set iter = parsed.obx.%GetIterator()
	While iter.%GetNext(.k, .o) {
		// Codes and presence only; result values are clinical data the agent does not need to decide routing.
		Do obs.%Push({"code":(o.code), "hasValue":(o.value '= ""), "status":(o.status)})
	}
	Set findings = [].%FromJSON(case.Findings)
	Set codes = []
	Set iter = findings.%GetIterator()
	While iter.%GetNext(.k, .f) { Do codes.%Push(f.code) }
	Set permitted = ##class(CareBridge.Engine.PolicyGate).Permitted(##class(CareBridge.Engine.PolicyGate).#AGENTMATRIX, case.ExceptionType)
	Set allowed = []
	Set ptr = 0
	While $LISTNEXT(permitted, ptr, a) { Do allowed.%Push(a) }
	Quit {
		"correlationId": (record.CorrelationId),
		"exceptionType": (case.ExceptionType),
		"message": {
			"messageType": (parsed.msh.messageType),
			"controlId": (parsed.msh.controlId),
			"sendingApplication": (parsed.msh.sendingApplication),
			"patientRef": (parsed.pid.mrn),
			"placerOrderNumber": (parsed.obr.placerOrderNumber),
			"fillerOrderNumber": (parsed.obr.fillerOrderNumber),
			"testCode": (parsed.obr.testCode),
			"resultStatus": (record.ResultStatus),
			"observations": (obs),
			"freeTextPresent": (parsed.nte.%Size() > 0)
		},
		"validationFindings": (findings),
		"evidenceCodesObserved": (codes),
		"deliveryAttempts": (record.DeliveryAttempts),
		"maxDeliveryAttempts": (##class(CareBridge.Engine.PolicyGate).MaxDeliveryAttempts()),
		"permittedActions": (allowed)
	}
}

/// The user message sent to the agent for one case.
ClassMethod Prompt(input As %DynamicObject) As %String
{
	Quit "Investigate this CareBridge interoperability exception and return your recommendation as a single JSON object."_$CHAR(10)_
		"Use the read-only tools to confirm what you need. Choose recommended_action from permittedActions only."_$CHAR(10)_
		"Every evidence item must be a code that appears in evidenceCodesObserved."_$CHAR(10)_$CHAR(10)_
		"CASE:"_$CHAR(10)_input.%ToJSON()
}

}
