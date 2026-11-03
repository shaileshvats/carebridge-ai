/// Registers an inbound result as an immutable MessageRecord and assigns its correlation id.
Class CareBridge.Engine.Intake Extends %RegisteredObject
{

ClassMethod NewCorrelationId() As %String
{
	Quit "CB-"_$ZDATE($HOROLOG, 8)_"-"_$TRANSLATE($JUSTIFY($INCREMENT(^CareBridge.Seq), 6), " ", "0")
}

ClassMethod Register(text As %String, sessionId As %Integer = "", docId As %String = "", Output sc As %Status) As CareBridge.Data.MessageRecord
{
	Set sc = $$$OK
	Set parsed = ##class(CareBridge.Engine.HL7Parser).Parse(text)
	Set r = ##class(CareBridge.Data.MessageRecord).%New()
	Set r.CorrelationId = ..NewCorrelationId()
	Set r.ControlId = parsed.msh.controlId
	Set r.SendingApplication = parsed.msh.sendingApplication
	Set r.SendingFacility = parsed.msh.sendingFacility
	Set r.IdempotencyKey = parsed.msh.sendingApplication_"|"_parsed.msh.sendingFacility_"|"_parsed.msh.controlId
	Set r.MessageType = parsed.msh.messageType
	Set r.PatientRef = parsed.pid.mrn
	Set r.OrderRef = parsed.obr.placerOrderNumber
	Set r.ResultStatus = ##class(CareBridge.Engine.HL7Parser).ResultStatus(parsed)
	Set r.ContentHash = ##class(CareBridge.Engine.HL7Parser).ContentHash(parsed)
	Set r.SessionId = sessionId
	Set r.InboundDocId = docId
	Set r.Scenario = $GET(^CareBridge.DemoScenario(parsed.msh.controlId))
	Do r.RawMessage.Write(text)
	Set sc = r.%Save()
	If $$$ISOK(sc) {
		Do ##class(CareBridge.Data.AuditEvent).Log(r.CorrelationId, "RECEIVED", "LIS.ORU.In", "ORU from "_r.SendingApplication_" control id "_r.ControlId_$SELECT(r.Scenario'="":" (demo scenario "_r.Scenario_")", 1:""))
	}
	Quit r
}

/// Open an exception case for a record.
ClassMethod OpenCase(record As CareBridge.Data.MessageRecord, type As %String, findings As %DynamicArray, context As %DynamicObject, Output sc As %Status) As CareBridge.Data.ExceptionCase
{
	Set c = ##class(CareBridge.Data.ExceptionCase).%New()
	Set c.Message = record
	Set c.CorrelationId = record.CorrelationId
	Set c.ExceptionType = type
	Set c.Findings = findings.%ToJSON()
	Set c.Context = context.%ToJSON()
	Set sc = c.%Save()
	Do ##class(CareBridge.Data.AuditEvent).Log(record.CorrelationId, "EXCEPTION_RAISED", "CareBridge.LabResultRouter", type_" (case "_c.%Id()_")")
	Quit c
}

}
