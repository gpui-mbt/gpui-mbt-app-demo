import {
  gpui_app_demo_key,
  gpui_app_demo_pointer_down,
  gpui_app_demo_pointer_move,
  gpui_app_demo_pointer_up,
  gpui_app_demo_scene,
  gpui_app_demo_scroll,
  gpui_app_demo_set_viewport,
  gpui_app_demo_start,
  gpui_app_demo_state,
  gpui_app_demo_text,
} from "./moonbit.js";
import { drawSceneSnapshot } from "./canvas-renderer.js";

const canvas = document.querySelector("#demo-canvas");
const errorBox = document.querySelector("#demo-error");
const status = document.querySelector("#demo-status");
const context = canvas.getContext("2d", { alpha: false });

let width = 0;
let height = 0;
let scale = 1;
let frame = 0;

function fail(message) {
  errorBox.textContent = message;
  errorBox.hidden = false;
}

function ok(value) {
  return value === "ok" || value === "";
}

function updateStatus() {
  try {
    const state = JSON.parse(gpui_app_demo_state());
    if (state.ok) {
      status.textContent = `${state.page} · clicks ${state.clicks}`;
      document.title = `${state.page} — gpui.mbt app demo`;
    }
  } catch {
    // The canvas remains authoritative; a stale status label is harmless.
  }
}

function draw() {
  frame = 0;
  try {
    const raw = gpui_app_demo_scene();
    const snapshot = JSON.parse(raw);
    if (snapshot.ok === false) {
      fail(`scene error: ${snapshot.error}`);
      return;
    }
    drawSceneSnapshot(context, snapshot, { width, height, scale });
    errorBox.hidden = true;
  } catch (error) {
    fail(error?.message || String(error));
  }
  updateStatus();
}

function requestDraw() {
  if (frame !== 0) return;
  frame = requestAnimationFrame(draw);
}

function logicalPoint(event) {
  const bounds = canvas.getBoundingClientRect();
  return {
    x: (event.clientX - bounds.left) * (width / bounds.width),
    y: (event.clientY - bounds.top) * (height / bounds.height),
  };
}

function modifiers(event) {
  return [
    event.shiftKey ? "shift" : "",
    event.ctrlKey ? "ctrl" : "",
    event.altKey ? "alt" : "",
    (event.metaKey || event.ctrlKey) ? "meta" : "",
  ].filter(Boolean).join(" ");
}

function resize() {
  const bounds = canvas.getBoundingClientRect();
  const nextWidth = Math.max(320, Math.round(bounds.width));
  const nextHeight = Math.max(240, Math.round(bounds.height));
  const nextScale = Math.max(1, window.devicePixelRatio || 1);
  if (nextWidth === width && nextHeight === height && nextScale === scale) {
    return;
  }
  width = nextWidth;
  height = nextHeight;
  scale = nextScale;
  canvas.width = Math.round(width * scale);
  canvas.height = Math.round(height * scale);
  const result = gpui_app_demo_set_viewport(width, height, scale);
  if (!ok(result)) {
    fail(`viewport error: ${result}`);
    return;
  }
  requestDraw();
}

function keyName(event) {
  if (event.key === " ") return " ";
  return event.key;
}

function handleKeyDown(event) {
  const meta = event.metaKey || event.ctrlKey;
  if (meta && (event.key === "k" || event.key === "K" || /^[1-4]$/.test(event.key))) {
    event.preventDefault();
    gpui_app_demo_key(event.key.toLowerCase(), modifiers(event), event.repeat);
    requestDraw();
    return;
  }
  if (event.key === "Tab") {
    event.preventDefault();
    gpui_app_demo_key("Tab", modifiers(event), event.repeat);
    requestDraw();
    return;
  }
  if (event.key.length === 1 && !meta && !event.altKey) {
    event.preventDefault();
    const result = gpui_app_demo_text(event.key);
    window.__gpuiLastTextResult = result;
    requestDraw();
    return;
  }
  if (["Enter", "Escape", "Backspace", "Delete", "ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Home", "End", "PageUp", "PageDown"].includes(event.key)) {
    event.preventDefault();
    gpui_app_demo_key(keyName(event), modifiers(event), event.repeat);
    requestDraw();
  }
}

let pointerDown = false;

canvas.addEventListener("pointermove", (event) => {
  const { x, y } = logicalPoint(event);
  gpui_app_demo_pointer_move(x, y);
  requestDraw();
});
canvas.addEventListener("pointerdown", (event) => {
  if (event.button !== 0) return;
  pointerDown = true;
  canvas.setPointerCapture(event.pointerId);
  canvas.focus();
  const { x, y } = logicalPoint(event);
  const result = gpui_app_demo_pointer_down(x, y);
  if (!ok(result)) fail(`pointer error: ${result}`);
  requestDraw();
});
canvas.addEventListener("pointerup", (event) => {
  if (event.button !== 0 || !pointerDown) return;
  pointerDown = false;
  const { x, y } = logicalPoint(event);
  const result = gpui_app_demo_pointer_up(x, y);
  if (!ok(result)) fail(`pointer error: ${result}`);
  requestDraw();
});
canvas.addEventListener("pointercancel", () => {
  pointerDown = false;
});
canvas.addEventListener("wheel", (event) => {
  event.preventDefault();
  const { x, y } = logicalPoint(event);
  gpui_app_demo_scroll(x, y, event.deltaX, event.deltaY);
  requestDraw();
}, { passive: false });
window.addEventListener("keydown", handleKeyDown);
window.addEventListener("resize", resize);

const observer = new ResizeObserver(resize);
observer.observe(canvas);

window.__gpuiDemo = {
  scene: () => gpui_app_demo_scene(),
  state: () => gpui_app_demo_state(),
  text: (value) => gpui_app_demo_text(value),
  key: (key, modifiers = "", repeat = false) => gpui_app_demo_key(key, modifiers, repeat),
  draw: () => draw(),
};

const started = gpui_app_demo_start();
if (!ok(started)) {
  fail(`startup error: ${started}`);
} else {
  resize();
  canvas.focus();
}
