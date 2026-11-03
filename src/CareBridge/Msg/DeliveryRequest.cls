/// Process -> EMR.ClinicalReceiver: deliver the original result unchanged.
Class CareBridge.Msg.DeliveryRequest Extends Ens.Request
{

Property CorrelationId As %String(MAXLEN = 40);

Property Attempt As %Integer;

}
