/// Work item for quarantine, manual review or scheduled retry.
Class CareBridge.Data.QueueItem Extends (%Persistent, %JSON.Adaptor)
{

/// QUARANTINE, REVIEW, RETRY, REJECT_NOTICE
Property Queue As %String(MAXLEN = 20) [ Required ];

Property CorrelationId As %String(MAXLEN = 40) [ Required ];

Property ExceptionCase As CareBridge.Data.ExceptionCase;

Property Reason As %String(MAXLEN = 2000);

/// OPEN, DONE, CANCELLED
Property Status As %String(MAXLEN = 12) [ InitialExpression = "OPEN" ];

/// For RETRY items: when the retry scheduler may pick it up.
Property DueAt As %TimeStamp;

Property CreatedAt As %TimeStamp [ InitialExpression = {$ZDATETIME($ZTIMESTAMP, 3)} ];

Property ClosedAt As %TimeStamp;

Index QueueStatusIdx On (Queue, Status);

Index CorrelationIdx On CorrelationId;

}
