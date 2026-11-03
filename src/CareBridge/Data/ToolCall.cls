/// A read-only tool call made by the agent, captured by CareBridge.AI.ToolAudit (an AI Hub audit policy)
/// or by the replay adapter.
Class CareBridge.Data.ToolCall Extends (%Persistent, %JSON.Adaptor)
{

Property AgentRun As CareBridge.Data.AgentRun;

Property Seq As %Integer;

Property ToolName As %String(MAXLEN = 120);

Property Arguments As %String(MAXLEN = 4000);

/// First 1000 characters of the tool result. Results contain synthetic data only.
Property ResultSummary As %String(MAXLEN = 1200);

Property DurationMs As %Integer;

Property Success As %Boolean;

Property Error As %String(MAXLEN = 2000);

/// ALLOWED or DENIED by CareBridge.AI.ToolGuard.
Property Authorization As %String(MAXLEN = 10) [ InitialExpression = "ALLOWED" ];

Property CalledAt As %TimeStamp [ InitialExpression = {$ZDATETIME($ZTIMESTAMP, 3)} ];

Index RunIdx On AgentRun;

}
