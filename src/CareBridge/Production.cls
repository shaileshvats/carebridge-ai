/// CareBridge AI interoperability production.
/// HIS (ADT/ORM, MLLP :7010) and LIS (ORU, MLLP :7011) feed the router; exceptions go to the
/// ExceptionInvestigator AI Hub agent; the policy gate decides; operations deliver, quarantine,
/// reject or hand the case to people through the Workflow Engine.
Class CareBridge.Production Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="CareBridge.Production" TestingEnabled="true" LogGeneralTraceEvents="false">
  <Description>CareBridge AI - laboratory result routing with an AI Hub exception investigator and a deterministic policy gate</Description>
  <ActorPoolSize>2</ActorPoolSize>
  <Item Name="HIS.ADT.In" Category="HIS" ClassName="EnsLib.HL7.Service.TCPService" PoolSize="1" Enabled="true" Foreground="false" Comment="Simulated Hospital Information System: patient registration (ADT) and orders (ORM)">
    <Setting Target="Adapter" Name="Port">7010</Setting>
    <Setting Target="Adapter" Name="StayConnected">30</Setting>
    <Setting Target="Host" Name="MessageSchemaCategory">2.5.1</Setting>
    <Setting Target="Host" Name="TargetConfigNames">CareBridge.HISRegistry</Setting>
    <Setting Target="Host" Name="AckMode">Immed</Setting>
  </Item>
  <Item Name="LIS.ORU.In" Category="LIS" ClassName="EnsLib.HL7.Service.TCPService" PoolSize="1" Enabled="true" Foreground="false" Comment="Simulated Laboratory Information System: results (ORU^R01)">
    <Setting Target="Adapter" Name="Port">7011</Setting>
    <Setting Target="Adapter" Name="StayConnected">30</Setting>
    <Setting Target="Host" Name="MessageSchemaCategory">2.5.1</Setting>
    <Setting Target="Host" Name="TargetConfigNames">CareBridge.LabResultRouter</Setting>
    <Setting Target="Host" Name="AckMode">Immed</Setting>
  </Item>
  <Item Name="CareBridge.RetryScheduler" Category="CareBridge" ClassName="CareBridge.Service.RetryScheduler" PoolSize="1" Enabled="true" Foreground="false" Comment="Custom adapter: dispatches scheduled delivery retries when due">
    <Setting Target="Adapter" Name="CallInterval">5</Setting>
  </Item>
  <Item Name="CareBridge.HISRegistry" Category="HIS" ClassName="CareBridge.Process.HISRegistry" PoolSize="1" Enabled="true" Foreground="false">
  </Item>
  <Item Name="CareBridge.LabResultRouter" Category="CareBridge" ClassName="CareBridge.Process.LabResultRouter" PoolSize="1" Enabled="true" Foreground="false" Comment="Validate, investigate exceptions, apply the policy gate, execute">
  </Item>
  <Item Name="CareBridge.ExceptionInvestigator" Category="CareBridge,AI" ClassName="CareBridge.Operation.ExceptionInvestigator" PoolSize="1" Enabled="true" Foreground="false" Comment="Runs the CareBridge.ExceptionInvestigator AI Hub agent (LIVE) or the replay adapter (REPLAY)">
    <Setting Target="Host" Name="DefaultMode">REPLAY</Setting>
  </Item>
  <Item Name="EMR.ClinicalReceiver" Category="EMR" ClassName="CareBridge.Operation.ClinicalReceiver" PoolSize="1" Enabled="true" Foreground="false" Comment="Simulated downstream clinical record system">
    <Setting Target="Host" Name="OutboxDirectory">/home/irisowner/carebridge/emr-inbox/</Setting>
  </Item>
  <Item Name="CareBridge.Quarantine" Category="CareBridge" ClassName="CareBridge.Operation.QuarantineStore" PoolSize="1" Enabled="true" Foreground="false">
    <Setting Target="Host" Name="QuarantineDirectory">/home/irisowner/carebridge/quarantine/</Setting>
  </Item>
  <Item Name="LIS.RejectNotifier" Category="LIS" ClassName="CareBridge.Operation.RejectNotifier" PoolSize="1" Enabled="true" Foreground="false" Comment="Application-reject ACKs back to the laboratory">
  </Item>
  <Item Name="CareBridge.ManualReview" Category="CareBridge,Workflow" ClassName="EnsLib.Workflow.Operation" PoolSize="1" Enabled="true" Foreground="false" Comment="Workflow Engine: hands review tasks to the CareBridge.ManualReview role">
    <Setting Target="Host" Name="AutoCreateRole">1</Setting>
  </Item>
</Production>
}

}
