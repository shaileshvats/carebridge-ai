/// Append-only audit trail. Every state change for a message writes one event.
Class CareBridge.Data.AuditEvent Extends (%Persistent, %JSON.Adaptor)
{

Property CorrelationId As %String(MAXLEN = 40) [ Required ];

/// e.g. RECEIVED, VALIDATED, EXCEPTION_RAISED, AGENT_INVOKED, POLICY_EVALUATED, DELIVERED, ...
Property EventType As %String(MAXLEN = 40) [ Required ];

/// Component or person: the production item name, "policy-gate", or a reviewer name.
Property Actor As %String(MAXLEN = 80);

Property Detail As %String(MAXLEN = 8000);

Property At As %TimeStamp [ InitialExpression = {$ZDATETIME($ZTIMESTAMP, 3)} ];

Index CorrelationIdx On CorrelationId;

Index AtIdx On At;

ClassMethod Log(correlationId As %String, eventType As %String, actor As %String = "", detail As %String = "") As %Status
{
	Set e = ..%New()
	Set e.CorrelationId = correlationId
	Set e.EventType = eventType
	Set e.Actor = actor
	Set e.Detail = $EXTRACT(detail, 1, 8000)
	Quit e.%Save()
}

/// Updating or deleting audit events is not allowed.
Method %OnBeforeSave(insert As %Boolean) As %Status [ Private, ServerOnly = 1 ]
{
	Quit $SELECT(insert:$$$OK, 1:$$$ERROR($$$GeneralError, "CareBridge: audit events are append-only"))
}

/// Deleting audit events is refused unless a purge was explicitly opened in this process
/// (CareBridge.Setup.Installer.Reset and the unit-test cleanup do this for demo data).
ClassMethod %OnDelete(oid As %ObjectIdentity) As %Status [ Private, ServerOnly = 1 ]
{
	Quit $SELECT($GET(^||CareBridge.AllowAuditPurge):$$$OK, 1:$$$ERROR($$$GeneralError, "CareBridge: audit events are append-only"))
}

}
