/// Maintains the synthetic patient and order registry from the simulated HIS feed:
/// ADT^A04 / A08 / A28 register or update a patient; ORM^O01 places (NW) or cancels (CA) an order.
Class CareBridge.Process.HISRegistry Extends Ens.BusinessProcess
{

Method OnRequest(pRequest As EnsLib.HL7.Message, Output pResponse As %Library.Persistent) As %Status
{
	Set sc = $$$OK
	Try {
		Set text = pRequest.OutputToString($CHAR(13), , .sc)
		Quit:$$$ISERR(sc)
		Set p = ##class(CareBridge.Engine.HL7Parser).Parse(text)
		Set corr = "HIS-"_p.msh.controlId
		Set type = p.msh.messageType
		If $EXTRACT(type, 1, 3) = "ADT" {
			Set sc = ..UpsertPatient(p)
			Do ##class(CareBridge.Data.AuditEvent).Log(corr, "HIS_PATIENT_UPDATED", ..%ConfigName, type_" MRN "_p.pid.mrn)
		} ElseIf type = "ORM^O01" {
			Set sc = ..UpsertPatient(p)
			Quit:$$$ISERR(sc)
			Set sc = ..ApplyOrder(p)
			Do ##class(CareBridge.Data.AuditEvent).Log(corr, "HIS_ORDER_UPDATED", ..%ConfigName, p.orc.orderControl_" order "_p.orc.placerOrderNumber_" for MRN "_p.pid.mrn)
		} Else {
			Do ##class(CareBridge.Data.AuditEvent).Log(corr, "HIS_IGNORED", ..%ConfigName, "Unhandled type "_type)
		}
	} Catch ex {
		Set sc = ex.AsStatus()
	}
	Quit sc
}

ClassMethod UpsertPatient(p As %DynamicObject) As %Status
{
	Quit:p.pid.mrn="" $$$ERROR($$$GeneralError, "HIS message without PID-3")
	Set pat = ##class(CareBridge.Data.Patient).MRNIdxOpen(p.pid.mrn)
	If '$ISOBJECT(pat) Set pat = ##class(CareBridge.Data.Patient).%New(), pat.MRN = p.pid.mrn
	Set:p.pid.familyName'="" pat.FamilyName = p.pid.familyName
	Set:p.pid.givenName'="" pat.GivenName = p.pid.givenName
	Set:p.pid.birthDate'="" pat.BirthDate = p.pid.birthDate
	Set:p.pid.sex'="" pat.Sex = p.pid.sex
	Set pat.LastADTControlId = p.msh.controlId
	Set pat.UpdatedAt = $ZDATETIME($ZTIMESTAMP, 3)
	Quit pat.%Save()
}

ClassMethod ApplyOrder(p As %DynamicObject) As %Status
{
	Set placer = $SELECT(p.orc.placerOrderNumber'="":p.orc.placerOrderNumber, 1:p.obr.placerOrderNumber)
	Quit:placer="" $$$ERROR($$$GeneralError, "ORM without a placer order number")
	Set o = ##class(CareBridge.Data.LabOrder).PlacerIdxOpen(placer)
	If p.orc.orderControl = "CA" {
		Quit:'$ISOBJECT(o) $$$OK
		Set o.Status = "CANCELLED"
		Quit o.%Save()
	}
	If '$ISOBJECT(o) Set o = ##class(CareBridge.Data.LabOrder).%New(), o.PlacerOrderNumber = placer
	Set o.MRN = p.pid.mrn
	Set o.TestCode = p.obr.testCode
	Set o.TestName = p.obr.testName
	Set o.FillerOrderNumber = p.obr.fillerOrderNumber
	Quit o.%Save()
}

}
