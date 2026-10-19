#!/usr/bin/env node
// Renders UI assets with headless Chrome (playwright-core) — run once by a developer, outputs are committed:
//   Resources/icons/<id>.png   64×64 black template icons from Lucide (ISC), same mapping as the spec mockups
//   Resources/AppIcon.iconset  Morph logo app icon (original design), → AppIcon.icns via `iconutil` in make-app-bundle.sh
//   Resources/logo-menubar.png menu-bar logo (colour, 36×36 for @2x)
// usage: NODE_PATH=<dir with lucide-static, playwright-core> node scripts/gen-assets.mjs
import fs from "fs";
import path from "path";
import { createRequire } from "module";
const require = createRequire(import.meta.url);
const { chromium } = require("playwright-core");
const lucideDir = path.dirname(require.resolve("lucide-static/package.json")) + "/icons";
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");

// Same tool/action → Lucide mapping as docs/spec/mockups/src/icons.js
const MAP = {
  compress: "minimize-2", removeMetadata: "tag", editImage: "sliders-horizontal", annotateImage: "pen-line", frameImage: "frame",
  cropImage: "crop", cropVideo: "crop", redactImage: "eye-off", redactVideo: "eye-off", normalizeAudio: "audio-waveform",
  muteVideo: "volume-x", trimVideo: "scissors", trimAudio: "scissors", splitPDF: "columns-2", organizePDF: "layout-grid",
  extractArchive: "package-open", createPDF: "file-plus", mergePDF: "files", changeVideoSpeed: "gauge", joinVideos: "film",
  videoSnapshots: "camera", splitVideo: "split", audioToVideo: "audio-lines", audioChannels: "speaker", createCollage: "layout-dashboard",
  redactAudio: "mic-off", airDrop: "send", float: "pin", copy: "copy", move: "folder-input", copyPath: "clipboard-copy",
  openTerminal: "square-terminal", x: "x", play: "play", pause: "pause", check: "check", alert: "triangle-alert", shield: "shield-check",
  keyboard: "keyboard", settings: "settings", search: "search", folder: "folder", file: "file", chevron: "chevron-down",
  stepBack: "step-back", stepFwd: "step-forward", image: "image", music: "music", fileText: "file-text", archive: "archive",
  accessibility: "accessibility", info: "info", reveal: "external-link",
};

const LOGO = (size, bg) => `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#8f7dff"/><stop offset="1" stop-color="#2fd1c4"/></linearGradient>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#ecebf7"/></linearGradient>
  </defs>
  ${bg ? '<rect x="100" y="100" width="824" height="824" rx="185" fill="url(#bg)"/><rect x="100.5" y="100.5" width="823" height="823" rx="185" fill="none" stroke="#1c1b22" stroke-opacity=".08"/>' : ""}
  <g transform="translate(512 512) scale(${bg ? 24 : 42})"><g transform="translate(-12 -12)">
    <circle cx="12" cy="12" r="8.2" fill="none" stroke="url(#g)" stroke-width="4.2" stroke-dasharray="8.2 2.6"/>
    <circle cx="12" cy="12" r="2.6" fill="url(#g)"/>
  </g></g></svg>`;

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1100, height: 1100 } });
async function render(svg, w, h, out) {
  await page.setContent(`<html><head><style>html,body{margin:0;background:transparent}svg{display:block}</style></head><body>${svg}</body></html>`);
  await page.screenshot({ path: out, omitBackground: true, clip: { x: 0, y: 0, width: w, height: h } });
}

fs.mkdirSync(path.join(root, "Resources/icons"), { recursive: true });
for (const [id, name] of Object.entries(MAP)) {
  const raw = fs.readFileSync(path.join(lucideDir, `${name}.svg`), "utf8").replace(/<!--[\s\S]*?-->/g, "");
  const inner = raw.match(/<svg[^>]*>([\s\S]*)<\/svg>/)[1];
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${inner}</svg>`;
  await render(svg, 64, 64, path.join(root, `Resources/icons/${id}.png`));
}
const iconset = path.join(root, "Resources/AppIcon.iconset");
fs.mkdirSync(iconset, { recursive: true });
for (const [n, px] of [["16x16", 16], ["16x16@2x", 32], ["32x32", 32], ["32x32@2x", 64], ["128x128", 128], ["128x128@2x", 256],
                       ["256x256", 256], ["256x256@2x", 512], ["512x512", 512], ["512x512@2x", 1024]]) {
  await render(LOGO(px, true), px, px, path.join(iconset, `icon_${n}.png`));
}
await render(LOGO(36, false), 36, 36, path.join(root, "Resources/logo-menubar.png"));
await render(LOGO(256, false), 256, 256, path.join(root, "Resources/logo.png"));
await browser.close();
console.log(`icons: ${Object.keys(MAP).length}, app icon + logos written`);
