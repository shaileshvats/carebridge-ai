/// Plays the simulated HIS and LIS: sends scenario messages over MLLP to the running production
/// and waits for each result to reach a terminal state. Nothing here bypasses the production.
Class CareBridge.Demo.Runner Extends %RegisteredObject
{

Parameter HISPORT = 7010;

Parameter LISPORT = 7011;

/// Statuses after which a message needs nothing more from the production.
Parameter TERMINAL = "ACCEPTED,QUARANTINED,MANUAL_REVIEW,DUPLICATE_SUPPRESSED,REJECTED,FAILED";

/// Run one scenario synchronously. Returns {scenario, expect, messages:[{controlId, correlationId, status, outcome}], passed}.
ClassMethod RunScenario(name As %String, timeoutSeconds As %Integer = 0) As %DynamicObject
{
	Set defs = ##class(CareBridge.Demo.Scenarios).Definitions()
	Set sc = defs.scenarios.%Get(name)
	If '$ISOBJECT(sc) Quit {"scenario":(name), "error":"Unknown scenario"}
	Set runNo = $INCREMENT(^CareBridge.DemoRunNo)
	// A small per-run variation keeps repeated runs from colliding as duplicates of earlier runs.
	Set v = 80 + (runNo # 15)
	Set out = {"scenario":(name), "title":(sc.title), "expect":(sc.expect), "messages":[], "startedAt":($ZDATETIME($ZTIMESTAMP, 3))}
	Set wait = $SELECT(timeoutSeconds > 0:timeoutSeconds, sc.%IsDefined("waitSeconds"):sc.waitSeconds, 1:45)
	Set iter = sc.steps.%GetIterator()
	While iter.%GetNext(.i, .step) {
		If step.%IsDefined("receiverFailNext") {
			Do ##class(CareBridge.Data.ReceiverControl).SetFailNext(step.receiverFailNext)
			Continue
		}
		Set res = ..SendStep(step, name, v)
		If res.%IsDefined("error") Set out.error = res.error Quit
		If step.send = "LIS" {
			Set res.final = ..WaitForTerminal(res.controlId, wait)
		}
		Do out.messages.%Push(res)
	}
	Set last = out.messages.%Get(out.messages.%Size() - 1)
	Set outcome = $SELECT($ISOBJECT(last)&&$ISOBJECT(last.final):last.final.outcome, 1:"")
	Set out.outcome = outcome
	Do out.%Set("passed", (outcome = sc.expect), "boolean")
	Set out.finishedAt = $ZDATETIME($ZTIMESTAMP, 3)
	Quit out
}

/// Send the scenario's follow-up steps (e.g. the late HIS registration in unknown-patient).
ClassMethod RunFollowUp(name As %String) As %DynamicObject
{
	Set sc = ##class(CareBridge.Demo.Scenarios).Definitions().scenarios.%Get(name)
	If '$ISOBJECT(sc) || '$ISOBJECT(sc.followUp) Quit {"error":"No follow-up for this scenario"}
	Set out = {"scenario":(name), "title":(sc.followUp.title), "messages":[]}
	Set iter = sc.followUp.steps.%GetIterator()
	While iter.%GetNext(.i, .step) {
		Do out.messages.%Push(..SendStep(step, name, 0))
	}
	// Give the HIS registry a moment to apply the update.
	Hang 1
	Quit out
}

ClassMethod SendStep(step As %DynamicObject, scenario As %String, v As %String) As %DynamicObject
{
	Set defs = ##class(CareBridge.Demo.Scenarios).Definitions()
	Set ctl = $SELECT(step.send = "HIS":"HIS", 1:"LAB")_$ZDATE($HOROLOG, 8)_$TRANSLATE($JUSTIFY($INCREMENT(^CareBridge.DemoCtl), 5), " ", "0")
	Set ts = $TRANSLATE($ZDATETIME($HOROLOG, 8), " :")
	Set text = ##class(CareBridge.Demo.Scenarios).Render(defs.templates.%Get(step.template), step.vars, ctl, ts, v)
	// Label the message for the replay adapter and the dashboard. This lives outside the HL7 itself.
	Set ^CareBridge.DemoScenario(ctl) = scenario
	Set port = $SELECT(step.send = "HIS":..#HISPORT, 1:..#LISPORT)
	Set sc = ..SendMLLP(text, port, .ack)
	If $$$ISERR(sc) Quit {"controlId":(ctl), "system":(step.send), "error":($SYSTEM.Status.GetErrorText(sc))}
	Quit {"controlId":(ctl), "system":(step.send), "ack":($PIECE($PIECE(ack, $CHAR(13), 2), "|", 2))}
}

/// Minimal MLLP client: <VT>message<FS><CR>, then read the ACK.
ClassMethod SendMLLP(text As %String, port As %Integer, Output ack As %String, host As %String = "127.0.0.1") As %Status
{
	Set ack = "", dev = "|TCP|"_port
	Try {
		Open dev:(host:port:"S"):10
		If '$TEST Return $$$ERROR($$$GeneralError, "Cannot connect to "_host_":"_port)
		Use dev
		Write $CHAR(11)_text_$CHAR(28,13),*-3
		Set deadline = $ZHOROLOG + 15
		For {
			Read chunk#4096:2
			Set ack = ack_chunk
			Quit:(ack [ $CHAR(28))||($ZHOROLOG > deadline)
		}
		Close dev
	} Catch ex {
		Close dev
		Return ex.AsStatus()
	}
	Set ack = $TRANSLATE(ack, $CHAR(11,28))
	Quit $SELECT(ack [ "MSA|":$$$OK, 1:$$$ERROR($$$GeneralError, "No HL7 ACK received from port "_port))
}

/// Poll until the message with this control id reaches a terminal state (or timeout).
ClassMethod WaitForTerminal(controlId As %String, timeoutSeconds As %Integer = 45) As %DynamicObject
{
	Set deadline = $ZHOROLOG + timeoutSeconds
	Set result = {"status":"NOT_RECEIVED", "outcome":""}
	For {
		Set id = "", corr = "", status = "", outcome = ""
		&sql(SELECT TOP 1 ID, CorrelationId, Status, FinalOutcome INTO :id, :corr, :status, :outcome FROM CareBridge_Data.MessageRecord WHERE ControlId = :controlId ORDER BY ID DESC)
		If SQLCODE = 0 {
			// MANUAL_REVIEW is terminal for the runner: the next step belongs to a person.
			Set result = {"correlationId":(corr), "status":(status), "outcome":($SELECT(status="MANUAL_REVIEW":"MANUAL_REVIEW", 1:outcome))}
			Quit:$LISTFIND($LISTFROMSTRING(..#TERMINAL), status)
		}
		Quit:$ZHOROLOG>deadline
		Hang 0.5
	}
	Quit result
}

/// Run every scenario (or one group) in order; returns a summary report.
ClassMethod RunAll(group As %String = "") As %DynamicObject
{
	Set defs = ##class(CareBridge.Demo.Scenarios).Definitions()
	Set report = {"startedAt":($ZDATETIME($ZTIMESTAMP, 3)), "mode":(##class(CareBridge.Operation.ExceptionInvestigator).ActiveMode()), "results":[], "passed":0, "failed":0}
	Set iter = defs.order.%GetIterator()
	While iter.%GetNext(.i, .name) {
		Continue:(group'="")&&(defs.scenarios.%Get(name).group'=group)
		Set r = ..RunScenario(name)
		Do report.results.%Push(r)
		If r.passed { Set report.passed = report.passed + 1 } Else { Set report.failed = report.failed + 1 }
	}
	Set report.finishedAt = $ZDATETIME($ZTIMESTAMP, 3)
	Quit report
}

/// Background entry point used by the dashboard: runs and stores the report under ^CareBridge.DemoJob(jobId).
ClassMethod RunJob(jobId As %String, what As %String)
{
	Set ^CareBridge.DemoJob(jobId, "status") = "RUNNING"
	Try {
		If what = "all" { Set r = ..RunAll() } ElseIf $EXTRACT(what, 1, 6) = "group:" { Set r = ..RunAll($EXTRACT(what, 7, *)) } Else { Set r = ..RunScenario(what) }
		Set ^CareBridge.DemoJob(jobId, "result") = r.%ToJSON()
		Set ^CareBridge.DemoJob(jobId, "status") = "DONE"
	} Catch ex {
		Set ^CareBridge.DemoJob(jobId, "result") = {"error":(ex.DisplayString())}.%ToJSON()
		Set ^CareBridge.DemoJob(jobId, "status") = "ERROR"
	}
}

/// Terminal-friendly: Do ##class(CareBridge.Demo.Runner).Demo()
ClassMethod Demo(group As %String = "")
{
	Set r = ..RunAll(group)
	Set iter = r.results.%GetIterator()
	While iter.%GetNext(.i, .s) {
		Write $SELECT(s.passed:"PASS ", 1:"FAIL "), $JUSTIFY(s.scenario, -24), " expected ", $JUSTIFY(s.expect, -20), " got ", s.outcome, !
	}
	Write !, r.passed, " passed, ", r.failed, " failed (agent mode ", r.mode, ")", !
}

}
