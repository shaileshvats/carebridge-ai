/// Simulated downstream clinical record system. Accepts each result at most once and can be told
/// to fail the next N deliveries (CareBridge.Data.ReceiverControl) to reproduce a temporary outage.
Class CareBridge.Operation.ClinicalReceiver Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

/// Optional directory where each delivered result is also written as an .hl7 file.
Property OutboxDirectory As %String(MAXLEN = 300);

Parameter SETTINGS = "OutboxDirectory:Basic";

Method Deliver(pRequest As CareBridge.Msg.DeliveryRequest, Output pResponse As CareBridge.Msg.DeliveryResponse) As %Status
{
	Set pResponse = ##class(CareBridge.Msg.DeliveryResponse).%New()
	If ##class(CareBridge.Data.ReceiverControl).ConsumeFailure() {
		Quit $$$ERROR($$$GeneralError, "Clinical receiver unavailable (simulated timeout after 30s)")
	}
	Set record = ##class(CareBridge.Data.MessageRecord).OpenByCorrelation(pRequest.CorrelationId)
	Quit:'$ISOBJECT(record) $$$ERROR($$$GeneralError, "Unknown correlation id "_pRequest.CorrelationId)

	Set existing = ##class(CareBridge.Data.DeliveredResult).CorrelationIdxOpen(pRequest.CorrelationId)
	If $ISOBJECT(existing) {
		Set pResponse.Delivered = 1, pResponse.AlreadyDelivered = 1, pResponse.ReceiverRef = existing.%Id()
		Quit $$$OK
	}
	Set d = ##class(CareBridge.Data.DeliveredResult).%New()
	Set d.CorrelationId = record.CorrelationId
	Set d.PatientRef = record.PatientRef
	Set d.OrderRef = record.OrderRef
	Set d.ContentHash = record.ContentHash
	Do record.RawMessage.Rewind()
	Do d.Payload.CopyFrom(record.RawMessage)
	Set sc = d.%Save()
	// The unique index on ContentHash refuses a second copy of identical content.
	Quit:$$$ISERR(sc) $$$ERROR($$$GeneralError, "Receiver refused the result: "_$SYSTEM.Status.GetErrorText(sc))

	// Best effort: a file copy must never decide whether the message was handled.
	If ..OutboxDirectory '= "" {
		Try {
		Do ##class(%File).CreateDirectoryChain(..OutboxDirectory)
		Set file = ##class(%Stream.FileCharacter).%New()
		Set file.Filename = ##class(%File).NormalizeFilename(record.CorrelationId_".hl7", ..OutboxDirectory)
		Do record.RawMessage.Rewind()
		Do file.CopyFrom(record.RawMessage)
		Do file.%Save()
		} Catch {}
	}
	Set orderRef = record.OrderRef
	&sql(UPDATE CareBridge_Data.LabOrder SET Status = 'RESULTED' WHERE PlacerOrderNumber = :orderRef)
	Set pResponse.Delivered = 1, pResponse.AlreadyDelivered = 0, pResponse.ReceiverRef = d.%Id()
	Quit $$$OK
}

XData MessageMap
{
<MapItems>
	<MapItem MessageType="CareBridge.Msg.DeliveryRequest">
		<Method>Deliver</Method>
	</MapItem>
</MapItems>
}

}
