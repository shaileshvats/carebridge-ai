/// Test control for the simulated downstream receiver: makes the next N deliveries fail
/// so the temporary-outage scenario is reproducible.
Class CareBridge.Data.ReceiverControl Extends %RegisteredObject
{

Property FailNext As %Integer [ InitialExpression = 0 ];

ClassMethod SetFailNext(n As %Integer) As %Status
{
	Set ^CareBridge.ReceiverFailNext = +n
	Quit $$$OK
}

/// Returns 1 (and decrements the counter) if this delivery should fail.
ClassMethod ConsumeFailure() As %Boolean
{
	Lock +^CareBridge.ReceiverFailNext:5
	Set n = +$GET(^CareBridge.ReceiverFailNext)
	If n > 0 Set ^CareBridge.ReceiverFailNext = n - 1
	Lock -^CareBridge.ReceiverFailNext
	Quit (n > 0)
}

}
