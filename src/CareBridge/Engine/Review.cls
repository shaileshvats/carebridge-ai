/// Bridges the dashboard's review queue to Workflow Engine tasks.
/// A reviewer's choice completes the workflow task; the LabResultRouter then receives it in OnResponse
/// and runs it through the policy gate before anything is executed.
Class CareBridge.Engine.Review Extends %RegisteredObject
{

/// Open review tasks for the CareBridge.ManualReview role, joined to their exception cases.
ClassMethod OpenTasks() As %DynamicArray
{
	Set out = []
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM EnsLib_Workflow.TaskResponse WHERE TaskStatus_IsComplete = 0 AND TaskStatus_Role = ? ORDER BY ID DESC", ##class(CareBridge.Setup.Installer).#REVIEWROLE)
	While rs.%Next() {
		Set t = ##class(EnsLib.Workflow.TaskResponse).%OpenId(rs.ID)
		Continue:'$ISOBJECT(t)
		Set caseId = ..CaseIdFromTask(t)
		Set c = ##class(CareBridge.Data.ExceptionCase).%OpenId(caseId)
		Continue:'$ISOBJECT(c)
		Set r = c.Message
		Set lastEval = ""
		&sql(SELECT TOP 1 Summary INTO :lastEval FROM CareBridge_Data.PolicyEvaluation WHERE ExceptionCase = :caseId ORDER BY ID DESC)
		Do out.%Push({
			"taskId":(t.%Id()), "caseId":(caseId), "correlationId":(r.CorrelationId), "exceptionType":(c.ExceptionType),
			"patientRef":(r.PatientRef), "orderRef":(r.OrderRef), "scenario":(r.Scenario), "subject":(t.%Subject), "message":(t.%Message),
			"priority":(t.%Priority), "actions":(t.%Actions), "createdAt":(t.%TaskStatus.TimeCreated), "lastPolicy":(lastEval)
		})
	}
	Quit out
}

/// The router sets the case id in the task request; it is also the second piece of the completion key.
ClassMethod CaseIdFromTask(t As EnsLib.Workflow.TaskResponse) As %String
{
	Set msg = t.%Message
	Quit $PIECE($PIECE(msg, "Case ", 2), ".", 1)
}

ClassMethod FindTask(caseId As %String) As EnsLib.Workflow.TaskResponse
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM EnsLib_Workflow.TaskResponse WHERE TaskStatus_IsComplete = 0 AND TaskStatus_Role = ? ORDER BY ID DESC", ##class(CareBridge.Setup.Installer).#REVIEWROLE)
	While rs.%Next() {
		Set t = ##class(EnsLib.Workflow.TaskResponse).%OpenId(rs.ID)
		If $ISOBJECT(t) && (..CaseIdFromTask(t) = caseId) Return t
	}
	Quit ""
}

/// Complete the open review task for a case with the reviewer's action and note.
/// The policy gate evaluates it in the router; this method only checks the request is well formed.
ClassMethod Decide(caseId As %String, action As %String, note As %String, reviewer As %String) As %DynamicObject
{
	Set action = $ZCONVERT($GET(action), "U"), note = $GET(note), reviewer = $GET(reviewer)
	If '##class(EnsLib.Workflow.UserDefinition).%ExistsId(reviewer) Quit {"error":"Unknown reviewer"}
	Set t = ..FindTask(caseId)
	If '$ISOBJECT(t) Quit {"error":"No open review task for case "_caseId}
	If '$LISTFIND($LISTFROMSTRING(t.%Actions), action) Quit {"error":"Action "_action_" is not offered for this case"}
	Set t.%UserName = reviewer
	Do t.%FormValues.SetAt(note, "Note")
	Set sc = t.%Save()
	If $$$ISERR(sc) Quit {"error":($SYSTEM.Status.GetErrorText(sc))}
	Set sc = t.CompleteTask(action)
	If $$$ISERR(sc) Quit {"error":($SYSTEM.Status.GetErrorText(sc))}
	Quit {"caseId":(caseId), "taskId":(t.%Id()), "submitted":(action), "note":"Sent to the policy gate; refresh the message to see the result"}
}

}
