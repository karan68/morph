/* Morph UI helpers shared by mockups and the clickable prototype. */
(function () {
  const NS = "http://www.w3.org/2000/svg";
  const I = window.ICONS || {};

  const icon = (name, size = 16, extra = "") =>
    `<svg ${extra} width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${I[name] || ""}</svg>`;

  const CATEGORY = (f) => {
    f = (f || "").toLowerCase();
    if (["jpg", "jpeg", "png", "webp", "heic", "tiff", "svg", "avif", "bmp"].includes(f)) return "image";
    if (["mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "wma"].includes(f)) return "audio";
    if (["mp4", "mov", "mkv", "webm", "avi", "wmv", "gif"].includes(f)) return "video";
    if (f === "pdf") return "pdf";
    if (["ppt", "pptx", "key"].includes(f)) return "slides";
    if (["xlsx", "xls", "ods", "csv", "tsv"].includes(f)) return "sheet";
    if (["srt", "vtt"].includes(f)) return "subtitle";
    if (["zip", "tar", "gz", "rar"].includes(f)) return "archive";
    if (f === "folder") return "folder";
    return "doc";
  };
  const COLORS = { image: "#2f8f6a", audio: "#b8367f", video: "#d6403f", pdf: "#c8372b", slides: "#d0661b", sheet: "#1e8a4f", subtitle: "#5b47f5", archive: "#7a6650", doc: "#2f63d6" };
  const GLYPH = { image: "image", audio: "music", video: "film", pdf: "fileText", slides: "createCollage", sheet: "organizePDF", subtitle: "fileText", archive: "archive", doc: "fileText" };
  const label = (f) => (f === "gz" ? "GZIP" : f === "textClipping" ? "CLIP" : String(f).toUpperCase());

  function fileIcon(fmt, { photo = null, size = 1 } = {}) {
    const cat = CATEGORY(fmt);
    const scale = size !== 1 ? ` style="transform:scale(${size});transform-origin:top center"` : "";
    if (cat === "folder") return `<div class="fileicon folder"${scale}><div class="sheet"></div></div>`;
    if (photo) return `<div class="fileicon photo"${scale}><div class="sheet ${photo}"></div><div class="band" style="background:rgba(0,0,0,.42)">${label(fmt)}</div></div>`;
    const g = I[GLYPH[cat]] ? GLYPH[cat] : "file";
    return `<div class="fileicon"${scale}><div class="sheet"><span class="glyph" style="color:${COLORS[cat]}">${icon(g, 26)}</span></div><div class="band" style="background:${COLORS[cat]}">${label(fmt)}</div></div>`;
  }

  function fileItem(name, fmt, { photo = null, selected = false, wall = false, dim = false, style = "" } = {}) {
    return `<div class="fileitem${selected ? " selected" : ""}${wall ? " on-wall" : ""}${dim ? " dim" : ""}" style="${style}">${fileIcon(fmt, { photo })}<div class="name">${name}</div></div>`;
  }

  const cursor = (x, y) =>
    `<svg class="cursor" style="left:${x}px;top:${y}px" viewBox="0 0 22 30"><path d="M2 2 L2 24 L7.5 18.8 L11.2 27.4 L15 25.8 L11.4 17.4 L19 17.4 Z" fill="#111" stroke="#fff" stroke-width="1.6" stroke-linejoin="round"/></svg>`;

  // Geometry: annular sector inset by corner radius, then stroked with round joins => rounded petals.
  const GEO = { size: 340, rOut: 160, rIn: 62, gap: 7, corner: 12, backdrop: 168 };
  const polar = (r, a) => [GEO.size / 2 + r * Math.cos(a), GEO.size / 2 + r * Math.sin(a)];
  const centerAngle = (i, n) => -Math.PI / 2 + (i * 2 * Math.PI) / n;
  function petalPath(i, n) {
    const ro = GEO.rOut - GEO.corner, ri = GEO.rIn + GEO.corner;
    if (n === 1) { // single target: full ring (evenodd hole)
      const m = GEO.size / 2, ring = (r) => `M${m - r} ${m} a${r} ${r} 0 1 0 ${2 * r} 0 a${r} ${r} 0 1 0 ${-2 * r} 0 Z`;
      return `${ring(ro)} ${ring(ri)}`;
    }
    const c = centerAngle(i, n);
    const half = (r) => Math.max(0.02, Math.PI / n - (GEO.gap / 2 + GEO.corner) / r);
    const [x1, y1] = polar(ro, c - half(ro)), [x2, y2] = polar(ro, c + half(ro));
    const [x3, y3] = polar(ri, c + half(ri)), [x4, y4] = polar(ri, c - half(ri));
    const big = 2 * half(ro) > Math.PI ? 1 : 0;
    return `M${x1.toFixed(2)} ${y1.toFixed(2)} A${ro} ${ro} 0 ${big} 1 ${x2.toFixed(2)} ${y2.toFixed(2)} L${x3.toFixed(2)} ${y3.toFixed(2)} A${ri} ${ri} 0 ${big} 0 ${x4.toFixed(2)} ${y4.toFixed(2)} Z`;
  }
  // Returns petal index for a point relative to wheel centre, or null.
  function hitTest(dx, dy, n) {
    const d = Math.hypot(dx, dy);
    if (!n || d < GEO.rIn || d > GEO.rOut + 4) return null;
    let a = Math.atan2(dy, dx) + Math.PI / 2;
    a = ((a % (2 * Math.PI)) + 2 * Math.PI) % (2 * Math.PI);
    const step = (2 * Math.PI) / n;
    return Math.round(a / step) % n;
  }

  /**
   * wheel({ mode: "conversions"|"tools"|"actions", targets: [...ids], highlighted, focused,
   *         center: {thumb, size, text}, legend: true, contrast: false, emptyText })
   */
  function wheelHTML(o) {
    const n = o.targets.length;
    const defs = { ...(window.MATRIX?.toolDefs || {}), ...(window.MATRIX?.actionDefs || {}) };
    const isTool = o.mode !== "conversions";
    const midR = (GEO.rIn + GEO.rOut) / 2 + 3;
    const dense = n > 7;
    let petals = "";
    o.targets.forEach((t, i) => {
      const [lx, ly] = polar(midR, centerAngle(i, n));
      const cls = ["target", i === o.highlighted ? "hl" : "", i === o.focused ? "focus" : ""].join(" ");
      const name = isTool ? (defs[t]?.name || t) : `Convert to ${label(t)}`;
      let inner = `<path class="petal" fill-rule="evenodd" d="${petalPath(i, n)}" stroke-width="${GEO.corner * 2}"/>`;
      if (o.contrast) inner += `<path class="outline" d="${petalPath(i, n)}"/>`;
      if (i === o.focused) inner += `<path class="focusring" d="${petalPath(i, n)}" stroke-linejoin="round"/>`;
      if (isTool) {
        const t2 = defs[t]?.title || t;
        inner += `<svg class="ico" x="${(lx - 10).toFixed(1)}" y="${(ly - 20).toFixed(1)}" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${I[t] || ""}</svg>`;
        inner += `<text class="lbl tool" x="${lx.toFixed(1)}" y="${(ly + 11).toFixed(1)}"${dense ? ' style="font-size:9.5px"' : ""}>${t2}</text>`;
      } else {
        inner += `<text class="lbl" x="${lx.toFixed(1)}" y="${ly.toFixed(1)}"${dense ? ' style="font-size:13.5px"' : ""}>${label(t)}</text>`;
      }
      petals += `<g class="${cls}" role="menuitem" aria-label="${name}" data-index="${i}" data-id="${t}">${inner}</g>`;
    });
    const s = GEO.size;
    const ring = `<svg class="ring" viewBox="0 0 ${s} ${s}" width="${s}" height="${s}" role="menu" aria-label="${o.mode === "actions" ? "Choose a file action" : isTool ? "Choose a file tool" : "Choose a conversion format"}"><circle class="backdrop" cx="${s / 2}" cy="${s / 2}" r="${GEO.backdrop}"/>${petals}</svg>`;
    let center = "";
    if (n) {
      const c = o.center || {};
      const hl = o.highlighted ?? o.focused;
      if (hl != null && hl >= 0) {
        const t = o.targets[hl];
        center = `<div class="center"><span class="big">${isTool ? (defs[t]?.title || t) : label(t)}</span></div>`;
      } else {
        center = `<div class="center">${c.thumb ? `<div class="thumb ${c.thumb}"></div>` : c.fmt ? `<div style="margin-top:-12px">${fileIcon(c.fmt, { size: 0.62 })}</div>` : ""}${c.text ? `<span class="chip">${c.text}</span>` : ""}</div>`;
      }
    }
    const empty = n ? "" : `<div class="empty glass">${o.emptyText || "Nothing here"}</div>`;
    const lg = o.legend === false ? "" :
      `<div class="legend glass">${[["conversions", "⇧", "Convert"], ["tools", "⌘", "Tools"], ["actions", "⌃", "Actions"]].map(([m, k, t]) => `<span class="${o.mode === m ? "on" : ""}"><span class="kbd">${k}</span>${t}</span>`).join("")}</div>`;
    return `<div class="wheel${o.contrast ? " contrast" : ""}" style="left:${o.x}px;top:${o.y}px">${n ? ring : ""}${center}${empty}${lg}</div>`;
  }

  window.MorphUI = { icon, fileIcon, fileItem, cursor, wheelHTML, hitTest, GEO, label, CATEGORY };
})();
