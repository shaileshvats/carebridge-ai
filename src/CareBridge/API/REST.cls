/// REST API behind the CareBridge dashboard (/api/carebridge). Every number it returns is read from
/// persisted IRIS data; every action it takes goes through the production or the policy gate.
Class CareBridge.API.REST Extends %CSP.REST
{

Parameter CONTENTTYPE = "application/json";

Parameter CHARSET = "utf-8";

Parameter HandleCorsRequest = 0;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <Route Url="/health" Method="GET" Call="Health"/>
  <Route Url="/overview" Method="GET" Call="Overview"/>
  <Route Url="/messages" Method="GET" Call="Messages"/>
  <Route Url="/messages/:corr" Method="GET" Call="MessageDetail"/>
  <Route Url="/review" Method="GET" Call="ReviewQueue"/>
  <Route Url="/review/:caseId" Method="POST" Call="ReviewDecide"/>
  <Route Url="/agent-runs" Method="GET" Call="AgentRuns"/>
  <Route Url="/queues" Method="GET" Call="Queues"/>
  <Route Url="/scenarios" Method="GET" Call="Scenarios"/>
  <Route Url="/scenarios/:name/run" Method="POST" Call="RunScenario"/>
  <Route Url="/scenarios/:name/followup" Method="POST" Call="FollowUp"/>
  <Route Url="/jobs/:id" Method="GET" Call="Job"/>
  <Route Url="/mode" Method="GET" Call="GetMode"/>
  <Route Url="/mode" Method="POST" Call="SetMode"/>
  <Route Url="/reset" Method="POST" Call="Reset"/>
</Routes>
}

ClassMethod Reply(obj As %DynamicAbstractObject) As %Status
{
	Write obj.%ToJSON()
	Quit $$$OK
}

ClassMethod Fail(httpStatus As %String, message As %String) As %Status
{
	Set %response.Status = httpStatus
	Quit ..Reply({"error":(message)})
}

/// Dynamic SQL that fails loudly: a query error becomes an HTTP 500 instead of an empty list.
ClassMethod Q(sql As %String, args...) As %SQL.StatementResult
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, sql, args...)
	If rs.%SQLCODE < 0 $$$ThrowStatus($$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message))
	Quit rs
}

ClassMethod Body() As %DynamicObject
{
	Try {
		If $ISOBJECT(%request.Content) && (%request.Content.Size > 0) Return {}.%FromJSON(%request.Content)
	} Catch {}
	Quit {}
}

ClassMethod Health() As %Status
{
	Quit ..Reply({
		"status":"ok",
		"namespace":($NAMESPACE),
		"irisVersion":($ZVERSION),
		"productionRunning":(##class(Ens.Director).IsProductionRunning()),
		"aiHubAvailable":(##class(CareBridge.Operation.ExceptionInvestigator).LiveAvailable())
	})
}

ClassMethod Overview() As %Status
{
	Set out = {}
	&sql(SELECT COUNT(*) INTO :n FROM CareBridge_Data.MessageRecord)
	Set out.received = +n
	For pair = "accepted:ACCEPTED", "quarantined:QUARANTINED", "manualReview:MANUAL_REVIEW", "duplicates:DUPLICATE_SUPPRESSED", "rejected:REJECTED", "retryPending:RETRY_PENDING", "inFlight:INVESTIGATING", "failed:FAILED" {
		Set status = $PIECE(pair, ":", 2)
		&sql(SELECT COUNT(*) INTO :n FROM CareBridge_Data.MessageRecord WHERE Status = :status)
		Do out.%Set($PIECE(pair, ":", 1), +n)
	}
	&sql(SELECT COUNT(DISTINCT CorrelationId) INTO :n FROM CareBridge_Data.ExceptionCase)
	Set out.withExceptions = +n
	&sql(SELECT COUNT(*) INTO :n FROM CareBridge_Data.QueueItem WHERE Queue = 'RETRY')
	Set out.retriesScheduled = +n
	&sql(SELECT COUNT(*) INTO :n FROM CareBridge_Data.MessageRecord WHERE DeliveryAttempts > 1)
	Set out.messagesRetried = +n
	&sql(SELECT COUNT(*), SUM(CASE WHEN Outcome = 'OK' THEN 1 ELSE 0 END) INTO :n, :ok FROM CareBridge_Data.AgentRun)
	Set out.agentRuns = +n, out.agentRunsValid = +ok
	&sql(SELECT COUNT(*), SUM(CASE WHEN Approved = 1 THEN 1 ELSE 0 END) INTO :n, :ok FROM CareBridge_Data.PolicyEvaluation WHERE Source = 'AGENT')
	Set out.agentRecommendationsEvaluated = +n, out.agentRecommendationsApproved = +ok
	&sql(SELECT COUNT(*) INTO :n FROM CareBridge_Data.DeliveredResult)
	Set out.deliveredToEMR = +n
	Set out.mode = ##class(CareBridge.Operation.ExceptionInvestigator).ActiveMode()
	Set out.byException = []
	Set rs = ..Q("SELECT ExceptionType, COUNT(*) AS N FROM CareBridge_Data.ExceptionCase GROUP BY ExceptionType ORDER BY N DESC")
	While rs.%Next() { Do out.byException.%Push({"type":(rs.ExceptionType), "count":(rs.N)}) }
	Quit ..Reply(out)
}

ClassMethod Messages() As %Status
{
	Set sql = "SELECT TOP ? CorrelationId, ControlId, MessageType, PatientRef, OrderRef, ResultStatus, Status, FinalOutcome, DecidedBy, DeliveryAttempts, Scenario, ReceivedAt, CompletedAt FROM CareBridge_Data.MessageRecord WHERE 1=1"
	Set args = 1, args(1) = $SELECT(+$GET(%request.Data("limit", 1)) > 0:+%request.Data("limit", 1), 1:200)
	Set q = $GET(%request.Data("q", 1))
	If q '= "" {
		Set sql = sql_" AND (CorrelationId %STARTSWITH ? OR ControlId %STARTSWITH ? OR PatientRef %STARTSWITH ? OR OrderRef %STARTSWITH ?)"
		For i = 1:1:4 { Set args = args + 1, args(args) = q }
	}
	For f = "status:Status", "type:MessageType", "patient:PatientRef", "order:OrderRef", "outcome:FinalOutcome" {
		Set v = $GET(%request.Data($PIECE(f, ":", 1), 1))
		If v '= "" Set sql = sql_" AND "_$PIECE(f, ":", 2)_" = ?", args = args + 1, args(args) = v
	}
	Set from = $GET(%request.Data("from", 1)), to = $GET(%request.Data("to", 1))
	If from '= "" Set sql = sql_" AND ReceivedAt >= ?", args = args + 1, args(args) = from
	If to '= "" Set sql = sql_" AND ReceivedAt <= ?", args = args + 1, args(args) = to_$SELECT($LENGTH(to)=10:" 23:59:59", 1:"")
	Set sql = sql_" ORDER BY ID DESC"
	Set rs = ..Q(sql, args...)
	Set out = []
	While rs.%Next() {
		Do out.%Push({"correlationId":(rs.CorrelationId), "controlId":(rs.ControlId), "messageType":(rs.MessageType), "patientRef":(rs.PatientRef), "orderRef":(rs.OrderRef), "resultStatus":(rs.ResultStatus), "status":(rs.Status), "finalOutcome":(rs.FinalOutcome), "decidedBy":(rs.DecidedBy), "deliveryAttempts":(rs.DeliveryAttempts), "scenario":(rs.Scenario), "receivedAt":(rs.ReceivedAt), "completedAt":(rs.CompletedAt)})
	}
	Quit ..Reply(out)
}

/// Everything about one message, receipt to final action.
ClassMethod MessageDetail(corr As %String) As %Status
{
	Set r = ##class(CareBridge.Data.MessageRecord).OpenByCorrelation(corr)
	If '$ISOBJECT(r) Quit ..Fail("404", "Unknown correlation id")
	Set raw = r.RawText()
	Set out = {"correlationId":(r.CorrelationId), "controlId":(r.ControlId), "messageType":(r.MessageType), "sendingApplication":(r.SendingApplication), "sendingFacility":(r.SendingFacility),
		"patientRef":(r.PatientRef), "orderRef":(r.OrderRef), "resultStatus":(r.ResultStatus), "status":(r.Status), "finalOutcome":(r.FinalOutcome), "decidedBy":(r.DecidedBy),
		"deliveryAttempts":(r.DeliveryAttempts), "scenario":(r.Scenario), "receivedAt":(r.ReceivedAt), "completedAt":(r.CompletedAt), "sessionId":(r.SessionId),
		"contentHash":(r.ContentHash), "raw":(raw), "parsed":(##class(CareBridge.Engine.HL7Parser).Parse(raw))}
	Set out.cases = []
	Set rs = ..Q("SELECT ID FROM CareBridge_Data.ExceptionCase WHERE CorrelationId = ? ORDER BY ID", corr)
	While rs.%Next() {
		Set c = ##class(CareBridge.Data.ExceptionCase).%OpenId(rs.ID)
		Set co = {"caseId":(c.%Id()), "exceptionType":(c.ExceptionType), "status":(c.Status), "resolution":(c.Resolution), "resolvedBy":(c.ResolvedBy), "reviewNote":(c.ReviewNote), "createdAt":(c.CreatedAt), "resolvedAt":(c.ResolvedAt),
			"findings":([].%FromJSON(c.Findings)), "context":($SELECT(c.Context'="":{}.%FromJSON(c.Context), 1:{})), "agentRuns":[], "policy":[]}
		Set rs2 = ..Q("SELECT ID FROM CareBridge_Data.AgentRun WHERE ExceptionCase = ? ORDER BY ID", c.%Id())
		While rs2.%Next() { Do co.agentRuns.%Push(..RunJSON(rs2.ID)) }
		Set rs3 = ..Q("SELECT ID, Source, RecommendedAction, Approved, FinalAction, Rules, Summary, EvaluatedAt FROM CareBridge_Data.PolicyEvaluation WHERE ExceptionCase = ? ORDER BY ID", c.%Id())
		While rs3.%Next() {
			Set pe = {"id":(rs3.ID), "source":(rs3.Source), "recommendedAction":(rs3.RecommendedAction), "finalAction":(rs3.FinalAction), "summary":(rs3.Summary), "evaluatedAt":(rs3.EvaluatedAt), "rules":([].%FromJSON(rs3.Rules))}
			Do pe.%Set("approved", rs3.Approved, "boolean")
			Do co.policy.%Push(pe)
		}
		Do out.cases.%Push(co)
	}
	Set out.timeline = []
	Set rs = ..Q("SELECT EventType, Actor, Detail, ""At"" FROM CareBridge_Data.AuditEvent WHERE CorrelationId = ? ORDER BY ID", corr)
	While rs.%Next() { Do out.timeline.%Push({"event":(rs.EventType), "actor":(rs.Actor), "detail":(rs.Detail), "at":(rs.At)}) }
	Set out.queueItems = []
	Set rs = ..Q("SELECT ID, Queue, Status, Reason, DueAt, CreatedAt, ClosedAt FROM CareBridge_Data.QueueItem WHERE CorrelationId = ? ORDER BY ID", corr)
	While rs.%Next() { Do out.queueItems.%Push({"id":(rs.ID), "queue":(rs.Queue), "status":(rs.Status), "reason":(rs.Reason), "dueAt":(rs.DueAt), "createdAt":(rs.CreatedAt), "closedAt":(rs.ClosedAt)}) }
	Set d = ##class(CareBridge.Data.DeliveredResult).CorrelationIdxOpen(corr)
	Set out.delivery = $SELECT($ISOBJECT(d):{"receiverRef":(d.%Id()), "deliveredAt":(d.DeliveredAt)}, 1:"")
	Quit ..Reply(out)
}

ClassMethod RunJSON(id As %String) As %DynamicObject
{
	Set a = ##class(CareBridge.Data.AgentRun).%OpenId(id)
	Set o = {"runId":(a.%Id()), "correlationId":(a.CorrelationId), "caseId":(a.ExceptionCaseGetObjectId()), "agent":(a.AgentName), "mode":(a.Mode), "provider":(a.Provider), "model":(a.Model),
		"startedAt":(a.StartedAt), "endedAt":(a.EndedAt), "durationMs":(a.DurationMs), "promptTokens":(a.PromptTokens), "completionTokens":(a.CompletionTokens), "attempts":(a.Attempts),
		"outcome":(a.Outcome), "recommendedAction":(a.RecommendedAction), "error":(a.Error), "rawOutput":(a.RawOutput),
		"input":($SELECT(a.InputPayload'="":{}.%FromJSON(a.InputPayload), 1:"")), "recommendation":($SELECT(a.Recommendation'="":{}.%FromJSON(a.Recommendation), 1:"")), "toolCalls":[]}
	Set rs = ..Q("SELECT Seq, ToolName, Arguments, ResultSummary, DurationMs, Success, Error, ""Authorization"" AS Auth, CalledAt FROM CareBridge_Data.ToolCall WHERE AgentRun = ? ORDER BY Seq", id)
	While rs.%Next() {
		Set t = {"seq":(rs.Seq), "tool":(rs.ToolName), "arguments":(rs.Arguments), "result":(rs.ResultSummary), "durationMs":(rs.DurationMs), "error":(rs.Error), "authorization":(rs.Auth), "calledAt":(rs.CalledAt)}
		Do t.%Set("success", rs.Success, "boolean")
		Do o.toolCalls.%Push(t)
	}
	Set pe = ""
	&sql(SELECT ID INTO :pe FROM CareBridge_Data.PolicyEvaluation WHERE AgentRun = :id)
	If (SQLCODE = 0) && (pe '= "") {
		Set p = ##class(CareBridge.Data.PolicyEvaluation).%OpenId(pe)
		Set o.policy = {"finalAction":(p.FinalAction), "summary":(p.Summary)}
		Do o.policy.%Set("approved", p.Approved, "boolean")
	}
	Quit o
}

ClassMethod AgentRuns() As %Status
{
	Set limit = $SELECT(+$GET(%request.Data("limit", 1)) > 0:+%request.Data("limit", 1), 1:100)
	Set out = []
	Set rs = ..Q("SELECT TOP ? ID FROM CareBridge_Data.AgentRun ORDER BY ID DESC", limit)
	While rs.%Next() {
		Set o = ..RunJSON(rs.ID)
		Do o.%Remove("input"), o.%Remove("rawOutput")
		Do out.%Push(o)
	}
	Quit ..Reply(out)
}

ClassMethod ReviewQueue() As %Status
{
	Quit ..Reply(##class(CareBridge.Engine.Review).OpenTasks())
}

ClassMethod ReviewDecide(caseId As %String) As %Status
{
	Set b = ..Body()
	Set res = ##class(CareBridge.Engine.Review).Decide(caseId, b.action, b.note, b.reviewer)
	If res.%IsDefined("error") Quit ..Fail("409", res.error)
	Quit ..Reply(res)
}

ClassMethod Queues() As %Status
{
	Set out = []
	Set rs = ..Q("SELECT TOP 200 ID, Queue, CorrelationId, ExceptionCase, Status, Reason, DueAt, CreatedAt, ClosedAt FROM CareBridge_Data.QueueItem ORDER BY ID DESC")
	While rs.%Next() { Do out.%Push({"id":(rs.ID), "queue":(rs.Queue), "correlationId":(rs.CorrelationId), "caseId":(rs.ExceptionCase), "status":(rs.Status), "reason":(rs.Reason), "dueAt":(rs.DueAt), "createdAt":(rs.CreatedAt), "closedAt":(rs.ClosedAt)}) }
	Quit ..Reply(out)
}

ClassMethod Scenarios() As %Status
{
	Set defs = ##class(CareBridge.Demo.Scenarios).Definitions()
	Set out = []
	Set iter = defs.order.%GetIterator()
	While iter.%GetNext(.i, .name) {
		Set s = defs.scenarios.%Get(name)
		Set o = {"name":(name), "title":(s.title), "group":(s.group), "description":(s.description), "expect":(s.expect), "followUp":($SELECT($ISOBJECT(s.followUp):s.followUp.title, 1:""))}
		Do out.%Push(o)
	}
	Quit ..Reply(out)
}

ClassMethod RunScenario(name As %String) As %Status
{
	If (name '= "all") && ($EXTRACT(name, 1, 6) '= "group:") && '$ISOBJECT(##class(CareBridge.Demo.Scenarios).Definitions().scenarios.%Get(name)) Quit ..Fail("404", "Unknown scenario")
	Set jobId = $INCREMENT(^CareBridge.DemoJobSeq)
	Set ^CareBridge.DemoJob(jobId, "status") = "QUEUED"
	Job ##class(CareBridge.Demo.Runner).RunJob(jobId, name)
	Quit ..Reply({"jobId":(jobId), "status":"QUEUED"})
}

ClassMethod FollowUp(name As %String) As %Status
{
	Set r = ##class(CareBridge.Demo.Runner).RunFollowUp(name)
	If r.%IsDefined("error") Quit ..Fail("404", r.error)
	Quit ..Reply(r)
}

ClassMethod Job(id As %String) As %Status
{
	Set status = $GET(^CareBridge.DemoJob(id, "status"))
	If status = "" Quit ..Fail("404", "Unknown job")
	Set result = $GET(^CareBridge.DemoJob(id, "result"))
	Quit ..Reply({"jobId":(id), "status":(status), "result":($SELECT(result'="":{}.%FromJSON(result), 1:""))})
}

ClassMethod GetMode() As %Status
{
	Set cfg = {"mode":(##class(CareBridge.Operation.ExceptionInvestigator).ActiveMode()), "liveAvailable":(##class(CareBridge.Operation.ExceptionInvestigator).LiveAvailable())}
	If cfg.liveAvailable {
		Set p = $CLASSMETHOD("CareBridge.ExceptionInvestigator", "ProviderSettings")
		// Provider, model and endpoint only. The key is never returned.
		Set cfg.provider = p.provider, cfg.model = p.model, cfg.baseUrl = p.baseUrl
		Do cfg.%Set("keyConfigured", p.hasKey, "boolean")
	}
	Set cfg.modeLocked = ($SYSTEM.Util.GetEnviron("CAREBRIDGE_LOCK_MODE") '= "")
	Quit ..Reply(cfg)
}

ClassMethod SetMode() As %Status
{
	If $SYSTEM.Util.GetEnviron("CAREBRIDGE_LOCK_MODE") '= "" Quit ..Fail("403", "Mode switching is disabled on this deployment")
	Set m = $ZCONVERT(..Body().mode, "U")
	If (m '= "LIVE") && (m '= "REPLAY") Quit ..Fail("400", "mode must be LIVE or REPLAY")
	Set ^CareBridge.Config("AgentMode") = m
	Quit ..GetMode()
}

ClassMethod Reset() As %Status
{
	Set sc = ##class(CareBridge.Setup.Installer).Reset()
	If $$$ISERR(sc) Quit ..Fail("500", $SYSTEM.Status.GetErrorText(sc))
	Quit ..Reply({"reset":true})
}

}
