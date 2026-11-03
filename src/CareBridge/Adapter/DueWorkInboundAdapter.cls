/// Custom inbound adapter: polls the CareBridge work queue for items that have become due
/// (e.g. scheduled delivery retries) and hands each one to its business service exactly once.
Class CareBridge.Adapter.DueWorkInboundAdapter Extends Ens.InboundAdapter
{

/// Queue name to watch (RETRY by default).
Property Queue As %String [ InitialExpression = "RETRY" ];

/// Maximum items handed over per poll.
Property BatchSize As %Integer [ InitialExpression = 20 ];

Parameter SETTINGS = "Queue:Basic,BatchSize:Basic";

Method OnTask() As %Status
{
	Set sc = $$$OK
	Set now = $ZDATETIME($ZTIMESTAMP, 3), queue = ..Queue, n = 0
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP ? ID FROM CareBridge_Data.QueueItem WHERE Queue = ? AND Status = 'OPEN' AND DueAt <= ? ORDER BY DueAt", ..BatchSize, queue, now)
	While rs.%Next() {
		Set id = rs.%Get("ID")
		// Claim the item before dispatch so a slow service never sees it twice.
		&sql(UPDATE CareBridge_Data.QueueItem SET Status = 'DISPATCHED' WHERE ID = :id AND Status = 'OPEN')
		Continue:(SQLCODE'=0)||(%ROWCOUNT'=1)
		Set item = ##class(CareBridge.Data.QueueItem).%OpenId(id)
		Set sc = ..BusinessHost.ProcessInput(item)
		If $$$ISERR(sc) {
			// Put it back so the next poll retries the hand-over.
			&sql(UPDATE CareBridge_Data.QueueItem SET Status = 'OPEN' WHERE ID = :id)
			Quit
		}
		Set n = n + 1
	}
	Set ..BusinessHost.%WaitForNextCallInterval = 1
	Quit sc
}

}
