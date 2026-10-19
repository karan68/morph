#!/usr/bin/env python3
"""Independent conversion verifier — proves Morph's conversions are real, not renames.

Runs on Linux with tools that were NOT used to produce the files (Ubuntu's own FFmpeg 6.1, libmagic, Pillow,
libheif, librsvg, poppler, Ubuntu's bsdtar, Python zipfile/tarfile). Shares no code with Morph.

For every conversion produced by the macOS golden matrix (results.json from scripts/run-matrix.py):
  1. SIGNATURE   magic bytes identify the target format (own table below; libmagic recorded as a 2nd opinion)
  2. NOT RENAME  the content-detected format of the output differs from the input's, and the bytes differ
  3. DECODE      the whole output decodes without errors
  4. FIDELITY    the decoded content matches the source (image PSNR, audio pitch + duration, video frame PSNR +
                 duration + soundtrack pitch, subtitle cues, archive members + file hashes)
  5. CONTROL     a fake made by RENAMING the input to the target extension must FAIL checks 1–4 (proves the
                 verifier can't be fooled by a rename)

usage: verify-conversions.py <run-dir-with-results.json> <out-dir>
"""
import hashlib, io, json, os, re, shutil, subprocess, sys, tarfile, tempfile, zipfile
import numpy as np
from PIL import Image

RUN, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
TMP = tempfile.mkdtemp(prefix="verify-")
HEIF_DEC = shutil.which("heif-dec") or shutil.which("heif-convert") or "heif-dec"   # name differs by libheif version

def sh(cmd, timeout=180, binary=False):
    p = subprocess.run(cmd, capture_output=True, timeout=timeout, text=not binary)
    return p.returncode, p.stdout, p.stderr

def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""): h.update(b)
    return h.hexdigest()

# ---------------------------------------------------------------------------------------------------------
# 1. Content-based format detection from magic bytes (independent of the file name)
# ---------------------------------------------------------------------------------------------------------
def sniff(path):
    with open(path, "rb") as f: b = f.read(4096)
    if b[:3] == b"\xff\xd8\xff": return "jpg"
    if b[:8] == b"\x89PNG\r\n\x1a\n": return "png"
    if b[:4] == b"RIFF" and b[8:12] == b"WEBP": return "webp"
    if b[:4] == b"RIFF" and b[8:12] == b"WAVE": return "wav"
    if b[:4] == b"RIFF" and b[8:12] == b"AVI ": return "avi"
    if b[:4] in (b"II*\x00", b"MM\x00*"): return "tiff"
    if b[:2] == b"BM": return "bmp"
    if b[:5] == b"%PDF-": return "pdf"
    if b[:6] in (b"GIF87a", b"GIF89a"): return "gif"
    if b[:4] == b"fLaC": return "flac"
    if b[:4] == b"FORM" and b[8:12] in (b"AIFF", b"AIFC"): return "aiff"
    if b[:4] == b"OggS":
        if b"OpusHead" in b[:200]: return "opus"
        if b"\x01vorbis" in b[:200]: return "ogg"
        return "ogg?"
    if b[:16] == bytes.fromhex("3026b2758e66cf11a6d900aa0062ce6c"): return "asf"   # WMA / WMV container
    if b[:4] == b"\x1a\x45\xdf\xa3":
        return "webm" if b"webm" in b[:64] else "mkv" if b"matroska" in b[:64] else "ebml?"
    if b[4:8] == b"ftyp":
        brand = b[8:12]
        compat = [b[i:i + 4] for i in range(16, min(len(b), 8 + int.from_bytes(b[0:4], "big")), 4)]
        if brand in (b"heic", b"heix", b"heim", b"heis", b"hevc", b"hevx") : return "heic"
        if brand in (b"avif", b"avis"): return "avif"
        if brand == b"mif1": return "avif" if b"avif" in compat else "heic" if b"heic" in compat else "heif?"
        if brand == b"qt  ": return "mov"
        if brand in (b"M4A ", b"M4B "): return "m4a"
        return "mp4"
    if b[:3] == b"ID3" or (len(b) > 1 and b[0] == 0xFF and (b[1] & 0xE0) == 0xE0): return "mp3"
    if b[:4] == b"PK\x03\x04": return "zip"
    if b[:2] == b"\x1f\x8b": return "gz"
    if len(b) > 262 and b[257:262] == b"ustar": return "tar"
    if b[:4] == b"Rar!": return "rar"
    t = b.decode("utf-8", "replace").lstrip("\ufeff").lstrip()
    if t.startswith("<svg") or "<svg" in t[:300]: return "svg"
    if t.startswith("WEBVTT"): return "vtt"
    if re.match(r"\d+\s*\r?\n\d\d:\d\d:\d\d,\d{3} --> ", t): return "srt"
    return "txt"

# What the target extension must sniff as. mp4/m4a outputs from different muxers are all ISO-BMFF "ftyp";
# m4a may legitimately carry an mp4-family brand, so stream checks below decide audio-only vs video.
ACCEPT = {
    "jpg": {"jpg"}, "png": {"png"}, "webp": {"webp"}, "heic": {"heic"}, "avif": {"avif"}, "tiff": {"tiff"},
    "bmp": {"bmp"}, "pdf": {"pdf"}, "gif": {"gif"}, "mp3": {"mp3"}, "m4a": {"m4a", "mp4"}, "wav": {"wav"},
    "flac": {"flac"}, "ogg": {"ogg"}, "opus": {"opus"}, "aiff": {"aiff"}, "wma": {"asf"}, "mp4": {"mp4"},
    "mov": {"mov"}, "mkv": {"mkv"}, "webm": {"webm"}, "avi": {"avi"}, "wmv": {"asf"}, "srt": {"srt"},
    "vtt": {"vtt"}, "txt": {"txt"}, "zip": {"zip"}, "tar": {"tar"}, "gz": {"gz"},
}

def libmagic(path):
    rc, so, _ = sh(["file", "-b", "--mime-type", path])
    return so.strip() if rc == 0 else "?"

# ---------------------------------------------------------------------------------------------------------
# 3/4. Independent decoders
# ---------------------------------------------------------------------------------------------------------
def to_rgb_on_white(im):
    im = im.convert("RGBA")
    bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
    return np.asarray(Image.alpha_composite(bg, im).convert("RGB"), dtype=np.float64)

def decode_image(path, fmt):
    """Decode the FULL image with an independent decoder chosen by the sniffed format."""
    if fmt in ("heic", "avif"):
        png = os.path.join(TMP, os.path.basename(path) + ".dec.png")
        rc, _, se = sh([HEIF_DEC, path, png])
        if rc != 0 or not os.path.exists(png): raise RuntimeError(os.path.basename(HEIF_DEC) + ": " + se.strip()[-200:])
        path = png
    elif fmt == "svg":
        png = os.path.join(TMP, os.path.basename(path) + ".dec.png")
        rc, _, se = sh(["rsvg-convert", "-o", png, path])
        if rc != 0: raise RuntimeError("rsvg-convert: " + se.strip()[-200:])
        path = png
    elif fmt == "pdf":
        # The page must render (full decode), and the content compared is the image embedded in the page:
        # rendering applies the PDF's /Interpolate smoothing, which would measure the renderer, not the file.
        rc, so, se = sh(["pdfinfo", path])
        pages = int(re.search(r"Pages:\s+(\d+)", so).group(1)) if rc == 0 else 0
        if pages != 1: raise RuntimeError(f"pdfinfo pages={pages} {se.strip()[-120:]}")
        size = re.search(r"Page size:\s+([\d.]+) x ([\d.]+) pts", so)
        base = os.path.join(TMP, os.path.basename(path) + ".dec")
        rc, _, se = sh(["pdftoppm", "-r", "72", "-png", "-singlefile", path, base])
        if rc != 0: raise RuntimeError("pdftoppm: " + se.strip()[-200:])
        d = tempfile.mkdtemp(dir=TMP)   # fresh dir per PDF
        rc, lst, _ = sh(["pdfimages", "-list", path])
        types = [l.split()[2] for l in lst.splitlines()[2:] if l.strip()]
        rc2, _, se = sh(["pdfimages", "-png", path, os.path.join(d, "img")])
        files = sorted(os.listdir(d))
        if rc != 0 or rc2 != 0 or types.count("image") != 1 or len(files) != len(types):
            raise RuntimeError(f"pdfimages: types={types} files={files}")
        im = Image.open(os.path.join(d, files[types.index("image")])).convert("RGB"); im.load()
        if "smask" in types:   # transparency stored as a soft mask → apply as alpha
            mask = Image.open(os.path.join(d, files[types.index("smask")])).convert("L")
            im = im.convert("RGBA"); im.putalpha(mask.resize(im.size))
        if size and (round(float(size.group(1))), round(float(size.group(2)))) != im.size:
            raise RuntimeError(f"page {size.group(1)}x{size.group(2)} pt != image {im.size}")
        return to_rgb_on_white(im)
    im = Image.open(path)
    im.load()  # forces a full decode; raises on truncated/corrupt data
    try:
        from PIL import ImageOps
        im = ImageOps.exif_transpose(im)
    except Exception:
        pass
    return to_rgb_on_white(im)

def psnr(a, b):
    if a.shape != b.shape:
        b = np.asarray(Image.fromarray(b.astype(np.uint8)).resize((a.shape[1], a.shape[0]), Image.LANCZOS), dtype=np.float64)
    mse = np.mean((a - b) ** 2)
    return 99.0 if mse == 0 else 10 * np.log10(255.0 ** 2 / mse)

def ffprobe(path):
    rc, so, se = sh(["ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", path])
    if rc != 0: raise RuntimeError("ffprobe: " + se.strip()[-200:])
    return json.loads(so)

def full_decode_errors(path):
    rc, _, se = sh(["ffmpeg", "-hide_banner", "-nostdin", "-v", "error", "-i", path, "-f", "null", "-"], timeout=300)
    errs = [l for l in se.splitlines() if l.strip()]
    return (rc != 0), errs

def audio_signal(path, rate=16000):
    rc, so, se = sh(["ffmpeg", "-hide_banner", "-nostdin", "-v", "error", "-i", path, "-vn", "-ac", "1", "-ar", str(rate),
                     "-f", "s16le", "-"], binary=True)
    if rc != 0: raise RuntimeError("audio decode failed: " + se.decode("utf-8", "replace").strip()[-200:])
    return np.frombuffer(so, dtype=np.int16).astype(np.float64), rate

def dominant_hz(sig, rate):
    n = len(sig)
    seg = sig[n // 4: n // 4 + rate] if n > rate * 2 else sig
    if len(seg) < 1000: return 0.0
    spec = np.abs(np.fft.rfft(seg * np.hanning(len(seg))))
    return float(np.fft.rfftfreq(len(seg), 1 / rate)[int(np.argmax(spec[1:])) + 1])

def video_frame(path, t):
    rc, so, se = sh(["ffmpeg", "-hide_banner", "-nostdin", "-v", "error", "-i", path, "-ss", f"{t:.3f}", "-frames:v", "1",
                     "-f", "image2pipe", "-c:v", "png", "-"], binary=True)
    if rc != 0 or not so: raise RuntimeError("frame decode failed: " + se.decode("utf-8", "replace").strip()[-200:])
    return to_rgb_on_white(Image.open(io.BytesIO(so)))

def luma(a): return 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]

def luma_frames(path, fps, w, h, n=90):
    vf = (f"fps={fps}," if fps else "") + f"scale={w}:{h}"
    rc, so, se = sh(["ffmpeg", "-hide_banner", "-nostdin", "-v", "error", "-i", path, "-an", "-vf", vf, "-frames:v", str(n),
                     "-pix_fmt", "gray", "-f", "rawvideo", "-"], binary=True)
    if rc != 0 or not so: raise RuntimeError("frame decode failed: " + se.decode("utf-8", "replace").strip()[-200:])
    return np.frombuffer(so, dtype=np.uint8).astype(np.float64).reshape(-1, h, w)

def best_aligned(S, O, window):
    best = (0.0, 0)
    for k in range(-window, window + 1):
        pairs = [(i, i + k) for i in range(2, min(len(O), len(S)) - 2) if 0 <= i + k < len(S)]
        if not pairs: continue
        v = float(np.mean([psnr(S[j], O[i]) for i, j in pairs]))
        best = max(best, (v, k))
    return best

def parse_subs(path):
    t = open(path, encoding="utf-8", errors="replace").read().replace("\r\n", "\n").lstrip("\ufeff")
    cues = []
    for block in re.split(r"\n\s*\n", t):
        m = re.search(r"(\d*:?\d\d:\d\d[.,]\d{3})\s*-->\s*(\d*:?\d\d:\d\d[.,]\d{3})", block)
        if not m: continue
        def secs(x):
            p = x.replace(",", ".").split(":"); p = [float(v) for v in p]
            return p[0] * 3600 + p[1] * 60 + p[2] if len(p) == 3 else p[0] * 60 + p[1]
        text = block[m.end():].split("\n", 1)[1] if "\n" in block[m.end():] else ""
        cues.append((round(secs(m.group(1)), 3), round(secs(m.group(2)), 3), text.strip()))
    return cues

def strip_tags(s): return re.sub(r"\{\\[^}]*\}", "", re.sub(r"<[^>]+>", "", s)).strip()

def archive_members(path, fmt):
    """name → sha256 of regular files, read with Python's stdlib (zip/tar/gz) or Ubuntu's bsdtar (rar)."""
    out = {}
    if fmt == "zip":
        with zipfile.ZipFile(path) as z:
            bad = z.testzip()
            if bad: raise RuntimeError(f"CRC error in {bad}")
            for i in z.infolist():
                if i.is_dir(): continue
                name = i.filename.lstrip("./")
                if (i.external_attr >> 16) & 0o170000 == 0o120000:      # symlink entry
                    out[name] = "symlink→" + z.read(i).decode("utf-8", "replace")
                else:
                    out[name] = hashlib.sha256(z.read(i)).hexdigest()
    elif fmt in ("tar", "gz"):
        with tarfile.open(path, "r:gz" if fmt == "gz" else "r:") as t:
            for m in t.getmembers():
                name = m.name.lstrip("./")
                if m.issym(): out[name] = "symlink→" + m.linkname
                elif m.isfile(): out[name] = hashlib.sha256(t.extractfile(m).read()).hexdigest()
    else:
        d = tempfile.mkdtemp(dir=TMP)
        rc, _, se = sh(["bsdtar", "-x", "-f", path, "-C", d])
        if rc != 0: raise RuntimeError("bsdtar: " + se.strip()[-200:])
        for root, _, files in os.walk(d):
            for f in files:
                p = os.path.join(root, f)
                if os.path.islink(p): out[os.path.relpath(p, d)] = "symlink→" + os.readlink(p)
                elif os.path.isfile(p): out[os.path.relpath(p, d)] = sha(p)
    return out

IMAGE = {"jpg", "png", "webp", "heic", "avif", "tiff", "bmp", "svg", "pdf"}
AUDIO = {"mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "wma"}
VIDEO = {"mp4", "mov", "mkv", "webm", "avi", "wmv", "gif"}
SUBS = {"srt", "vtt", "txt"}
ARCH = {"zip", "tar", "gz", "rar"}

# ---------------------------------------------------------------------------------------------------------
# One verification
# ---------------------------------------------------------------------------------------------------------
def verify(inp, outp, in_fmt, target):
    """Returns dict with per-check results. ok == all checks passed."""
    r = {"signature": False, "notRename": False, "decode": False, "fidelity": False, "metric": "", "notes": []}
    got, src_kind = sniff(outp), sniff(inp)
    r["sniffed"], r["inputSniffed"], r["libmagic"] = got, src_kind, libmagic(outp)
    r["signature"] = got in ACCEPT[target]
    r["notRename"] = (got != src_kind) and sha(inp) != sha(outp)
    if not r["signature"]:
        r["notes"].append(f"bytes say {got}, expected {target}")
        return finish(r)
    try:
        if target in IMAGE:
            o = decode_image(outp, got)
            i = decode_image(inp, src_kind)
            r["decode"] = True
            # Luma PSNR: chroma subsampling (4:2:0 in JPEG/HEIC/AVIF/WebP) dominates RGB PSNR on the saturated
            # synthetic test pattern even for a lossless output, so brightness detail is the fair signal.
            # Mean colour per channel catches colour shifts that luma alone would miss.
            py = psnr(luma(i), luma(o)) if i.shape == o.shape else 0.0
            dc = float(np.max(np.abs(i.mean((0, 1)) - o.mean((0, 1))))) if i.shape == o.shape else 255.0
            th = 25 if in_fmt == "svg" else 35   # svg: two different renderers (WebKit vs librsvg) anti-alias differently
            r["fidelity"] = i.shape[:2] == o.shape[:2] and py >= th and dc <= 4
            r["metric"] = f"{o.shape[1]}x{o.shape[0]} · luma PSNR {py:.1f} dB (≥{th}) · mean colour Δ {dc:.1f} (≤4)"
        elif target in AUDIO or (target == "mp3" and in_fmt in VIDEO):
            failed, errs = full_decode_errors(outp)
            info = ffprobe(outp)
            streams = [s["codec_type"] for s in info["streams"]]
            r["decode"] = not failed and not errs and "audio" in streams and "video" not in streams
            if errs: r["notes"].append(errs[0][:120])
            so, ro = audio_signal(outp); si, ri = audio_signal(inp)
            fo, fi = dominant_hz(so, ro), dominant_hz(si, ri)
            do, di = len(so) / ro, len(si) / ri
            r["fidelity"] = abs(fo - fi) <= 5 and abs(do - di) <= 0.15 and np.sqrt(np.mean(so ** 2)) > 100
            r["metric"] = f"{info['streams'][0]['codec_name']} · tone {fo:.0f} Hz (src {fi:.0f}) · {do:.2f}s (src {di:.2f}s)"
        elif target in VIDEO:
            failed, errs = full_decode_errors(outp)
            info = ffprobe(outp)
            v = next((s for s in info["streams"] if s["codec_type"] == "video"), None)
            r["decode"] = not failed and not errs and v is not None
            if errs: r["notes"].append(errs[0][:120])
            si = ffprobe(inp)
            do, di = float(info["format"].get("duration", 0)), float(si["format"].get("duration", 0))
            sv = next(s_ for s_ in si["streams"] if s_["codec_type"] == "video")
            gif = "gif" in (in_fmt, target)
            # Compare every frame (luma), both sides resampled to the same rate when GIF (12 fps) is involved,
            # searching a ±3-frame start offset (decoders differ by a frame at the start).
            fps = 12 if target == "gif" else 10 if in_fmt == "gif" else None
            w, h = int(v["width"]), int(v["height"])
            dims_ok = (w, h) == (int(sv["width"]), int(sv["height"])) or target == "gif"
            O, S = luma_frames(outp, fps, w, h), luma_frames(inp, fps, w, h)
            p, k = best_aligned(S, O, 3)
            th, dt = (25, 0.6) if gif else (35, 0.35)
            ok = dims_ok and p >= th and abs(do - di) <= dt
            msg = (f"{v['codec_name'] if v else '?'} {w}x{h} · {len(O)} frames, mean luma PSNR {p:.1f} dB (≥{th}, offset {k:+d}) · "
                   f"{do:.2f}s (src {di:.2f}s)")
            has_a_in = any(s["codec_type"] == "audio" for s in si["streams"])
            if target != "gif" and has_a_in:
                so, ro = audio_signal(outp); sa, ra = audio_signal(inp)
                fo2, fi2 = dominant_hz(so, ro), dominant_hz(sa, ra)
                ok = ok and abs(fo2 - fi2) <= 5
                msg += f" · tone {fo2:.0f} Hz (src {fi2:.0f})"
            r["fidelity"], r["metric"] = ok, msg
        elif target in SUBS:
            ci, co = parse_subs(inp), parse_subs(outp)
            r["decode"] = len(ci) > 0
            if target == "txt":
                lines = [l.strip() for l in open(outp, encoding="utf-8").read().splitlines() if l.strip()]
                want = [l for c in ci for l in strip_tags(c[2]).splitlines() if l.strip()]
                r["fidelity"] = lines == want and not co
                r["metric"] = f"{len(lines)} text lines = cue text, no timestamps"
            else:
                r["fidelity"] = len(co) == len(ci) and all(a[:2] == b[:2] and a[2] == b[2] for a, b in zip(ci, co))
                r["metric"] = f"{len(co)} cues, identical timings + text"
        elif target in ARCH:
            mo = archive_members(outp, got)
            mi = archive_members(inp, src_kind)
            r["decode"] = len(mo) > 0
            r["fidelity"] = mo == mi
            r["metric"] = (f"{len(mo)} entries, names + SHA-256 (and symlink targets) identical to source" if r["fidelity"]
                           else f"MISMATCH out={sorted(mo)} src={sorted(mi)}")
    except Exception as e:
        r["notes"].append(f"{type(e).__name__}: {str(e)[:160]}")
    return finish(r)

def finish(r):
    r["ok"] = r["signature"] and r["notRename"] and r["decode"] and r["fidelity"]
    return r

# ---------------------------------------------------------------------------------------------------------
results = json.load(open(os.path.join(RUN, "results.json")))
convs = [x for x in results if x["group"] == "convert" and x.get("outputs")]
rows, controls = [], []
for c in convs:
    inp, outp, target = os.path.join(RUN, c["inputs"][0]), os.path.join(RUN, c["outputs"][0]), c["target"]
    in_fmt = c["name"].split("→")[0]
    r = verify(inp, outp, in_fmt, target)
    r.update(path=c["name"], output=os.path.basename(outp))
    rows.append(r)
    print(("PASS " if r["ok"] else "FAIL ") + f"{c['name']:12} {r['sniffed']:5} {r['libmagic']:24} {r['metric'][:90]} {' '.join(r['notes'])[:80]}", flush=True)
    # 5. Negative control: the input merely renamed to the target extension must be rejected.
    fake = os.path.join(TMP, "renamed-" + os.path.basename(outp))
    shutil.copyfile(inp, fake)
    fr = verify(inp, fake, in_fmt, target)
    controls.append({"path": c["name"], "caught": not fr["ok"], "why": "signature" if not fr["signature"] else "not-rename" if not fr["notRename"] else "decode/fidelity"})

passed = sum(r["ok"] for r in rows)
caught = sum(x["caught"] for x in controls)
ver = lambda cmd: (sh(cmd)[1] or "").splitlines()[0][:80] if sh(cmd)[0] == 0 else "?"
lines = [
    "# Independent conversion verification",
    "",
    "Verified on Linux with tools that did **not** produce the files: "
    f"{ver(['ffmpeg', '-version'])}; {ver(['file', '--version'])}; Pillow {Image.__version__}; "
    f"libheif {ver([HEIF_DEC, '--version'])}; {ver(['rsvg-convert', '--version'])}; poppler pdftoppm; Ubuntu bsdtar; Python zipfile/tarfile.",
    "",
    f"- **Real conversions: {passed} / {len(rows)}** (signature ✓ · not a rename ✓ · full decode ✓ · content matches source ✓)",
    f"- **Rename controls caught: {caught} / {len(controls)}** — every input copied to the target extension (a fake “conversion”) was rejected",
    "",
    "| | Path | Bytes say | libmagic | Not rename | Decodes | Content check |",
    "|---|---|---|---|---|---|---|",
]
for r in rows:
    tick = lambda b: "✅" if b else "❌"
    lines.append(f"| {tick(r['ok'])} | {r['path']} | {r['sniffed']} (input: {r['inputSniffed']}) | {r['libmagic']} | {tick(r['notRename'])} | "
                 f"{tick(r['decode'])} | {(r['metric'] + ' ' + ' '.join(r['notes'])).strip()[:140].replace('|', '/')} |")
missed = [x["path"] for x in controls if not x["caught"]]
if missed: lines += ["", "**Rename controls NOT caught:** " + ", ".join(missed)]
open(os.path.join(OUT, "conversion-proof.md"), "w").write("\n".join(lines) + "\n")
json.dump({"rows": rows, "controls": controls}, open(os.path.join(OUT, "conversion-proof.json"), "w"), indent=2, default=str)
shutil.rmtree(TMP, ignore_errors=True)
print(f"\nREAL CONVERSIONS: {passed}/{len(rows)}   RENAME CONTROLS CAUGHT: {caught}/{len(controls)}")
sys.exit(0 if passed == len(rows) and caught == len(controls) and rows else 1)
