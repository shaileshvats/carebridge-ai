/// Turns due RETRY queue items into RetryRequests for the result router.
Class CareBridge.Service.RetryScheduler Extends Ens.BusinessService
{

Parameter ADAPTER = "CareBridge.Adapter.DueWorkInboundAdapter";

Property TargetConfigName As Ens.DataType.ConfigName [ InitialExpression = "CareBridge.LabResultRouter" ];

Parameter SETTINGS = "TargetConfigName:Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=1}";

Method OnProcessInput(pInput As CareBridge.Data.QueueItem, Output pOutput As %RegisteredObject) As %Status
{
	Set req = ##class(CareBridge.Msg.RetryRequest).%New()
	Set req.CorrelationId = pInput.CorrelationId
	Set req.QueueItemId = pInput.%Id()
	Do ##class(CareBridge.Data.AuditEvent).Log(pInput.CorrelationId, "RETRY_DUE", ..%ConfigName, "Queue item "_pInput.%Id())
	Quit ..SendRequestAsync(..TargetConfigName, req)
}

}
