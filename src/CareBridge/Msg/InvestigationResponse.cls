/// CareBridge.ExceptionInvestigator -> process: the agent's validated recommendation, or why there is none.
Class CareBridge.Msg.InvestigationResponse Extends Ens.Response
{

Property AgentRunId As %String(MAXLEN = 20);

/// OK, INVALID_OUTPUT, TIMEOUT, PROVIDER_ERROR, NOT_AVAILABLE
Property Outcome As %String(MAXLEN = 24);

Property Mode As %String(MAXLEN = 10);

/// Validated recommendation JSON (empty unless Outcome = OK).
Property Recommendation As %String(MAXLEN = "");

Property RecommendedAction As %String(MAXLEN = 40);

}
