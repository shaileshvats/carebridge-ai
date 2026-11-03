/// Orchestrates one laboratory result end to end:
/// register -> validate -> deliver, or (on exception) investigate with the AI Hub agent -> policy gate -> execute.
/// Manual review is handed to people through the Interoperability Workflow Engine; the reviewer's
/// decision comes back to OnResponse and passes through the same policy gate.
Class CareBridge.Process.LabResultRouter Extends Ens.BusinessProcess
{

Parameter SETTINGS = "InvestigatorTarget:Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=1},ReceiverTarget:Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=1},QuarantineTarget:Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=1},ReviewTarget:Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=1},RejectTarget:Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=1},RetryDelaySeconds:Basic,InvestigatorTimeout:Basic";

Property InvestigatorTarget As Ens.DataType.ConfigName [ InitialExpression = "CareBridge.ExceptionInvestigator" ];

Property ReceiverTarget As Ens.DataType.ConfigName [ InitialExpression = "EMR.ClinicalReceiver" ];

Property QuarantineTarget As Ens.DataType.ConfigName [ InitialExpression = "CareBridge.Quarantine" ];

/// Workflow operation; its config name is also the workflow role that receives review tasks.
Property ReviewTarget As Ens.DataType.ConfigName [ InitialExpression = "CareBridge.ManualReview" ];

Property RejectTarget As Ens.DataType.ConfigName [ InitialExpression = "LIS.RejectNotifier" ];

Property RetryDelaySeconds As %Integer [ InitialExpression = 15 ];

/// Seconds to wait for the agent before treating the investigation as timed out.
Property InvestigatorTimeout As %Integer [ InitialExpression = 240 ];

/// Correlation id of the message this process instance is handling (persisted across async responses).
Property CorrelationId As %String(MAXLEN = 40);

Method OnRequest(pRequest As %Library.Persistent, Output pResponse As %Library.Persistent) As %Status
{
	Set sc = $$$OK
	Try {
		If pRequest.%IsA("EnsLib.HL7.Message") {
			Set sc = ..HandleResult(pRequest)
		} ElseIf pRequest.%IsA("CareBridge.Msg.RetryRequest") {
			Set sc = ..HandleRetry(pRequest)
		} Else {
			Set sc = $$$ERROR($$$GeneralError, "Unexpected request "_$CLASSNAME(pRequest))
		}
	} Catch ex {
		Set sc = ex.AsStatus()
	}
	If $$$ISERR(sc) && (..CorrelationId '= "") {
		Do ..SetStatus(..CorrelationId, "FAILED")
		Do ##class(CareBridge.Data.AuditEvent).Log(..CorrelationId, "PROCESSING_ERROR", ..%ConfigName, $SYSTEM.Status.GetErrorText(sc))
	}
	Quit sc
}

Method HandleResult(msg As EnsLib.HL7.Message) As %Status
{
	Set text = msg.OutputToString($CHAR(13), , .sc)
	Quit:$$$ISERR(sc) sc
	Set record = ##class(CareBridge.Engine.Intake).Register(text, ..%SessionId, msg.%Id(), .sc)
	Quit:$$$ISERR(sc) sc
	Set ..CorrelationId = record.CorrelationId

	Do ..SetStatus(record.CorrelationId, "VALIDATING")
	Set parsed = ##class(CareBridge.Engine.HL7Parser).Parse(text)
	Set v = ##class(CareBridge.Engine.Validator).Validate(parsed, record)
	If v.ok {
		Do ##class(CareBridge.Data.AuditEvent).Log(record.CorrelationId, "VALIDATED", ..%ConfigName, "No exceptions; patient and order matched")
		Quit ..Deliver(record, "RULE")
	}
	Do ##class(CareBridge.Data.AuditEvent).Log(record.CorrelationId, "VALIDATION_FAILED", ..%ConfigName, v.exceptionType)
	Set case = ##class(CareBridge.Engine.Intake).OpenCase(record, v.exceptionType, v.findings, v.context, .sc)
	Quit:$$$ISERR(sc) sc
	Quit ..InvestigateAndExecute(case, record)
}

Method HandleRetry(req As CareBridge.Msg.RetryRequest) As %Status
{
	Set ..CorrelationId = req.CorrelationId
	Set record = ##class(CareBridge.Data.MessageRecord).OpenByCorrelation(req.CorrelationId)
	Quit:'$ISOBJECT(record) $$$ERROR($$$GeneralError, "Unknown correlation id "_req.CorrelationId)
	Set item = ##class(CareBridge.Data.QueueItem).%OpenId(req.QueueItemId)
	If $ISOBJECT(item) {
		Set item.Status = "DONE", item.ClosedAt = $ZDATETIME($ZTIMESTAMP, 3)
		Do item.%Save()
	}
	Do ##class(CareBridge.Data.AuditEvent).Log(record.CorrelationId, "RETRY_STARTED", ..%ConfigName, "Scheduled re-delivery, attempt "_(record.DeliveryAttempts + 1))
	Quit ..Deliver(record, "AGENT_POLICY")
}

/// Deliver the original, unchanged result to the clinical receiver. A failure becomes a
/// DOWNSTREAM_UNAVAILABLE exception investigated like any other.
Method Deliver(record As CareBridge.Data.MessageRecord, decidedBy As %String) As %Status
{
	Set record.DeliveryAttempts = record.DeliveryAttempts + 1
	Set sc = record.%Save()
	Quit:$$$ISERR(sc) sc
	Set req = ##class(CareBridge.Msg.DeliveryRequest).%New()
	Set req.CorrelationId = record.CorrelationId
	Set req.Attempt = record.DeliveryAttempts
	Set sc = ..SendRequestSync(..ReceiverTarget, req, .resp, 30)
	If $$$ISOK(sc) && $ISOBJECT($GET(resp)) && resp.Delivered {
		Do ##class(CareBridge.Data.AuditEvent).Log(record.CorrelationId, "DELIVERED", ..ReceiverTarget, $SELECT(resp.AlreadyDelivered:"Receiver already held this result (idempotent)", 1:"Delivered on attempt "_record.DeliveryAttempts))
		Quit ..Finish(record, "ACCEPTED", "ACCEPT", decidedBy)
	}
	Set err = $SELECT($$$ISERR(sc):$SYSTEM.Status.GetErrorText(sc), 1:"Receiver did not confirm delivery")
	Do ##class(CareBridge.Data.AuditEvent).Log(record.CorrelationId, "DELIVERY_FAILED", ..ReceiverTarget, "Attempt "_record.DeliveryAttempts_": "_err)
	Set findings = [{"code":"DOWNSTREAM_UNAVAILABLE", "severity":"error", "detail":($EXTRACT(err, 1, 300))}]
	If record.DeliveryAttempts >= ##class(CareBridge.Engine.PolicyGate).MaxDeliveryAttempts() {
		Do findings.%Push({"code":"RETRY_LIMIT_REACHED", "severity":"error", "detail":(record.DeliveryAttempts_" delivery attempts used")})
	}
	Do findings.%Push({"code":"PATIENT_FOUND", "severity":"info", "detail":"Validated before delivery"})
	Do findings.%Push({"code":"ORDER_FOUND", "severity":"info", "detail":"Validated before delivery"})
	Set case = ##class(CareBridge.Engine.Intake).OpenCase(record, "DOWNSTREAM_UNAVAILABLE", findings, {"deliveryAttempts":(record.DeliveryAttempts), "lastError":($EXTRACT(err, 1, 300))}, .sc)
	Quit:$$$ISERR(sc) sc
	Quit ..InvestigateAndExecute(case, record)
}

Method InvestigateAndExecute(case As CareBridge.Data.ExceptionCase, record As CareBridge.Data.MessageRecord) As %Status
{
	Do ..SetStatus(record.CorrelationId, "INVESTIGATING")
	Set input = ##class(CareBridge.Engine.ContextBuilder).Build(case, record)
	Set req = ##class(CareBridge.Msg.InvestigationRequest).%New()
	Set req.CorrelationId = record.CorrelationId
	Set req.CaseId = case.%Id()
	Set req.ExceptionType = case.ExceptionType
	Set req.InputPayload = input.%ToJSON()
	Set req.Scenario = record.Scenario
	Do ##class(CareBridge.Data.AuditEvent).Log(record.CorrelationId, "AGENT_INVOKED", ..InvestigatorTarget, "Case "_case.%Id()_" "_case.ExceptionType)
	Set sc = ..SendRequestSync(..InvestigatorTarget, req, .resp, ..InvestigatorTimeout)
	Set rec = "", outcome = "PROVIDER_ERROR", runId = ""
	If $$$ISERR(sc) {
		Set outcome = $SELECT($SYSTEM.Status.GetErrorText(sc) [ "Timed out":"TIMEOUT", 1:"PROVIDER_ERROR")
		Do ##class(CareBridge.Data.AuditEvent).Log(record.CorrelationId, "AGENT_FAILED", ..InvestigatorTarget, $SYSTEM.Status.GetErrorText(sc))
	} ElseIf '$ISOBJECT($GET(resp)) {
		// SendRequestSync returns OK with no response when the timeout expires.
		Set outcome = "TIMEOUT"
		Do ##class(CareBridge.Data.AuditEvent).Log(record.CorrelationId, "AGENT_FAILED", ..InvestigatorTarget, "No response within "_..InvestigatorTimeout_"s")
	} Else {
		Set outcome = resp.Outcome, runId = resp.AgentRunId
		If (outcome = "OK") && (resp.Recommendation '= "") Set rec = {}.%FromJSON(resp.Recommendation)
		Do ##class(CareBridge.Data.AuditEvent).Log(record.CorrelationId, "AGENT_RESPONDED", ..InvestigatorTarget, resp.Mode_" run "_runId_": "_outcome_$SELECT(resp.RecommendedAction'="":", recommends "_resp.RecommendedAction, 1:""))
	}
	Set verdict = ##class(CareBridge.Engine.PolicyGate).EvaluateAgent(rec, outcome, case, record, runId)
	Quit ..Execute(verdict.finalAction, case, record, $SELECT(verdict.approved:"AGENT_POLICY", 1:"POLICY_FALLBACK"), verdict.summary)
}

/// Carry out an approved (or fallback) action through the production.
Method Execute(action As %String, case As CareBridge.Data.ExceptionCase, record As CareBridge.Data.MessageRecord, decidedBy As %String, reason As %String = "") As %Status
{
	Set sc = $$$OK
	Do ##class(CareBridge.Data.AuditEvent).Log(record.CorrelationId, "ACTION_EXECUTING", ..%ConfigName, action_" (decided by "_decidedBy_")")
	If action = "ACCEPT" {
		Do ..ResolveCase(case, "ACCEPT", decidedBy)
		Quit ..Deliver(record, decidedBy)
	}
	If action = "RETRY" {
		Set item = ##class(CareBridge.Data.QueueItem).%New()
		Set item.Queue = "RETRY", item.CorrelationId = record.CorrelationId, item.ExceptionCase = case
		Set item.Reason = reason
		Set item.DueAt = $ZDATETIME($SYSTEM.SQL.Functions.DATEADD("s", ..RetryDelaySeconds, $ZDATETIME($ZTIMESTAMP, 3)), 3)
		Set sc = item.%Save()
		Do ..ResolveCase(case, "RETRY", decidedBy)
		Do ..SetStatus(record.CorrelationId, "RETRY_PENDING")
		Do ##class(CareBridge.Data.AuditEvent).Log(record.CorrelationId, "RETRY_SCHEDULED", ..%ConfigName, "Re-delivery due at "_item.DueAt_" UTC")
		Quit sc
	}
	If (action = "QUARANTINE") || (action = "REJECT") {
		Set req = ##class(CareBridge.Msg.QueueRequest).%New()
		Set req.CorrelationId = record.CorrelationId, req.CaseId = case.%Id(), req.Reason = reason
		Set target = $SELECT(action = "QUARANTINE":..QuarantineTarget, 1:..RejectTarget)
		Set sc = ..SendRequestSync(target, req, .resp, 30)
		Quit:$$$ISERR(sc) sc
		Do ..ResolveCase(case, action, decidedBy)
		Quit ..Finish(record, $SELECT(action = "QUARANTINE":"QUARANTINED", 1:"REJECTED"), action, decidedBy)
	}
	If action = "DUPLICATE_SUPPRESSED" {
		Do ..ResolveCase(case, action, decidedBy)
		Do ##class(CareBridge.Data.AuditEvent).Log(record.CorrelationId, "DUPLICATE_SUPPRESSED", ..%ConfigName, "Not forwarded; the receiver already holds this result")
		Quit ..Finish(record, "DUPLICATE_SUPPRESSED", action, decidedBy)
	}
	If action = "MANUAL_REVIEW" {
		Quit ..RequestReview(case, record, reason)
	}
	Quit $$$ERROR($$$GeneralError, "No executor for action '"_action_"'")
}

/// Hand the case to people through the Workflow Engine. The decision returns in OnResponse.
Method RequestReview(case As CareBridge.Data.ExceptionCase, record As CareBridge.Data.MessageRecord, reason As %String) As %Status
{
	Set case.Status = "AWAITING_REVIEW"
	Do case.%Save()
	Do ..SetStatus(record.CorrelationId, "MANUAL_REVIEW")
	Set permitted = ##class(CareBridge.Engine.PolicyGate).Permitted(##class(CareBridge.Engine.PolicyGate).#HUMANMATRIX, case.ExceptionType)
	Set task = ##class(EnsLib.Workflow.TaskRequest).%New()
	Set task.%Actions = $LISTTOSTRING(permitted, ",")
	Set task.%Subject = "["_record.CorrelationId_"] "_case.ExceptionType_" - "_record.PatientRef_" / "_record.OrderRef
	Set task.%Message = "Case "_case.%Id()_". "_reason
	Set task.%FormFields = "Note"
	Set task.%Priority = $SELECT(case.ExceptionType = "PATIENT_ORDER_CONFLICT":1, 1:3)
	Set sc = ..SendRequestAsync(..ReviewTarget, task, 1, "review:"_case.%Id())
	Quit:$$$ISERR(sc) sc
	Set item = ##class(CareBridge.Data.QueueItem).%New()
	Set item.Queue = "REVIEW", item.CorrelationId = record.CorrelationId, item.ExceptionCase = case, item.Reason = reason
	Do item.%Save()
	Do ##class(CareBridge.Data.AuditEvent).Log(record.CorrelationId, "REVIEW_REQUESTED", ..ReviewTarget, "Workflow task created; reviewer may choose "_task.%Actions)
	Quit $$$OK
}

/// A reviewer completed a workflow task. Their choice goes through the policy gate before anything happens.
Method OnResponse(request As %Library.Persistent, ByRef response As %Library.Persistent, callrequest As %Library.Persistent, callresponse As %Library.Persistent, pCompletionKey As %String) As %Status
{
	Quit:$PIECE(pCompletionKey, ":", 1)'="review" $$$OK
	Set sc = $$$OK
	Try {
		Set case = ##class(CareBridge.Data.ExceptionCase).%OpenId($PIECE(pCompletionKey, ":", 2))
		Set record = case.Message
		Set ..CorrelationId = record.CorrelationId
		If '$ISOBJECT(callresponse) {
			Do ##class(CareBridge.Data.AuditEvent).Log(record.CorrelationId, "REVIEW_TASK_ENDED", ..ReviewTarget, "Task ended without a response")
			Quit
		}
		Set action = callresponse.%Action
		Set reviewer = callresponse.%UserName
		Set note = ""
		If $ISOBJECT(callresponse.%FormValues) Set note = callresponse.%FormValues.GetAt("Note")
		Do ##class(CareBridge.Data.AuditEvent).Log(record.CorrelationId, "REVIEW_DECISION", reviewer, action_": "_note)
		Set verdict = ##class(CareBridge.Engine.PolicyGate).EvaluateHuman(action, note, reviewer, case, record)
		If verdict.approved {
			Set case.ResolvedBy = reviewer, case.ReviewNote = note
			Do case.%Save()
			Do ..CloseReviewItems(record.CorrelationId)
			Set sc = ..Execute(verdict.finalAction, case, record, "HUMAN", "Reviewer "_reviewer_": "_note)
		} Else {
			// Decision refused: issue a fresh task so the case is never left without an owner.
			Set sc = ..RequestReview(case, record, "Previous decision refused by policy: "_verdict.summary)
		}
	} Catch ex {
		Set sc = ex.AsStatus()
	}
	Quit sc
}

Method CloseReviewItems(correlationId As %String)
{
	&sql(UPDATE CareBridge_Data.QueueItem SET Status = 'DONE', ClosedAt = CURRENT_TIMESTAMP WHERE CorrelationId = :correlationId AND Queue = 'REVIEW' AND Status = 'OPEN')
}

Method ResolveCase(case As CareBridge.Data.ExceptionCase, resolution As %String, decidedBy As %String)
{
	Set case.Status = "RESOLVED", case.Resolution = resolution, case.ResolvedAt = $ZDATETIME($ZTIMESTAMP, 3)
	If case.ResolvedBy = "" Set case.ResolvedBy = decidedBy
	Do case.%Save()
}

Method Finish(record As CareBridge.Data.MessageRecord, status As %String, outcome As %String, decidedBy As %String) As %Status
{
	Set record.Status = status, record.FinalOutcome = outcome, record.DecidedBy = decidedBy
	Set record.CompletedAt = $ZDATETIME($ZTIMESTAMP, 3)
	Set sc = record.%Save()
	Do ##class(CareBridge.Data.AuditEvent).Log(record.CorrelationId, "COMPLETED", ..%ConfigName, outcome_" ("_decidedBy_")")
	Quit sc
}

ClassMethod SetStatus(correlationId As %String, status As %String)
{
	&sql(UPDATE CareBridge_Data.MessageRecord SET Status = :status WHERE CorrelationId = :correlationId)
}

}
