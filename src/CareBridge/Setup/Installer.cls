/// Installation, seeding and reset. Called by the IPM module on install and by the Docker build.
Class CareBridge.Setup.Installer Extends %RegisteredObject
{

/// Workflow role that receives review tasks (same name as the EnsLib.Workflow.Operation item).
Parameter REVIEWROLE = "CareBridge.ManualReview";

/// Synthetic reviewers available in the demo.
Parameter REVIEWERS = "reviewer.demo,lab.supervisor";

/// Full install: config defaults, seed data, workflow role and users, production autostart.
ClassMethod Install() As %Status
{
	Set sc = $$$OK
	Try {
		Do ..ConfigDefaults()
		$$$ThrowOnError(..Seed())
		$$$ThrowOnError(..SetupWorkflow())
		$$$ThrowOnError(##class(Ens.Director).SetAutoStart("CareBridge.Production", 0))
		Write "CareBridge installed in namespace ", $NAMESPACE, !
	} Catch ex {
		Set sc = ex.AsStatus()
	}
	Quit sc
}

/// Install then start the production (used where a running production is wanted immediately).
ClassMethod InstallAndStart() As %Status
{
	Set sc = ..Install()
	Quit:$$$ISERR(sc) sc
	Quit ..StartProduction()
}

ClassMethod StartProduction() As %Status
{
	If ##class(Ens.Director).IsProductionRunning() Quit $$$OK
	Quit ##class(Ens.Director).StartProduction("CareBridge.Production")
}

ClassMethod ConfigDefaults()
{
	Set:$GET(^CareBridge.Config("MaxDeliveryAttempts"))="" ^CareBridge.Config("MaxDeliveryAttempts") = 3
}

/// Synthetic registry: six patients and their orders. Every value is fictional.
ClassMethod Seed() As %Status
{
	Set patients = [
		["MRN100001","SYNTHETIC","ALPHA","19740312","F"],
		["MRN100002","SYNTHETIC","BRAVO","19620721","M"],
		["MRN100003","SYNTHETIC","CHARLIE","19910203","F"],
		["MRN100004","SYNTHETIC","DELTA","19550930","F"],
		["MRN100005","SYNTHETIC","ECHO","20010614","M"],
		["MRN100006","SYNTHETIC","FOXTROT","19790825","F"]
	]
	Set orders = [
		["ORD-1001","MRN100001","2345-7","Glucose"],
		["ORD-1002","MRN100002","2345-7","Glucose"],
		["ORD-1003","MRN100003","718-7","Hemoglobin"],
		["ORD-1004","MRN100004","2951-2","Sodium"],
		["ORD-1005","MRN100001","2345-7","Glucose"],
		["ORD-1006","MRN100001","2345-7","Glucose"],
		["ORD-1007","MRN100006","2951-2","Sodium"],
		["ORD-1008","MRN100002","2160-0","Creatinine"],
		["ORD-1009","MRN100005","718-7","Hemoglobin"]
	]
	Set iter = patients.%GetIterator()
	While iter.%GetNext(.i, .p) {
		Set pat = ##class(CareBridge.Data.Patient).MRNIdxOpen(p.%Get(0))
		If '$ISOBJECT(pat) Set pat = ##class(CareBridge.Data.Patient).%New(), pat.MRN = p.%Get(0)
		Set pat.FamilyName = p.%Get(1), pat.GivenName = p.%Get(2), pat.BirthDate = p.%Get(3), pat.Sex = p.%Get(4)
		Set sc = pat.%Save()
		Return:$$$ISERR(sc) sc
	}
	Set iter = orders.%GetIterator()
	While iter.%GetNext(.i, .o) {
		Set ord = ##class(CareBridge.Data.LabOrder).PlacerIdxOpen(o.%Get(0))
		If '$ISOBJECT(ord) Set ord = ##class(CareBridge.Data.LabOrder).%New(), ord.PlacerOrderNumber = o.%Get(0)
		Set ord.MRN = o.%Get(1), ord.TestCode = o.%Get(2), ord.TestName = o.%Get(3), ord.FillerOrderNumber = "F-"_o.%Get(0), ord.Status = "PLACED"
		Set sc = ord.%Save()
		Return:$$$ISERR(sc) sc
	}
	Quit $$$OK
}

/// Create the review role and synthetic reviewers in the Workflow Engine.
ClassMethod SetupWorkflow() As %Status
{
	Set role = ..#REVIEWROLE
	If '##class(EnsLib.Workflow.RoleDefinition).%ExistsId(role) {
		Set sc = ##class(EnsLib.Workflow.RoleDefinition).CreateRole(role, "Reviews CareBridge exception cases")
		Return:$$$ISERR(sc) sc
	}
	For i = 1:1:$LENGTH(..#REVIEWERS, ",") {
		Set user = $PIECE(..#REVIEWERS, ",", i)
		If '##class(EnsLib.Workflow.UserDefinition).%ExistsId(user) {
			Set u = ##class(EnsLib.Workflow.UserDefinition).%New()
			Set u.Name = user, u.FullName = "Synthetic reviewer "_user, u.IsActive = 1
			Set sc = u.%Save()
			Return:$$$ISERR(sc) sc
		}
		Set sc = ##class(EnsLib.Workflow.RoleDefinition).AddUserToRole(role, user)
	}
	Quit $$$OK
}

/// Delete all transactional data (messages, cases, runs, audit, queues, deliveries, open workflow tasks)
/// and restore the synthetic registry. The production keeps running.
ClassMethod Reset() As %Status
{
	Set sc = $$$OK
	Try {
		// Cancel open review tasks so their waiting process instances end cleanly.
		Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM EnsLib_Workflow.TaskResponse WHERE TaskStatus_IsComplete = 0")
		While rs.%Next() {
			Set t = ##class(EnsLib.Workflow.TaskResponse).%OpenId(rs.%Get("ID"))
			If $ISOBJECT(t) Do ##class(EnsLib.Workflow.Engine).CancelRequest(t.%TaskStatus.Request)
		}
		Set ^CareBridge.ReceiverFailNext = 0
		For cls = "ToolCall","PolicyEvaluation","AgentRun","QueueItem","ExceptionCase","DeliveredResult","MessageRecord","Patient","LabOrder" {
			Do $CLASSMETHOD("CareBridge.Data."_cls, "%KillExtent")
		}
		// Audit events are append-only for the application; reset clears the demo trail directly.
		Do ##class(CareBridge.Data.AuditEvent).%KillExtent()
		Kill ^CareBridge.DemoScenario, ^CareBridge.DemoJob
		$$$ThrowOnError(..Seed())
	} Catch ex {
		Set sc = ex.AsStatus()
	}
	Quit sc
}

}
