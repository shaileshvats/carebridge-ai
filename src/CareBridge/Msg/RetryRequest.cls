/// CareBridge.RetryScheduler -> process: a scheduled re-delivery attempt is due.
Class CareBridge.Msg.RetryRequest Extends Ens.Request
{

Property CorrelationId As %String(MAXLEN = 40);

Property QueueItemId As %String(MAXLEN = 20);

}
