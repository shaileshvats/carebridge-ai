/// Process -> quarantine / review / reject-notice operations.
Class CareBridge.Msg.QueueRequest Extends Ens.Request
{

Property CorrelationId As %String(MAXLEN = 40);

Property CaseId As %String(MAXLEN = 20);

Property Reason As %String(MAXLEN = 2000);

}
