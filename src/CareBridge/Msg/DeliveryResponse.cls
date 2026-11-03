Class CareBridge.Msg.DeliveryResponse Extends Ens.Response
{

Property Delivered As %Boolean;

/// Set when the receiver already held this result (idempotent no-op).
Property AlreadyDelivered As %Boolean;

Property ReceiverRef As %String(MAXLEN = 40);

}
