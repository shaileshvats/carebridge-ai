// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Shailesh Vats
// Minimal Chrome DevTools Protocol helper: launch headless Chrome, capture frames, drive the real page.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export async function launch({ port = 9333, width = 1280, height = 800, profile }) {
  fs.rmSync(profile, { recursive: true, force: true });
  const proc = spawn(CHROME, [
    '--headless=new', `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`,
    `--window-size=${width},${height}`, '--no-first-run', '--no-default-browser-check', '--disable-extensions',
    '--hide-scrollbars', '--force-device-scale-factor=1', '--force-dark-mode', '--blink-settings=preferredColorScheme=0',
    'about:blank',
  ], { stdio: ['ignore', 'ignore', 'pipe'] });
  let wsUrl = null;
  for (let i = 0; i < 100 && !wsUrl; i++) {
    await sleep(150);
    try {
      const list = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
      wsUrl = list.find((t) => t.type === 'page')?.webSocketDebuggerUrl;
    } catch { /* not up yet */ }
  }
  if (!wsUrl) throw new Error('chrome did not start');
  const cdp = await connect(wsUrl);
  await cdp.send('Page.enable');
  await cdp.send('Runtime.enable');
  await cdp.send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: false });
  await cdp.send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-color-scheme', value: 'dark' }] });
  return { proc, cdp };
}

async function connect(url) {
  const ws = new WebSocket(url);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
  let id = 0;
  const pending = new Map();
  const listeners = [];
  ws.onmessage = (ev) => {
    const m = JSON.parse(ev.data);
    if (m.id && pending.has(m.id)) {
      const { res, rej } = pending.get(m.id);
      pending.delete(m.id);
      m.error ? rej(new Error(m.error.message)) : res(m.result);
    } else if (m.method) listeners.forEach((l) => l(m));
  };
  return {
    send: (method, params = {}) => new Promise((res, rej) => { const i = ++id; pending.set(i, { res, rej }); ws.send(JSON.stringify({ id: i, method, params })); }),
    on: (fn) => listeners.push(fn),
    close: () => ws.close(),
  };
}

// Frame recorder: captures the page at a steady rate; each frame records how long it should be shown.
export class Recorder {
  constructor(cdp, dir) {
    this.cdp = cdp; this.dir = dir; this.frames = []; this.caption = ''; this.speed = 1; this.interval = 125; this.running = false; this.n = 0; this.badge = '';
    fs.mkdirSync(dir, { recursive: true });
  }
  start() {
    this.running = true;
    this.loop = (async () => {
      let last = Date.now();
      let prev = null; // only frames captured by this run get their duration measured
      while (this.running) {
        const t0 = Date.now();
        const shot = await this.cdp.send('Page.captureScreenshot', { format: 'jpeg', quality: 82 });
        const file = path.join(this.dir, `f${String(this.n++).padStart(6, '0')}.jpg`);
        fs.writeFileSync(file, Buffer.from(shot.data, 'base64'));
        const now = Date.now();
        if (prev) prev.dur = (now - last) / 1000 / prev.speed;
        prev = { file, dur: this.interval / 1000, caption: this.caption, badge: this.badge, speed: this.speed };
        this.frames.push(prev);
        last = now;
        const wait = this.interval * this.speed - (Date.now() - t0);
        if (wait > 0) await sleep(wait);
      }
    })();
  }
  async stop() { this.running = false; await this.loop; }
  // A still frame shown for `secs` (title cards, labelled screenshots).
  still(file, secs, caption, badge = '') { this.frames.push({ file, dur: secs, caption, badge, speed: 1 }); }
  manifest(out) { fs.writeFileSync(out, JSON.stringify(this.frames.map(({ file, dur, caption, badge, speed }) => ({ file, dur, caption, badge, speed })), null, 1)); }
}

// ---- page actions (all act on the real application's DOM) ----
export async function evaluate(cdp, expr) {
  const r = await cdp.send('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true });
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
  return r.result.value;
}
export async function goto(cdp, url, settle = 1500) {
  await cdp.send('Page.navigate', { url });
  await sleep(settle);
}
export async function waitFor(cdp, expr, timeout = 30000) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) {
    if (await evaluate(cdp, `!!(${expr})`).catch(() => false)) return true;
    await sleep(250);
  }
  throw new Error(`timed out waiting for ${expr}`);
}
// Click the first visible element matching selector whose text contains `text`, with a real mouse event at its centre.
export async function clickText(cdp, selector, text) {
  const box = await evaluate(cdp, `(() => {
    const el = [...document.querySelectorAll(${JSON.stringify(selector)})].find(e => e.offsetParent !== null && e.innerText.includes(${JSON.stringify(text)}));
    if (!el) return null;
    el.scrollIntoView({ block: 'center', behavior: 'instant' });
    const r = el.getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
  })()`);
  if (!box) throw new Error(`no ${selector} with text ${text}`);
  await sleep(350);
  for (const type of ['mouseMoved', 'mousePressed', 'mouseReleased']) {
    await cdp.send('Input.dispatchMouseEvent', { type, x: box.x, y: box.y, button: 'left', clickCount: 1 });
  }
}
export async function typeInto(cdp, selector, text) {
  await evaluate(cdp, `(() => { const el = document.querySelector(${JSON.stringify(selector)}); el.scrollIntoView({block:'center'}); el.focus(); el.value=''; })()`);
  for (const ch of text) { await cdp.send('Input.insertText', { text: ch }); await sleep(35); }
}
export async function smoothScroll(cdp, total, steps = 30, pause = 60) {
  for (let i = 0; i < steps; i++) { await evaluate(cdp, `window.scrollBy(0, ${total / steps})`); await sleep(pause); }
}
export async function scrollToEl(cdp, selector, offset = 110) {
  await evaluate(cdp, `(() => { const el = document.querySelector(${JSON.stringify(selector)}); if (!el) return false; window.scrollTo({ top: el.getBoundingClientRect().top + scrollY - ${offset}, behavior: 'instant' }); return true; })()`);
}
