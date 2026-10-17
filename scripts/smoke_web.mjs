import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { mkdir, readFile, writeFile, mkdtemp, rm } from "node:fs/promises";
import { extname, join, normalize, resolve } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

const root = resolve(fileURLToPath(new URL("..", import.meta.url)));
const webRoot = join(root, "web");
const outDir = join(root, "build", "web-smoke");
const chrome = process.env.CHROME_BIN ||
  (process.platform === "darwin"
    ? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    : "chromium");
const mime = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".png": "image/png",
};

function serve() {
  return new Promise((resolveServer, reject) => {
    const server = createServer(async (request, response) => {
      try {
        const url = new URL(request.url, "http://127.0.0.1");
        const relative = url.pathname === "/" ? "/index.html" : url.pathname;
        const path = normalize(join(webRoot, relative));
        if (!path.startsWith(webRoot)) {
          response.writeHead(403).end();
          return;
        }
        const body = await readFile(path);
        response.writeHead(200, { "content-type": mime[extname(path)] || "application/octet-stream" });
        response.end(body);
      } catch {
        response.writeHead(404).end();
      }
    });
    server.on("error", reject);
    server.listen(0, "127.0.0.1", () => resolveServer(server));
  });
}

function delay(ms) {
  return new Promise((resolveDelay) => setTimeout(resolveDelay, ms));
}

async function waitFor(url, timeout = 15000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(url);
      if (response.ok) return;
    } catch {
      // Chrome is still starting.
    }
    await delay(100);
  }
  throw new Error(`timed out waiting for ${url}`);
}

class CDP {
  constructor(url) {
    this.socket = new WebSocket(url);
    this.nextId = 1;
    this.pending = new Map();
  }

  async open() {
    await new Promise((resolveOpen, reject) => {
      this.socket.addEventListener("open", resolveOpen, { once: true });
      this.socket.addEventListener("error", reject, { once: true });
    });
    this.socket.addEventListener("message", (event) => {
      const message = JSON.parse(event.data);
      const pending = this.pending.get(message.id);
      if (!pending) return;
      this.pending.delete(message.id);
      if (message.error) pending.reject(new Error(message.error.message));
      else pending.resolve(message.result);
    });
  }

  send(method, params = {}) {
    const id = this.nextId++;
    return new Promise((resolveSend, reject) => {
      this.pending.set(id, { resolve: resolveSend, reject });
      this.socket.send(JSON.stringify({ id, method, params }));
    });
  }

  close() {
    this.socket.close();
  }
}

async function evaluate(cdp, expression) {
  const result = await cdp.send("Runtime.evaluate", {
    expression,
    returnByValue: true,
    awaitPromise: true,
  });
  if (result.exceptionDetails) {
    throw new Error(result.exceptionDetails.text || "evaluation failed");
  }
  return result.result.value;
}

async function state(cdp) {
  return JSON.parse(await evaluate(cdp, "window.__gpuiDemo.state()"));
}

async function click(cdp, x, y) {
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mousePressed",
    x,
    y,
    button: "left",
    clickCount: 1,
  });
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mouseReleased",
    x,
    y,
    button: "left",
    clickCount: 1,
  });
  await delay(120);
}

async function text(cdp, value) {
  for (const character of value) {
    const code = /^[a-z]$/i.test(character)
      ? `Key${character.toUpperCase()}`
      : character;
    await cdp.send("Input.dispatchKeyEvent", {
      type: "keyDown",
      key: character,
      code,
      text: character,
    });
    await cdp.send("Input.dispatchKeyEvent", {
      type: "keyUp",
      key: character,
      code,
    });
  }
  await delay(120);
}

async function key(cdp, keyName, code, modifiers = 0) {
  await cdp.send("Input.dispatchKeyEvent", {
    type: "keyDown",
    key: keyName,
    code,
    modifiers,
  });
  await cdp.send("Input.dispatchKeyEvent", {
    type: "keyUp",
    key: keyName,
    code,
    modifiers,
  });
  await delay(120);
}

async function shot(cdp, name) {
  const result = await cdp.send("Page.captureScreenshot", { format: "png" });
  await writeFile(join(outDir, name), Buffer.from(result.data, "base64"));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const server = await serve();
const port = server.address().port;
const profile = await mkdtemp(join(tmpdir(), "gpui-web-smoke-"));
const browser = spawn(chrome, [
  "--headless=new",
  "--no-sandbox",
  "--disable-gpu",
  "--disable-dev-shm-usage",
  "--no-first-run",
  "--no-default-browser-check",
  "--hide-scrollbars",
  `--user-data-dir=${profile}`,
  "--window-size=1200,760",
  "--remote-debugging-port=9223",
  `http://127.0.0.1:${port}/index.html`,
], { stdio: ["ignore", "ignore", "ignore"] });

try {
  await rm(outDir, { recursive: true, force: true });
  await mkdir(outDir, { recursive: true });
  await waitFor("http://127.0.0.1:9223/json/version");
  const pages = await (await fetch("http://127.0.0.1:9223/json/list")).json();
  const page = pages.find((candidate) => candidate.type === "page");
  assert(page, "no Chrome page target");
  const cdp = new CDP(page.webSocketDebuggerUrl);
  await cdp.open();
  await cdp.send("Page.enable");
  await cdp.send("Runtime.enable");
  await delay(1200);

  let current = await state(cdp);
  assert(current.ok && current.page === "Overview" && current.clicks === 0, `unexpected initial state ${JSON.stringify(current)}`);
  await shot(cdp, "01-overview.png");

  await click(cdp, 320, 241);
  current = await state(cdp);
  assert(current.clicks === 1, `increment failed: ${JSON.stringify(current)}`);

  await click(cdp, 80, 186);
  current = await state(cdp);
  assert(current.page === "Controls", `controls nav failed: ${JSON.stringify(current)}`);
  await click(cdp, 700, 353);
  await text(cdp, "hello");
  current = await state(cdp);
  assert(current.note === "hello", `note input failed: ${JSON.stringify(current)}`);
  await shot(cdp, "02-controls.png");

  await click(cdp, 1095, 50);
  current = await state(cdp);
  assert(current.palette === true, `palette did not open: ${JSON.stringify(current)}`);
  await shot(cdp, "03-palette.png");
  await text(cdp, "accent");
  await key(cdp, "Enter", "Enter");
  current = await state(cdp);
  assert(current.palette === false, `palette did not close: ${JSON.stringify(current)}`);
  assert(current.accent === "Violet", `accent command failed: ${JSON.stringify(current)}`);
  await shot(cdp, "04-accent.png");

  await click(cdp, 68, 240);
  current = await state(cdp);
  assert(current.page === "Lists", `lists nav failed: ${JSON.stringify(current)}`);
  await click(cdp, 700, 400);
  await shot(cdp, "05-lists.png");

  console.log("WEB_SMOKE PASS", JSON.stringify(current));
  cdp.close();
} catch (error) {
  console.error("WEB_SMOKE FAIL", error.stack || String(error));
  process.exitCode = 1;
} finally {
  browser.kill("SIGTERM");
  await delay(500);
  server.close();
  try {
    await rm(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
  } catch {
    // Chrome may still be flushing its profile; the test result is authoritative.
  }
}
