/// The deterministic policy gate's verdict on one recommendation (from the agent or a human reviewer).
Class CareBridge.Data.PolicyEvaluation Extends (%Persistent, %JSON.Adaptor)
{

Property CorrelationId As %String(MAXLEN = 40);

Property ExceptionCase As CareBridge.Data.ExceptionCase;

Property AgentRun As CareBridge.Data.AgentRun;

/// AGENT or HUMAN
Property Source As %String(MAXLEN = 10);

Property RecommendedAction As %String(MAXLEN = 40);

/// 1 if the recommendation was executed as given.
Property Approved As %Boolean;

/// Action actually executed.
Property FinalAction As %String(MAXLEN = 24);

/// JSON array of {rule, result, detail}.
Property Rules As %String(MAXLEN = 8000);

Property Summary As %String(MAXLEN = 1000);

Property EvaluatedAt As %TimeStamp [ InitialExpression = {$ZDATETIME($ZTIMESTAMP, 3)} ];

Index CaseIdx On ExceptionCase;

Index CorrelationIdx On CorrelationId;

}
