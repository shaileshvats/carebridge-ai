// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Shailesh Vats
// Records the CareBridge demo from the real running application (headless Chrome + CDP).
// Prerequisites: the stack is running (docker compose up), and for the LIVE segment an AI Hub provider is configured.
// usage: node tools/video/record.mjs <framesDir> <manifest.json>
// then:  swiftc -O tools/video/encode.swift -o /tmp/encode && /tmp/encode <manifest.json> out.mp4 1280 800
import path from 'node:path';
import fs from 'node:fs';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { launch, Recorder, evaluate, goto, waitFor, sleep, typeInto, smoothScroll, scrollToEl } from './cdp.mjs';

const [framesDir = '/tmp/cb-frames', manifest = '/tmp/cb-manifest.json'] = process.argv.slice(2);
const APP = 'http://localhost:52773/carebridge/index.html';
const API = 'http://localhost:52773/api/carebridge';
const CARDS = pathToFileURL(path.join(path.dirname(fileURLToPath(import.meta.url)), 'cards.html')).href;

const post = (p, body) => fetch(API + p, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) }).then((r) => r.json());

// Start from a clean, known state (setup, not filmed).
await post('/reset');
await post('/mode', { mode: 'REPLAY' });

fs.rmSync(framesDir, { recursive: true, force: true });
const { proc, cdp } = await launch({ width: 1280, height: 800, profile: '/tmp/cb-video-profile' });
const rec = new Recorder(cdp, framesDir);

async function card(name, secs, caption) {
  await goto(cdp, `${CARDS}?card=${name}`, 700);
  const shot = await cdp.send('Page.captureScreenshot', { format: 'jpeg', quality: 90 });
  const file = path.join(framesDir, `card-${name}.jpg`);
  fs.writeFileSync(file, Buffer.from(shot.data, 'base64'));
  rec.still(file, secs, caption);
}
// Real mouse click on the first visible element matching a CSS selector.
async function click(selector) {
  const box = await evaluate(cdp, `(() => { const el = document.querySelector(${JSON.stringify(selector)}); if (!el) return null;
    el.scrollIntoView({ block: 'center', behavior: 'instant' }); const r = el.getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2 }; })()`);
  if (!box) throw new Error('nothing matches ' + selector);
  await sleep(400);
  for (const type of ['mouseMoved', 'mousePressed', 'mouseReleased']) await cdp.send('Input.dispatchMouseEvent', { type, x: box.x, y: box.y, button: 'left', clickCount: 1 });
}
// Run a scenario from the Demo scenarios page and wait (sped up) until it finishes; returns its correlation id.
async function runScenario(name, speed = 4) {
  await goto(cdp, `${APP}#/scenarios`, 1500);
  await click(`button[data-run="${name}"]`);
  rec.speed = speed;
  await waitFor(cdp, `document.querySelector('[data-name="${name}"] [data-status] a')`, 240000);
  rec.speed = 1;
  await sleep(1500);
  return evaluate(cdp, `document.querySelector('[data-name="${name}"] [data-status] a').textContent`);
}
async function setMode(mode) {
  await goto(cdp, `${APP}#/scenarios`, 1500);
  const current = await evaluate(cdp, `document.getElementById('mode-badge').textContent`);
  if (!current.startsWith(mode)) { await click('#toggle-mode'); await sleep(2000); }
}
async function openTrace(corr, settle = 2500) { await goto(cdp, `${APP}#/message/${corr}`, settle); }

// ---- film ----
await card('title', 8, 'CareBridge AI: an InterSystems IRIS interoperability production with an AI Hub agent and a deterministic policy gate.');
await card('problem', 12, 'A lab result can be valid HL7 and still be unsafe to route. Today people investigate these exceptions by hand.');
await card('arch', 17, 'The LIS and HIS send HL7 over MLLP. On an exception the AI Hub agent investigates; the policy gate decides what the production may do.');

await goto(cdp, `${APP}#/overview`, 1500);
rec.start();
rec.badge = 'REPLAY · scripted agent replies';
rec.caption = 'The dashboard reads every number from IRIS. REPLAY mode: real production, tools and policy gate; only the agent reply is scripted.';
await sleep(7200);

rec.caption = 'A clean ORU^R01 arrives over MLLP. No exception, so no agent: it goes straight to the EMR.';
let corr = await runScenario('valid-result', 2);
await openTrace(corr);
rec.caption = 'Every message gets a correlation id, an immutable copy of the original and an audit timeline.';
await sleep(6400);

rec.caption = 'Switching to LIVE: the AI Hub agent calls a local Qwen3-4B model through the openai provider. No API cost.';
await setMode('LIVE');
rec.badge = 'LIVE · AI Hub agent';
await sleep(2500);
rec.caption = 'Unknown order: the patient exists but the order number does not. The agent investigates.';
corr = await runScenario('unknown-order', 3);
await openTrace(corr);
rec.caption = 'The exception case: deterministic validation findings from the HIS registry.';
await scrollToEl(cdp, '.detail-grid > div > .card:nth-child(2)', 80);
await sleep(5600);
rec.caption = 'The agent run: model, duration, tokens reported by AI Hub, and the read-only tool calls it made.';
await scrollToEl(cdp, '.detail-grid > div > .card:nth-child(3)', 80);
await evaluate(cdp, `document.querySelector('.detail-grid > div > .card:nth-child(3) details').open = true`);
await sleep(8000);
rec.caption = 'The policy gate checks the contract, the evidence, the action matrix, identity and retry rules before anything runs.';
await scrollToEl(cdp, '.detail-grid > div > .card:nth-child(4)', 80);
await sleep(8800);

rec.caption = 'Back to REPLAY for an adversarial test: a scripted "model" proposes merging patient records, then accepting.';
await setMode('REPLAY');
rec.badge = 'REPLAY · adversarial fixture';
corr = await runScenario('unsafe-action', 3);
await openTrace(corr);
await scrollToEl(cdp, '.detail-grid > div > .card:nth-child(3)', 80);
rec.caption = 'The contract validator rejects the merge and the extra patient_update field…';
await sleep(7200);
await scrollToEl(cdp, '.detail-grid > div > .card:nth-child(4)', 80);
rec.caption = '…and the policy gate rejects ACCEPT: not permitted for the agent, and patient identity is in conflict. A person decides.';
await sleep(8800);

rec.badge = 'REPLAY · scripted agent replies';
rec.caption = 'Unknown patient: identity is never guessed. The case becomes an IRIS Workflow Engine task.';
corr = await runScenario('unknown-patient', 3);
await goto(cdp, `${APP}#/review`, 2500);
const caseId = await evaluate(cdp, `[...document.querySelectorAll('[data-case]')].find(c => c.innerText.includes('unknown-patient')).dataset.case`);
const sel = (s) => `[data-case="${caseId}"] ${s}`;
rec.caption = 'A reviewer tries to accept the result, with a note.';
await typeInto(cdp, sel('textarea[name=note]'), 'Patient confirmed by the ward clerk');
await click(sel('[data-submit]'));
await sleep(6400);
await openTrace(corr);
await smoothScroll(cdp, 2600, 30, 50);
rec.caption = 'The policy gate refuses the human decision too: the patient is still not in the HIS registry. A new task is issued.';
await sleep(8800);

await goto(cdp, `${APP}#/review`, 2500);
rec.caption = 'The HIS now sends the registration (ADT^A04 over MLLP)…';
await click(sel('[data-followup]'));
await sleep(3000);
await typeInto(cdp, sel('textarea[name=note]'), 'Registration now complete in the HIS');
await click(sel('[data-submit]'));
rec.caption = '…and the same decision is approved by the policy gate and executed: the result is delivered to the EMR.';
await sleep(6400);
await openTrace(corr);
await waitFor(cdp, `document.body.innerText.includes('ACCEPTED')`, 30000).catch(() => {});
await sleep(1500);
await scrollToEl(cdp, '.timeline li:last-child', 400);
await sleep(8000);

await goto(cdp, `${APP}#/agent`, 2500);
rec.badge = '';
rec.caption = 'Agent activity: every run with its mode, model, duration, reported tokens, tool calls and policy verdict.';
await sleep(9600);
await rec.stop();

await card('end', 11, 'docker compose up · IPM package · 37 unit and 8 integration tests · synthetic data only.');
rec.manifest(manifest);
proc.kill();
console.log(`frames: ${rec.frames.length}, seconds: ${rec.frames.reduce((s, f) => s + f.dur, 0).toFixed(1)}`);
