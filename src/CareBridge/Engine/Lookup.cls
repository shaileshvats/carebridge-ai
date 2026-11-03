/// Read-only lookups over the synthetic registry and message history.
/// These are the only data the ExceptionInvestigator agent can reach (through CareBridge.AI.InvestigationTools),
/// so every method returns a small JSON document and never writes.
Class CareBridge.Engine.Lookup Extends %RegisteredObject
{

ClassMethod LookupPatient(mrn As %String) As %DynamicObject
{
	Set p = ##class(CareBridge.Data.Patient).MRNIdxOpen(mrn)
	If '$ISOBJECT(p) Quit {"found":false, "mrn":(mrn), "evidence":"PATIENT_NOT_FOUND"}
	// Minimum necessary: no names, only what identity checks need.
	Quit {"found":true, "mrn":(p.MRN), "birthDate":(p.BirthDate), "sex":(p.Sex), "evidence":"PATIENT_FOUND"}
}

ClassMethod LookupOrder(placerOrderNumber As %String) As %DynamicObject
{
	Set o = ##class(CareBridge.Data.LabOrder).PlacerIdxOpen(placerOrderNumber)
	If '$ISOBJECT(o) Quit {"found":false, "placerOrderNumber":(placerOrderNumber), "evidence":"ORDER_NOT_FOUND"}
	Quit {"found":true, "placerOrderNumber":(o.PlacerOrderNumber), "fillerOrderNumber":(o.FillerOrderNumber), "mrn":(o.MRN), "testCode":(o.TestCode), "status":(o.Status), "evidence":"ORDER_FOUND"}
}

/// Orders on file for a patient (placer numbers and test codes only).
ClassMethod OrdersForPatient(mrn As %String) As %DynamicObject
{
	Set out = []
	&sql(DECLARE oc CURSOR FOR SELECT PlacerOrderNumber, TestCode, Status INTO :placer, :code, :status FROM CareBridge_Data.LabOrder WHERE MRN = :mrn ORDER BY ID DESC)
	&sql(OPEN oc)
	For n = 1:1:20 {
		&sql(FETCH oc)
		Quit:SQLCODE'=0
		Do out.%Push({"placerOrderNumber":(placer), "testCode":(code), "status":(status)})
	}
	&sql(CLOSE oc)
	Quit {"mrn":(mrn), "orders":(out), "count":(out.%Size())}
}

/// Recent messages that share the patient or order reference (excluding the one under investigation).
ClassMethod HistoryArray(mrn As %String, placer As %String, excludeCorrelation As %String = "") As %DynamicArray
{
	Set out = []
	Set mrn = $GET(mrn), placer = $GET(placer)
	Quit:(mrn = "")&&(placer = "") out
	&sql(DECLARE hc CURSOR FOR
		SELECT TOP 10 CorrelationId, ControlId, MessageType, PatientRef, OrderRef, ResultStatus, Status, FinalOutcome, ReceivedAt
		INTO :corr, :ctl, :type, :pref, :oref, :rstat, :status, :outcome, :at
		FROM CareBridge_Data.MessageRecord
		WHERE (PatientRef = :mrn OR OrderRef = :placer) AND CorrelationId <> :excludeCorrelation
		ORDER BY ID DESC)
	&sql(OPEN hc)
	For {
		&sql(FETCH hc)
		Quit:SQLCODE'=0
		Do out.%Push({"correlationId":(corr), "controlId":(ctl), "messageType":(type), "patientRef":(pref), "orderRef":(oref), "resultStatus":(rstat), "status":(status), "finalOutcome":(outcome), "receivedAt":(at)})
	}
	&sql(CLOSE hc)
	Quit out
}

ClassMethod MessageHistory(correlationId As %String) As %DynamicObject
{
	Set r = ##class(CareBridge.Data.MessageRecord).OpenByCorrelation(correlationId)
	If '$ISOBJECT(r) Quit {"error":"unknown correlationId"}
	Quit {"correlationId":(correlationId), "history":(..HistoryArray(r.PatientRef, r.OrderRef, correlationId))}
}

ClassMethod DuplicateStatus(correlationId As %String) As %DynamicObject
{
	Set r = ##class(CareBridge.Data.MessageRecord).OpenByCorrelation(correlationId)
	If '$ISOBJECT(r) Quit {"error":"unknown correlationId"}
	Set d = ##class(CareBridge.Engine.Validator).DuplicateCheck(r)
	Set d.resultStatus = r.ResultStatus
	Set d.evidence = []
	Do:d.sameControlIdSeen d.evidence.%Push("DUPLICATE_CONTROL_ID")
	Do:d.sameContentDelivered d.evidence.%Push("DUPLICATE_CONTENT_DELIVERED")
	Do:r.ResultStatus="C" d.evidence.%Push("RESULT_CORRECTED")
	Quit d
}

/// Validation findings and delivery state recorded for the exception case of this message.
ClassMethod ValidationFindings(correlationId As %String) As %DynamicObject
{
	Set r = ##class(CareBridge.Data.MessageRecord).OpenByCorrelation(correlationId)
	If '$ISOBJECT(r) Quit {"error":"unknown correlationId"}
	Set case = ..LatestCase(correlationId)
	Set findings = $SELECT($ISOBJECT(case):[].%FromJSON(case.Findings), 1:[])
	Quit {"correlationId":(correlationId), "exceptionType":($SELECT($ISOBJECT(case):case.ExceptionType, 1:"")), "findings":(findings), "deliveryAttempts":(r.DeliveryAttempts), "maxDeliveryAttempts":(##class(CareBridge.Engine.PolicyGate).MaxDeliveryAttempts())}
}

ClassMethod LatestCase(correlationId As %String) As CareBridge.Data.ExceptionCase
{
	&sql(SELECT MAX(ID) INTO :id FROM CareBridge_Data.ExceptionCase WHERE CorrelationId = :correlationId)
	Quit:(SQLCODE'=0)||(id="") ""
	Quit ##class(CareBridge.Data.ExceptionCase).%OpenId(id)
}

}
