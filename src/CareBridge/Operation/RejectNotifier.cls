/// Tells the sending LIS a result was rejected: builds an HL7 application-reject ACK (MSA|AR)
/// for the original control id and records it as a REJECT_NOTICE item for the LIS outbox.
Class CareBridge.Operation.RejectNotifier Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

Method Notify(pRequest As CareBridge.Msg.QueueRequest, Output pResponse As CareBridge.Msg.QueueResponse) As %Status
{
	Set record = ##class(CareBridge.Data.MessageRecord).OpenByCorrelation(pRequest.CorrelationId)
	Quit:'$ISOBJECT(record) $$$ERROR($$$GeneralError, "Unknown correlation id "_pRequest.CorrelationId)
	Set ts = $TRANSLATE($ZDATETIME($HOROLOG, 8), " :")
	Set ack = "MSH|^~\&|CAREBRIDGE|SYNTH-HOSP|"_record.SendingApplication_"|"_record.SendingFacility_"|"_ts_"||ACK^R01|ACK"_record.ControlId_"|P|2.5.1"_$CHAR(13)_
		"MSA|AR|"_record.ControlId_"|"_$TRANSLATE($EXTRACT(pRequest.Reason, 1, 80), "|^~\&", "     ")
	Set item = ##class(CareBridge.Data.QueueItem).%New()
	Set item.Queue = "REJECT_NOTICE"
	Set item.CorrelationId = pRequest.CorrelationId
	Do item.ExceptionCaseSetObjectId(pRequest.CaseId)
	Set item.Reason = ack
	Set item.Status = "DONE"
	Set sc = item.%Save()
	Quit:$$$ISERR(sc) sc
	Do ##class(CareBridge.Data.AuditEvent).Log(pRequest.CorrelationId, "REJECT_NOTICE_SENT", ..%ConfigName, "MSA|AR for control id "_record.ControlId)
	Set pResponse = ##class(CareBridge.Msg.QueueResponse).%New()
	Set pResponse.QueueItemId = item.%Id()
	Quit $$$OK
}

XData MessageMap
{
<MapItems>
	<MapItem MessageType="CareBridge.Msg.QueueRequest">
		<Method>Notify</Method>
	</MapItem>
</MapItems>
}

}
