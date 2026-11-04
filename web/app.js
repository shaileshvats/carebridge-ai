// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Shailesh Vats
/* CareBridge AI dashboard. Plain JavaScript; every value shown comes from /api/carebridge. */
(function () {
  "use strict";
  const API = "/api/carebridge";
  const view = document.getElementById("view");
  let refreshTimer = null;

  const esc = (v) => String(v ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const fmtTime = (t) => (t ? esc(String(t).replace("T", " ").slice(0, 19)) + " UTC" : "");

  async function api(path, opts) {
    const res = await fetch(API + path, Object.assign({ headers: { "Content-Type": "application/json" } }, opts || {}));
    let body = null;
    try { body = await res.json(); } catch (e) { /* non-JSON error page */ }
    if (!res.ok) throw new Error((body && body.error) || ("HTTP " + res.status));
    return body;
  }
  const post = (path, data) => api(path, { method: "POST", body: JSON.stringify(data || {}) });

  const OUTCOME_CLASS = {
    ACCEPT: "ok", ACCEPTED: "ok", DUPLICATE_SUPPRESSED: "info", RETRY: "warn", RETRY_PENDING: "warn",
    QUARANTINE: "bad", QUARANTINED: "bad", REJECT: "bad", REJECTED: "bad", FAILED: "bad",
    MANUAL_REVIEW: "warn", AWAITING_REVIEW: "warn", INVESTIGATING: "info", VALIDATING: "info", RECEIVED: "info",
    OK: "ok", INVALID_OUTPUT: "bad", TIMEOUT: "bad", PROVIDER_ERROR: "bad", NOT_AVAILABLE: "bad",
    RESOLVED: "ok", OPEN: "warn", DONE: "ok", DISPATCHED: "info"
  };
  const pill = (v) => (v ? `<span class="pill ${OUTCOME_CLASS[v] || ""}">${esc(v.replace(/_/g, " "))}</span>` : "");

  function setActive(route) {
    document.querySelectorAll(".tabs a").forEach((a) => a.classList.toggle("active", a.dataset.route === route));
  }
  function schedule(fn, ms) {
    clearTimeout(refreshTimer);
    refreshTimer = setTimeout(() => { if (document.visibilityState === "visible") fn(); else schedule(fn, ms); }, ms);
  }
  function fail(e) { view.innerHTML = `<div class="notice bad">Could not load data: ${esc(e.message)}</div>`; }

  /* ---------- header status ---------- */
  async function refreshChrome() {
    try {
      const [mode, review, health] = await Promise.all([api("/mode"), api("/review"), api("/health")]);
      const badge = document.getElementById("mode-badge");
      badge.className = "mode-badge " + (mode.mode === "LIVE" ? "live" : "replay");
      badge.textContent = mode.mode === "LIVE" ? `LIVE AI · ${mode.model || ""}` : "REPLAY mode · scripted agent output";
      badge.title = mode.mode === "LIVE"
        ? `Live AI Hub agent. Provider ${mode.provider}, model ${mode.model}${mode.baseUrl ? ", endpoint " + mode.baseUrl : ""}`
        : "The IRIS production runs for real; the agent's reply is a scripted fixture (no model call).";
      const c = document.getElementById("review-count");
      c.hidden = !review.length; c.textContent = review.length;
      document.getElementById("health").textContent =
        `${health.productionRunning ? "Production running" : "Production stopped"} · namespace ${health.namespace} · AI Hub ${health.aiHubAvailable ? "available" : "not available"}`;
    } catch (e) { /* header is best effort */ }
  }

  /* ---------- Overview ---------- */
  async function overview() {
    setActive("overview");
    try {
      const o = await api("/overview");
      const k = (label, value, sub) => `<div class="kpi"><div class="label">${esc(label)}</div><div class="value">${esc(value)}</div>${sub ? `<div class="sub">${sub}</div>` : ""}</div>`;
      const maxEx = Math.max(1, ...o.byException.map((x) => x.count));
      view.innerHTML = `
        <div class="page-head"><div><h1>Overview</h1>
          <p>Laboratory results received from the simulated LIS, and what CareBridge did with them. Counts are read from IRIS on every refresh.</p></div>
          <a href="#/scenarios"><button class="primary">Run demo scenarios</button></a></div>
        <div class="grid kpis">
          ${k("Messages received", o.received)}
          ${k("Successfully processed", o.accepted, `${o.deliveredToEMR} delivered to the EMR`)}
          ${k("With exceptions", o.withExceptions)}
          ${k("Quarantined", o.quarantined)}
          ${k("Pending manual review", o.manualReview)}
          ${k("Retries", o.retriesScheduled, `${o.retryPending} pending · ${o.messagesRetried} messages re-delivered`)}
          ${k("Duplicates suppressed", o.duplicates)}
          ${k("Rejected to LIS", o.rejected)}
        </div>
        <div class="grid two" style="margin-top:1rem">
          <div class="card"><h2>Exceptions by type</h2>
            ${o.byException.length ? `<table><tbody>${o.byException.map((x) => `<tr><td style="width:45%">${esc(x.type.replace(/_/g, " "))}</td>
              <td><div class="bar" aria-hidden="true"><span style="width:${(x.count / maxEx) * 100}%"></span></div></td><td style="width:3rem;text-align:right">${x.count}</td></tr>`).join("")}</tbody></table>`
              : `<div class="empty">No exceptions yet.</div>`}
          </div>
          <div class="card"><h2>Agent governance</h2>
            <dl class="kv">
              <dt>Agent runs</dt><dd>${o.agentRuns} (${o.agentRunsValid} returned a valid recommendation)</dd>
              <dt>Recommendations evaluated</dt><dd>${o.agentRecommendationsEvaluated}</dd>
              <dt>Approved by policy gate</dt><dd>${o.agentRecommendationsApproved}</dd>
              <dt>Rejected or fallback</dt><dd>${o.agentRecommendationsEvaluated - o.agentRecommendationsApproved}</dd>
              <dt>Agent mode</dt><dd>${pill(o.mode)}</dd>
            </dl>
            <p class="muted" style="margin:.75rem 0 0">The agent recommends; the deterministic policy gate decides. ACCEPT is never delegated to the agent.</p>
          </div>
        </div>
        <div class="card" style="margin-top:1rem"><h2>Workflow</h2>
          <div class="flow">
            <span class="step">LIS · ORU^R01 over MLLP</span><span class="arrow">→</span>
            <span class="step">LIS.ORU.In (Business Service)</span><span class="arrow">→</span>
            <span class="step">LabResultRouter: validate</span><span class="arrow">→</span>
            <span class="step">ExceptionInvestigator (AI Hub agent)</span><span class="arrow">→</span>
            <span class="step">Policy gate</span><span class="arrow">→</span>
            <span class="step">EMR · Quarantine · Retry · Workflow review · Reject ACK</span>
          </div></div>`;
      schedule(overview, 5000);
    } catch (e) { fail(e); }
  }

  /* ---------- Message explorer ---------- */
  const msgFilters = { q: "", status: "", outcome: "", from: "", to: "" };
  async function messages() {
    setActive("messages");
    const qs = new URLSearchParams(Object.entries(msgFilters).filter(([, v]) => v)).toString();
    try {
      const rows = await api("/messages" + (qs ? "?" + qs : ""));
      const statuses = ["", "ACCEPTED", "MANUAL_REVIEW", "QUARANTINED", "RETRY_PENDING", "DUPLICATE_SUPPRESSED", "REJECTED", "INVESTIGATING", "FAILED"];
      view.innerHTML = `
        <div class="page-head"><div><h1>Message explorer</h1><p>Search by correlation id, control id, patient or order reference. Select a row for the full trace.</p></div></div>
        <form class="filters" id="mf">
          <input name="q" placeholder="Message id, MRN or order" value="${esc(msgFilters.q)}" aria-label="Search">
          <select name="status" aria-label="Status">${statuses.map((s) => `<option value="${s}" ${s === msgFilters.status ? "selected" : ""}>${s ? s.replace(/_/g, " ") : "Any status"}</option>`).join("")}</select>
          <input type="date" name="from" value="${esc(msgFilters.from)}" aria-label="From date">
          <input type="date" name="to" value="${esc(msgFilters.to)}" aria-label="To date">
          <button class="primary" type="submit">Search</button><button type="button" id="clear">Clear</button>
        </form>
        <div class="table-wrap"><table>
          <thead><tr><th>Correlation id</th><th>Received</th><th>Type</th><th>Patient</th><th>Order</th><th>Status</th><th>Decided by</th><th>Attempts</th><th>Scenario</th></tr></thead>
          <tbody>${rows.length ? rows.map((r) => `<tr class="clickable" data-corr="${esc(r.correlationId)}" tabindex="0">
            <td class="mono">${esc(r.correlationId)}</td><td>${fmtTime(r.receivedAt)}</td><td>${esc(r.messageType)}</td>
            <td class="mono">${esc(r.patientRef) || '<span class="muted">missing</span>'}</td><td class="mono">${esc(r.orderRef)}</td>
            <td>${pill(r.status)}</td><td>${esc(r.decidedBy)}</td><td>${esc(r.deliveryAttempts)}</td><td class="muted">${esc(r.scenario)}</td></tr>`).join("")
            : `<tr><td colspan="9" class="empty">No messages match.</td></tr>`}</tbody></table></div>`;
      document.getElementById("mf").addEventListener("submit", (ev) => {
        ev.preventDefault();
        new FormData(ev.target).forEach((v, k) => { msgFilters[k] = v; });
        messages();
      });
      document.getElementById("clear").addEventListener("click", () => { Object.keys(msgFilters).forEach((k) => (msgFilters[k] = "")); messages(); });
      view.querySelectorAll("tr[data-corr]").forEach((tr) => {
        const go = () => (location.hash = "#/message/" + encodeURIComponent(tr.dataset.corr));
        tr.addEventListener("click", go);
        tr.addEventListener("keydown", (e) => { if (e.key === "Enter") go(); });
      });
      schedule(messages, 8000);
    } catch (e) { fail(e); }
  }

  /* ---------- Message detail / trace ---------- */
  function rulesList(rules) {
    return `<ul class="rules">${rules.map((r) => `<li><span class="mark ${r.passed ? "pass" : "fail"}" aria-label="${r.passed ? "passed" : "failed"}">${r.passed ? "✓" : "✕"}</span>
      <span><strong>${esc(r.rule)}</strong> <span class="muted">${esc(r.detail)}</span></span></li>`).join("")}</ul>`;
  }
  function runBlock(run) {
    const tokens = (run.promptTokens || run.completionTokens) ? `${run.promptTokens ?? "?"} in / ${run.completionTokens ?? "?"} out` : "not reported";
    return `<div class="card">
      <div class="section-title"><h3>Agent run ${esc(run.runId)} · ${esc(run.agent)}</h3>${pill(run.outcome)}</div>
      <dl class="kv">
        <dt>Mode</dt><dd>${pill(run.mode)} ${run.mode === "REPLAY" ? '<span class="muted">scripted reply, real tool calls</span>' : ""}</dd>
        <dt>Provider / model</dt><dd>${esc(run.provider)} · ${esc(run.model)}</dd>
        <dt>Started</dt><dd>${fmtTime(run.startedAt)} · ${esc(run.durationMs)} ms · ${esc(run.attempts)} attempt(s)</dd>
        <dt>Tokens</dt><dd>${esc(tokens)}</dd>
        <dt>Recommended</dt><dd>${pill(run.recommendedAction)}</dd>
        ${run.error ? `<dt>Problems</dt><dd class="mono">${esc(run.error)}</dd>` : ""}
      </dl>
      ${run.recommendation ? `<p style="margin:.6rem 0 .2rem"><strong>Reason:</strong> ${esc(run.recommendation.reason)}</p>
        <p style="margin:0"><strong>Evidence:</strong> ${(run.recommendation.evidence || []).map((e) => `<code>${esc(e)}</code>`).join(" ")}</p>` : ""}
      <details style="margin-top:.6rem"><summary>Tool calls (${run.toolCalls.length})</summary>
        ${run.toolCalls.map((t) => `<div class="tool"><strong class="mono">${esc(t.tool)}</strong> ${t.authorization === "DENIED" ? pill("DENIED") : ""}
          <span class="muted">${esc(t.arguments)} · ${esc(t.durationMs)} ms</span><pre class="json">${esc(t.result || t.error)}</pre></div>`).join("") || '<div class="muted">No tool calls.</div>'}
      </details>
      <details><summary>Agent input (sanitised)</summary><pre class="json">${esc(JSON.stringify(run.input, null, 2))}</pre></details>
      <details><summary>Raw model output</summary><pre class="json">${esc(run.rawOutput)}</pre></details>
    </div>`;
  }
  async function messageDetail(corr) {
    setActive("messages");
    try {
      const m = await api("/messages/" + encodeURIComponent(corr));
      const p = m.parsed;
      view.innerHTML = `
        <div class="page-head"><div><a href="#/messages">← Message explorer</a>
          <h1 class="mono" style="margin-top:.3rem">${esc(m.correlationId)}</h1>
          <p>${esc(m.messageType)} from ${esc(m.sendingApplication)} · control id <code>${esc(m.controlId)}</code> · received ${fmtTime(m.receivedAt)}</p></div>
          <div>${pill(m.status)} ${m.decidedBy ? `<span class="muted">decided by ${esc(m.decidedBy)}</span>` : ""}</div></div>
        <div class="grid detail-grid">
          <div>
            <div class="card"><h2>Original message <span class="muted" style="font-weight:400">(immutable)</span></h2>
              <pre class="hl7">${esc(m.raw.replace(/\r/g, "\n"))}</pre>
              <dl class="kv" style="margin-top:.6rem">
                <dt>Patient (PID-3)</dt><dd class="mono">${esc(p.pid.mrn) || '<span class="muted">missing</span>'}</dd>
                <dt>Order (OBR-2)</dt><dd class="mono">${esc(p.obr.placerOrderNumber)}</dd>
                <dt>Test</dt><dd>${esc(p.obr.testCode)} ${esc(p.obr.testName)}</dd>
                <dt>Result status</dt><dd>${esc(m.resultStatus)}</dd>
                <dt>Delivery attempts</dt><dd>${esc(m.deliveryAttempts)}</dd>
                <dt>Interop session</dt><dd>${esc(m.sessionId)} <span class="muted">(Visual Trace in the Management Portal)</span></dd>
              </dl></div>
            ${m.cases.map((c) => `
              <div class="card"><div class="section-title"><h2>Exception case ${esc(c.caseId)}: ${esc(c.exceptionType.replace(/_/g, " "))}</h2>${pill(c.status)}</div>
                <h3>Validation findings</h3>
                <table><tbody>${c.findings.map((f) => `<tr><td class="mono">${esc(f.code)}</td><td>${pill(f.severity === "error" ? "ERROR" : f.severity === "warning" ? "WARNING" : "INFO")}</td><td>${esc(f.detail)}</td></tr>`).join("")}</tbody></table>
                <details style="margin-top:.5rem"><summary>Synthetic context retrieved</summary><pre class="json">${esc(JSON.stringify(c.context, null, 2))}</pre></details>
                ${c.resolution ? `<p style="margin:.6rem 0 0"><strong>Resolution:</strong> ${pill(c.resolution)} by ${esc(c.resolvedBy)}${c.reviewNote ? ` · “${esc(c.reviewNote)}”` : ""}</p>` : ""}
              </div>
              ${c.agentRuns.map(runBlock).join("")}
              ${c.policy.map((pe) => `<div class="card"><div class="section-title"><h3>Policy gate · ${esc(pe.source)} recommendation ${esc(pe.recommendedAction || "(none)")}</h3>${pill(pe.approved ? "APPROVED" : "REJECTED")}</div>
                <p style="margin:0 0 .3rem">${esc(pe.summary)}</p>${rulesList(pe.rules)}</div>`).join("")}
            `).join("")}
          </div>
          <div>
            <div class="card"><h2>Timeline</h2><ol class="timeline">${m.timeline.map((t) => `<li><div class="ev">${esc(t.event.replace(/_/g, " "))}</div>
              <div class="meta">${fmtTime(t.at)} · ${esc(t.actor)}</div><div>${esc(t.detail)}</div></li>`).join("")}</ol></div>
            <div class="card"><h2>Execution</h2>
              ${m.delivery ? `<p>Delivered to the EMR receiver (ref ${esc(m.delivery.receiverRef)}) at ${fmtTime(m.delivery.deliveredAt)}.</p>` : `<p class="muted">Not delivered to the EMR.</p>`}
              ${m.queueItems.length ? `<table><thead><tr><th>Queue</th><th>Status</th><th>Detail</th></tr></thead><tbody>${m.queueItems.map((q) => `<tr><td>${esc(q.queue)}</td><td>${pill(q.status)}</td>
                <td>${q.dueAt ? "Due " + fmtTime(q.dueAt) + "<br>" : ""}<span class="mono" style="font-size:11.5px">${esc(q.reason)}</span></td></tr>`).join("")}</tbody></table>` : ""}
            </div>
          </div>
        </div>`;
      if (["INVESTIGATING", "VALIDATING", "RETRY_PENDING", "RECEIVED", "MANUAL_REVIEW"].includes(m.status)) schedule(() => messageDetail(corr), 3000);
    } catch (e) { fail(e); }
  }

  /* ---------- Manual review ---------- */
  async function review() {
    setActive("review");
    try {
      const [tasks, scen] = await Promise.all([api("/review"), api("/scenarios")]);
      const followUps = Object.fromEntries(scen.filter((s) => s.followUp).map((s) => [s.name, s.followUp]));
      view.innerHTML = `
        <div class="page-head"><div><h1>Manual review queue</h1>
          <p>Cases handed to people through the IRIS Workflow Engine (role <code>CareBridge.ManualReview</code>). Only the actions the policy allows for each exception are offered, a note is required, and the decision is checked by the policy gate again before it runs.</p></div></div>
        ${tasks.length ? tasks.map((t) => `
          <div class="card" data-case="${esc(t.caseId)}">
            <div class="section-title"><h2>${esc(t.exceptionType.replace(/_/g, " "))} · <a class="mono" href="#/message/${encodeURIComponent(t.correlationId)}">${esc(t.correlationId)}</a></h2>
              <span class="muted">Task ${esc(t.taskId)} · case ${esc(t.caseId)} · ${fmtTime(t.createdAt)}</span></div>
            <p style="margin:0 0 .4rem">Patient <code>${esc(t.patientRef) || "missing"}</code> · order <code>${esc(t.orderRef)}</code>${t.scenario ? ` · scenario <em>${esc(t.scenario)}</em>` : ""}</p>
            <p class="muted" style="margin:0 0 .6rem">${esc(t.lastPolicy)}</p>
            ${followUps[t.scenario] ? `<p style="margin:0 0 .6rem"><button data-followup="${esc(t.scenario)}">${esc(followUps[t.scenario])}</button> <span class="muted">Simulates the HIS sending the missing registration.</span></p>` : ""}
            <div class="filters">
              <label>Reviewer <select name="reviewer"><option>reviewer.demo</option><option>lab.supervisor</option></select></label>
              <label>Action <select name="action">${t.actions.split(",").map((a) => `<option value="${esc(a)}">${esc(a.replace(/_/g, " "))}</option>`).join("")}</select></label>
            </div>
            <label>Review note (required)<textarea name="note" placeholder="Why this decision is safe"></textarea></label>
            <div style="margin-top:.5rem"><button class="primary" data-submit>Submit decision</button> <span class="muted" data-result></span></div>
          </div>`).join("") : `<div class="card empty">No cases are waiting for review.</div>`}`;
      view.querySelectorAll("[data-followup]").forEach((b) => b.addEventListener("click", async () => {
        b.disabled = true;
        try { await post(`/scenarios/${encodeURIComponent(b.dataset.followup)}/followup`); b.textContent = "HIS registration sent"; }
        catch (e) { b.textContent = "Failed: " + e.message; }
      }));
      view.querySelectorAll("[data-case]").forEach((card) => {
        card.querySelector("[data-submit]").addEventListener("click", async (ev) => {
          const out = card.querySelector("[data-result]");
          ev.target.disabled = true; out.textContent = "Submitting…";
          try {
            await post("/review/" + card.dataset.case, {
              action: card.querySelector("[name=action]").value,
              note: card.querySelector("[name=note]").value,
              reviewer: card.querySelector("[name=reviewer]").value
            });
            out.textContent = "Submitted to the policy gate.";
            setTimeout(review, 1500); refreshChrome();
          } catch (e) { out.textContent = e.message; ev.target.disabled = false; }
        });
      });
    } catch (e) { fail(e); }
  }

  /* ---------- Agent activity ---------- */
  async function agent() {
    setActive("agent");
    try {
      const runs = await api("/agent-runs");
      view.innerHTML = `
        <div class="page-head"><div><h1>Agent activity</h1>
          <p>Every invocation of <code>CareBridge.ExceptionInvestigator</code>. Token counts are shown only when the provider reports them; nothing is estimated.</p></div></div>
        <div class="table-wrap"><table>
          <thead><tr><th>Run</th><th>Started</th><th>Message</th><th>Mode</th><th>Provider / model</th><th>Duration</th><th>Tokens in/out</th><th>Tools</th><th>Outcome</th><th>Recommended</th><th>Policy</th></tr></thead>
          <tbody>${runs.length ? runs.map((r) => `<tr class="clickable" data-corr="${esc(r.correlationId)}" tabindex="0">
            <td>${esc(r.runId)}</td><td>${fmtTime(r.startedAt)}</td><td class="mono">${esc(r.correlationId)}</td><td>${pill(r.mode)}</td>
            <td>${esc(r.provider)}<br><span class="muted">${esc(r.model)}</span></td><td>${esc(r.durationMs)} ms</td>
            <td>${r.promptTokens || r.completionTokens ? esc(r.promptTokens) + " / " + esc(r.completionTokens) : '<span class="muted">not reported</span>'}</td>
            <td>${r.toolCalls.length}</td><td>${pill(r.outcome)}${r.error ? `<br><span class="muted" style="font-size:11.5px">${esc(r.error.slice(0, 120))}</span>` : ""}</td>
            <td>${pill(r.recommendedAction)}</td>
            <td>${r.policy ? pill(r.policy.approved ? "APPROVED" : "REJECTED") + "<br>" + pill(r.policy.finalAction) : ""}</td></tr>`).join("")
            : `<tr><td colspan="11" class="empty">The agent has not run yet. Run a scenario with an exception.</td></tr>`}</tbody></table></div>`;
      view.querySelectorAll("tr[data-corr]").forEach((tr) => tr.addEventListener("click", () => (location.hash = "#/message/" + encodeURIComponent(tr.dataset.corr))));
      schedule(agent, 8000);
    } catch (e) { fail(e); }
  }

  /* ---------- Scenarios ---------- */
  const jobs = {};
  async function scenarios() {
    setActive("scenarios");
    try {
      const [list, mode] = await Promise.all([api("/scenarios"), api("/mode")]);
      const card = (s) => `<div class="card scenario" data-name="${esc(s.name)}">
          <div class="row"><h3 style="margin:0">${esc(s.title)}</h3><span>expect ${pill(s.expect)}</span></div>
          <div class="muted">${esc(s.description)}</div>
          <div class="row"><button data-run="${esc(s.name)}">Run</button><span data-status class="muted"></span></div></div>`;
      view.innerHTML = `
        <div class="page-head"><div><h1>Demo scenarios</h1>
          <p>Each scenario sends synthetic HL7 over MLLP to the running production, exactly like an external LIS or HIS. Nothing bypasses IRIS.</p></div>
          <div style="display:flex;gap:.5rem;flex-wrap:wrap">
            <button class="primary" data-run="all">Run all scenarios</button>
            <button id="reset" class="danger">Reset demo data</button></div></div>
        <div class="card"><div class="section-title"><h2>Agent mode</h2>${pill(mode.mode)}</div>
          <p style="margin:0 0 .5rem">${mode.mode === "LIVE"
            ? `LIVE: the AI Hub agent calls <strong>${esc(mode.provider)}</strong> model <strong>${esc(mode.model)}</strong>${mode.baseUrl ? ` at <code>${esc(mode.baseUrl)}</code>` : ""}. Adversarial scenarios then test the real model instead of fixtures.`
            : "REPLAY: the production, tools, contract validator and policy gate all run for real; the agent's reply is a scripted fixture. No API key needed."}</p>
          ${mode.modeLocked ? '<p class="muted" style="margin:0">Mode switching is disabled on this deployment.</p>' :
            `<button id="toggle-mode" ${mode.mode === "REPLAY" && !mode.liveAvailable ? "disabled" : ""}>Switch to ${mode.mode === "LIVE" ? "REPLAY" : "LIVE"}</button>
             ${!mode.liveAvailable ? '<span class="muted">AI Hub classes not available in this instance.</span>' : (mode.mode === "REPLAY" && !mode.keyConfigured && !mode.baseUrl ? '<span class="muted">No model key or endpoint configured; LIVE runs will fall back to manual review.</span>' : "")}`}
        </div>
        <div id="report"></div>
        <h2 style="margin:1.25rem 0 .5rem">Core workflow</h2>
        <div class="grid two">${list.filter((s) => s.group === "core").map(card).join("")}</div>
        <h2 style="margin:1.25rem 0 .5rem">Adversarial and failure tests</h2>
        <div class="grid two">${list.filter((s) => s.group !== "core").map(card).join("")}</div>`;
      view.querySelectorAll("[data-run]").forEach((b) => b.addEventListener("click", () => startRun(b.dataset.run, b)));
      const reset = document.getElementById("reset");
      reset.addEventListener("click", async () => {
        if (!confirm("Delete all demo messages, cases and audit records and restore the synthetic registry?")) return;
        reset.disabled = true;
        try { await post("/reset"); reset.textContent = "Reset done"; refreshChrome(); } catch (e) { reset.textContent = e.message; }
      });
      const t = document.getElementById("toggle-mode");
      if (t) t.addEventListener("click", async () => { await post("/mode", { mode: mode.mode === "LIVE" ? "REPLAY" : "LIVE" }); refreshChrome(); scenarios(); });
    } catch (e) { fail(e); }
  }
  async function startRun(name, btn) {
    btn.disabled = true;
    const statusEl = name === "all" ? null : view.querySelector(`[data-name="${CSS.escape(name)}"] [data-status]`);
    const report = document.getElementById("report");
    if (statusEl) statusEl.textContent = "Running…";
    if (name === "all") report.innerHTML = `<div class="notice">Running all scenarios through the production. The retry scenarios wait for the retry scheduler, so this takes a few minutes.</div>`;
    try {
      const j = await post(`/scenarios/${encodeURIComponent(name)}/run`);
      jobs[name] = j.jobId;
      const poll = async () => {
        const s = await api("/jobs/" + j.jobId);
        if (s.status === "DONE" || s.status === "ERROR") {
          btn.disabled = false;
          const r = s.result || {};
          if (name === "all") {
            report.innerHTML = `<div class="card"><h2>Run report · ${esc(r.passed)} passed, ${esc(r.failed)} failed · mode ${esc(r.mode)}</h2>
              <table><thead><tr><th>Scenario</th><th>Expected</th><th>Got</th><th>Result</th><th>Message</th></tr></thead><tbody>
              ${(r.results || []).map((x) => { const last = (x.messages || []).slice(-1)[0] || {}; const corr = last.final ? last.final.correlationId : "";
                return `<tr><td>${esc(x.title)}</td><td>${pill(x.expect)}</td><td>${pill(x.outcome)}</td><td>${x.passed ? pill("PASS") : pill("FAIL")}</td>
                <td>${corr ? `<a class="mono" href="#/message/${encodeURIComponent(corr)}">${esc(corr)}</a>` : ""}</td></tr>`; }).join("")}</tbody></table></div>`;
          } else if (statusEl) {
            const last = (r.messages || []).slice(-1)[0] || {};
            const corr = last.final ? last.final.correlationId : "";
            statusEl.innerHTML = r.error ? esc(r.error) : `${pill(r.outcome)} ${r.passed ? "as expected" : "unexpected"} ${corr ? `· <a class="mono" href="#/message/${encodeURIComponent(corr)}">${esc(corr)}</a>` : ""}`;
          }
          refreshChrome();
        } else setTimeout(poll, 1500);
      };
      poll();
    } catch (e) { btn.disabled = false; if (statusEl) statusEl.textContent = e.message; else report.innerHTML = `<div class="notice bad">${esc(e.message)}</div>`; }
  }

  OUTCOME_CLASS.PASS = "ok"; OUTCOME_CLASS.FAIL = "bad"; OUTCOME_CLASS.APPROVED = "ok"; OUTCOME_CLASS.DENIED = "bad"; OUTCOME_CLASS.LIVE = "ok"; OUTCOME_CLASS.REPLAY = "info";
  OUTCOME_CLASS.ERROR = "bad"; OUTCOME_CLASS.WARNING = "warn"; OUTCOME_CLASS.INFO = "info";

  function route() {
    clearTimeout(refreshTimer);
    const h = location.hash.replace(/^#\/?/, "");
    const [page, arg] = h.split("/");
    if (page === "message" && arg) messageDetail(decodeURIComponent(arg));
    else if (page === "messages") messages();
    else if (page === "review") review();
    else if (page === "agent") agent();
    else if (page === "scenarios") scenarios();
    else overview();
    view.focus({ preventScroll: true });
  }
  window.addEventListener("hashchange", route);
  route();
  refreshChrome();
  setInterval(() => { if (document.visibilityState === "visible") refreshChrome(); }, 10000);
})();
