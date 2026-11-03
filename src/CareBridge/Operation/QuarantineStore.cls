/// Holds results that must not be delivered or discarded: creates an OPEN quarantine item
/// and optionally writes a copy of the original message to a quarantine directory.
Class CareBridge.Operation.QuarantineStore Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

Property QuarantineDirectory As %String(MAXLEN = 300);

Parameter SETTINGS = "QuarantineDirectory:Basic";

Method Quarantine(pRequest As CareBridge.Msg.QueueRequest, Output pResponse As CareBridge.Msg.QueueResponse) As %Status
{
	Set item = ##class(CareBridge.Data.QueueItem).%New()
	Set item.Queue = "QUARANTINE"
	Set item.CorrelationId = pRequest.CorrelationId
	Do item.ExceptionCaseSetObjectId(pRequest.CaseId)
	Set item.Reason = pRequest.Reason
	Set sc = item.%Save()
	Quit:$$$ISERR(sc) sc
	// Best effort: a file copy must never decide whether the message was handled.
	If ..QuarantineDirectory '= "" {
		Try {
		Do ##class(%File).CreateDirectoryChain(..QuarantineDirectory)
		Set record = ##class(CareBridge.Data.MessageRecord).OpenByCorrelation(pRequest.CorrelationId)
		If $ISOBJECT(record) {
			Set file = ##class(%Stream.FileCharacter).%New()
			Set file.Filename = ##class(%File).NormalizeFilename(record.CorrelationId_".hl7", ..QuarantineDirectory)
			Do record.RawMessage.Rewind()
			Do file.CopyFrom(record.RawMessage)
			Do file.%Save()
		}
		} Catch {}
	}
	Do ##class(CareBridge.Data.AuditEvent).Log(pRequest.CorrelationId, "QUARANTINED", ..%ConfigName, "Quarantine item "_item.%Id())
	Set pResponse = ##class(CareBridge.Msg.QueueResponse).%New()
	Set pResponse.QueueItemId = item.%Id()
	Quit $$$OK
}

XData MessageMap
{
<MapItems>
	<MapItem MessageType="CareBridge.Msg.QueueRequest">
		<Method>Quarantine</Method>
	</MapItem>
</MapItems>
}

}
