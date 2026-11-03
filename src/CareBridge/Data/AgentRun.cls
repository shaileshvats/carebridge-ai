/// One invocation of the CareBridge.ExceptionInvestigator agent, with its trace.
Class CareBridge.Data.AgentRun Extends (%Persistent, %JSON.Adaptor)
{

Property CorrelationId As %String(MAXLEN = 40);

Property ExceptionCase As CareBridge.Data.ExceptionCase;

Property AgentName As %String(MAXLEN = 80) [ InitialExpression = "CareBridge.ExceptionInvestigator" ];

/// LIVE (real AI Hub agent and model) or REPLAY (recorded recommendation, real tools).
Property Mode As %String(MAXLEN = 10);

Property Provider As %String(MAXLEN = 40);

Property Model As %String(MAXLEN = 120);

Property StartedAt As %TimeStamp;

Property EndedAt As %TimeStamp;

Property DurationMs As %Integer;

/// As reported by the provider through AI Hub; empty when not reported. Never estimated.
Property PromptTokens As %Integer;

Property CompletionTokens As %Integer;

/// Model calls made, including corrective retries after malformed output.
Property Attempts As %Integer [ InitialExpression = 0 ];

/// Input sent to the agent (sanitised fields only; see CareBridge.Engine.ContextBuilder).
Property InputPayload As %String(MAXLEN = 30000);

/// Last raw text returned by the model (or the replay fixture).
Property RawOutput As %String(MAXLEN = 30000);

/// Validated recommendation JSON, or empty if no valid output was obtained.
Property Recommendation As %String(MAXLEN = 8000);

Property RecommendedAction As %String(MAXLEN = 40);

/// OK, INVALID_OUTPUT, TIMEOUT, PROVIDER_ERROR, NOT_AVAILABLE
Property Outcome As %String(MAXLEN = 24);

Property Error As %String(MAXLEN = 4000);

Index CaseIdx On ExceptionCase;

Index CorrelationIdx On CorrelationId;

}
