/// An interoperability exception raised by deterministic validation, and its resolution.
Class CareBridge.Data.ExceptionCase Extends (%Persistent, %JSON.Adaptor)
{

Property Message As CareBridge.Data.MessageRecord [ Required ];

Property CorrelationId As %String(MAXLEN = 40);

/// Primary category: UNKNOWN_PATIENT, UNKNOWN_ORDER, DUPLICATE_RESULT, MISSING_REQUIRED_FIELDS,
/// PATIENT_ORDER_CONFLICT, DOWNSTREAM_UNAVAILABLE.
Property ExceptionType As %String(MAXLEN = 40) [ Required ];

/// JSON array of deterministic validation findings (codes and details).
Property Findings As %String(MAXLEN = 30000);

/// JSON object of the synthetic context retrieved at validation time.
Property Context As %String(MAXLEN = 30000);

/// OPEN, AWAITING_REVIEW, RESOLVED
Property Status As %String(MAXLEN = 20) [ InitialExpression = "OPEN" ];

/// Final action applied (after policy, or after human review).
Property Resolution As %String(MAXLEN = 24);

Property ResolvedBy As %String(MAXLEN = 80);

Property ReviewNote As %String(MAXLEN = 4000);

Property CreatedAt As %TimeStamp [ InitialExpression = {$ZDATETIME($ZTIMESTAMP, 3)} ];

Property ResolvedAt As %TimeStamp;

Index MessageIdx On Message;

Index StatusIdx On Status;

Index CorrelationIdx On CorrelationId;

}
