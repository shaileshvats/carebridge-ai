/// The toolset given to CareBridge.ExceptionInvestigator: the read-only investigation tools only.
Class CareBridge.AI.InvestigationToolSet Extends %AI.ToolSet [ DependsOn = CareBridge.AI.InvestigationTools ]
{

XData Definition [ MimeType = application/xml ]
{
<ToolSet Name="CareBridgeInvestigation">
	<Description>Read-only lookups over the synthetic hospital registry and CareBridge message history.</Description>
	<Include Class="CareBridge.AI.InvestigationTools"/>
</ToolSet>
}

}
