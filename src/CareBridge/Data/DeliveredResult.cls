/// Inbox of the simulated downstream clinical record system. One row per accepted result.
Class CareBridge.Data.DeliveredResult Extends (%Persistent, %JSON.Adaptor)
{

Property CorrelationId As %String(MAXLEN = 40) [ Required ];

Property PatientRef As %String(MAXLEN = 32);

Property OrderRef As %String(MAXLEN = 32);

Property ContentHash As %String(MAXLEN = 64);

/// HL7 text as forwarded (unchanged from the original).
Property Payload As %Stream.GlobalCharacter;

Property DeliveredAt As %TimeStamp [ InitialExpression = {$ZDATETIME($ZTIMESTAMP, 3)} ];

/// One delivery per message: the receiver refuses a second copy of the same correlation id.
Index CorrelationIdx On CorrelationId [ Unique ];

/// A second copy of identical content is refused at the database level (idempotent side effect).
Index ContentIdx On ContentHash [ Unique ];

}
