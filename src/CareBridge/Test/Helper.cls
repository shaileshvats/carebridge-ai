/// Shared fixtures for CareBridge unit tests. Test rows use correlation ids starting with "TST-".
Class CareBridge.Test.Helper Extends %RegisteredObject
{

ClassMethod ORU(mrn As %String = "MRN100001", order As %String = "ORD-1001", value As %String = "91", ctl As %String = "", note As %String = "", dob As %String = "19740312") As %String
{
	Set:ctl="" ctl = "TST"_$INCREMENT(^CareBridge.TestCtl)
	Set t = "MSH|^~\&|SYNTH-LIS|SYNTH-LAB|CAREBRIDGE|SYNTH-HOSP|20261104120000||ORU^R01^ORU_R01|"_ctl_"|P|2.5.1"_$CHAR(13)_
		"PID|1||"_mrn_"^^^SYNTH-HOSP^MR||SYNTHETIC^PATIENT||"_dob_"|F"_$CHAR(13)_
		"OBR|1|"_order_"|F-"_order_"|2345-7^Glucose^LN|||20261104115000|||||||||||||||20261104120000|||F"_$CHAR(13)_
		"OBX|1|NM|2345-7^Glucose^LN||"_value_"|mg/dL|70-99|N|||F"
	If note '= "" Set t = t_$CHAR(13)_"NTE|1||"_note
	Quit t
}

/// Save a MessageRecord for HL7 text without running the production.
ClassMethod Record(text As %String, attempts As %Integer = 0) As CareBridge.Data.MessageRecord
{
	Set p = ##class(CareBridge.Engine.HL7Parser).Parse(text)
	Set r = ##class(CareBridge.Data.MessageRecord).%New()
	Set r.CorrelationId = "TST-"_$INCREMENT(^CareBridge.TestSeq)
	Set r.ControlId = p.msh.controlId
	Set r.IdempotencyKey = p.msh.sendingApplication_"|"_p.msh.sendingFacility_"|"_p.msh.controlId
	Set r.PatientRef = p.pid.mrn, r.OrderRef = p.obr.placerOrderNumber
	Set r.ResultStatus = ##class(CareBridge.Engine.HL7Parser).ResultStatus(p)
	Set r.ContentHash = ##class(CareBridge.Engine.HL7Parser).ContentHash(p)
	Set r.DeliveryAttempts = attempts
	Do r.RawMessage.Write(text)
	Do r.%Save()
	Quit r
}

/// Validate a record and open its case (as the router would).
ClassMethod Case(r As CareBridge.Data.MessageRecord, type As %String = "") As CareBridge.Data.ExceptionCase
{
	Set v = ##class(CareBridge.Engine.Validator).Validate(##class(CareBridge.Engine.HL7Parser).Parse(r.RawText()), r)
	Set c = ##class(CareBridge.Data.ExceptionCase).%New()
	Set c.Message = r, c.CorrelationId = r.CorrelationId
	Set c.ExceptionType = $SELECT(type'="":type, 1:v.exceptionType)
	Set c.Findings = v.findings.%ToJSON(), c.Context = v.context.%ToJSON()
	Do c.%Save()
	Quit c
}

ClassMethod Rec(type As %String, action As %String, evidence As %DynamicArray, human As %Boolean = 0) As %DynamicObject
{
	Set r = {"exception_type":(type), "recommended_action":(action), "reason":"test", "evidence":(evidence)}
	Do r.%Set("requires_human_review", human, "boolean")
	Quit r
}

ClassMethod Cleanup()
{
	&sql(DELETE FROM CareBridge_Data.ToolCall WHERE AgentRun->CorrelationId %STARTSWITH 'TST-')
	&sql(DELETE FROM CareBridge_Data.PolicyEvaluation WHERE CorrelationId %STARTSWITH 'TST-')
	&sql(DELETE FROM CareBridge_Data.AgentRun WHERE CorrelationId %STARTSWITH 'TST-')
	&sql(DELETE FROM CareBridge_Data.ExceptionCase WHERE CorrelationId %STARTSWITH 'TST-')
	&sql(DELETE FROM CareBridge_Data.DeliveredResult WHERE CorrelationId %STARTSWITH 'TST-')
	&sql(DELETE FROM CareBridge_Data.MessageRecord WHERE CorrelationId %STARTSWITH 'TST-')
	// Test audit rows are removed through the storage directly; the class itself refuses updates.
	Set ^||CareBridge.AllowAuditPurge = 1
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM CareBridge_Data.AuditEvent WHERE CorrelationId %STARTSWITH 'TST-'")
	While rs.%Next() { Do ##class(CareBridge.Data.AuditEvent).%DeleteId(rs.ID) }
	Kill ^||CareBridge.AllowAuditPurge
}

}
