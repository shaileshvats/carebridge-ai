/// Process -> CareBridge.ExceptionInvestigator: investigate one exception case.
Class CareBridge.Msg.InvestigationRequest Extends Ens.Request
{

Property CorrelationId As %String(MAXLEN = 40);

Property CaseId As %String(MAXLEN = 20);

Property ExceptionType As %String(MAXLEN = 40);

/// Sanitised JSON input for the agent (see CareBridge.Engine.ContextBuilder).
Property InputPayload As %String(MAXLEN = "");

/// Demo scenario label, used by the replay adapter to pick a scripted recommendation.
Property Scenario As %String(MAXLEN = 40);

}
