/// One inbound HL7 message as CareBridge first saw it, plus its processing state.
/// RawMessage is written once on receipt and never modified (see %OnBeforeSave).
Class CareBridge.Data.MessageRecord Extends (%Persistent, %JSON.Adaptor)
{

/// Correlation id that follows this message through every table and the Interoperability message trace.
Property CorrelationId As %String(MAXLEN = 40) [ Required ];

/// Sending application + facility + control id (MSH-3/4/10). Not unique: a resend of the same control id
/// is stored as its own record and recognised by validation as a duplicate transmission. Duplicate side
/// effects are prevented downstream by the unique indexes on CareBridge.Data.DeliveredResult.
Property IdempotencyKey As %String(MAXLEN = 200) [ Required ];

/// SHA-256 of the clinically relevant content (patient, order, observations). Used to detect the same
/// result arriving under a different control id.
Property ContentHash As %String(MAXLEN = 64);

Property ControlId As %String(MAXLEN = 64);

Property SendingApplication As %String(MAXLEN = 80);

Property SendingFacility As %String(MAXLEN = 80);

/// e.g. ORU^R01
Property MessageType As %String(MAXLEN = 20);

Property PatientRef As %String(MAXLEN = 32);

Property OrderRef As %String(MAXLEN = 32);

/// Result status from OBR-25 / OBX-11 (F final, C corrected, P preliminary).
Property ResultStatus As %String(MAXLEN = 4);

/// Original message text exactly as received. Immutable.
Property RawMessage As %Stream.GlobalCharacter;

/// SHA-256 of RawMessage, fixed on first save; any later save with different content is refused.
Property RawSHA256 As %String(MAXLEN = 64);

/// RECEIVED, VALIDATING, INVESTIGATING, ACCEPTED, RETRY_PENDING, QUARANTINED, MANUAL_REVIEW, DUPLICATE_SUPPRESSED, REJECTED, FAILED
Property Status As %String(MAXLEN = 24) [ InitialExpression = "RECEIVED" ];

/// Final outcome once processing has finished (one of CareBridge.Engine.Actions).
Property FinalOutcome As %String(MAXLEN = 24);

/// How the final outcome was reached: RULE (no exception), AGENT_POLICY, HUMAN, POLICY_FALLBACK.
Property DecidedBy As %String(MAXLEN = 20);

Property DeliveryAttempts As %Integer [ InitialExpression = 0 ];

/// Interoperability session id of the inbound message (links to the Visual Trace).
Property SessionId As %Integer;

/// Ens.MessageHeader / EnsLib.HL7.Message id of the inbound document.
Property InboundDocId As %String(MAXLEN = 40);

/// Demo scenario label when sent by the demo runner; empty for ordinary traffic.
Property Scenario As %String(MAXLEN = 40);

Property ReceivedAt As %TimeStamp [ InitialExpression = {$ZDATETIME($ZTIMESTAMP, 3)} ];

Property CompletedAt As %TimeStamp;

Index IdempotencyIdx On IdempotencyKey;

Index CorrelationIdx On CorrelationId [ Unique ];

Index ContentHashIdx On ContentHash;

Index PatientIdx On PatientRef;

Index OrderIdx On OrderRef;

Index StatusIdx On Status;

Index ReceivedIdx On ReceivedAt;

/// Refuse to save a changed RawMessage once the record exists.
Method %OnBeforeSave(insert As %Boolean) As %Status [ Private, ServerOnly = 1 ]
{
	Set hash = ..RawHash()
	If insert || (..RawSHA256 = "") {
		Set ..RawSHA256 = hash
		Quit $$$OK
	}
	If hash '= ..RawSHA256 Quit $$$ERROR($$$GeneralError, "CareBridge: the original message is immutable")
	Quit $$$OK
}

Method RawHash() As %String [ Private ]
{
	Quit $ZCONVERT(##class(%xsd.hexBinary).LogicalToXSD($SYSTEM.Encryption.SHAHash(256, $ZCONVERT(..RawText(), "O", "UTF8"))), "L")
}

ClassMethod OpenByCorrelation(correlationId As %String) As CareBridge.Data.MessageRecord
{
	Quit ..CorrelationIdxOpen(correlationId)
}

Method RawText() As %String
{
	Do ..RawMessage.Rewind()
	Quit ..RawMessage.Read(3000000)
}

}
