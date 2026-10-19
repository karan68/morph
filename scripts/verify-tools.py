#!/usr/bin/env python3
"""Independent verification of Morph's 7 M1 tools on real-world files — proves the results are real.

Runs on Linux with tools that did NOT produce the files: exiftool, Ubuntu's FFmpeg 6.1 (ffprobe + framemd5),
Pillow, libheif, poppler (pdfinfo/pdftotext/pdftoppm), Python zipfile/tarfile, Ubuntu bsdtar.

Per tool (what each claim means, and how it's checked):
  Compress        same format (WAV→FLAC allowed) · output really smaller · goal met (target size / percentage /
                  max dimension) · content still the same (image luma PSNR, PDF text + page render, audio
                  sample-exact for lossless or correlated for lossy, video frame PSNR + soundtrack) · metadata kept
                  unless “Keep … info” is off
  Metadata        the input really had GPS/camera/ID3/cover art/PDF Info, and the output has none (exiftool) ·
                  content untouched: pixel-identical (JPEG/PNG/WebP/GIF), packet-identical streams (audio/video,
                  FFmpeg framemd5), identical text + pages (PDF)
  Crop Image      exact output dimensions · pixels equal the requested region of the source
  Trim Video/Audio duration = end − start · content equals the source from `start` · “lossless” claims checked
                  by packet hashes (MP4/MOV/MKV stream copy, MP3/M4A) or exact samples (WAV/FLAC)
  Remove Audio    no audio stream · video packets byte-identical to the source (no re-encode)
  Extract         every file's name + SHA-256 equals an independent reader's · hostile "../" entry can't escape
CONTROL: for every case, a fake result (the input copied, or a tampered folder) must FAIL the same checks.

usage: verify-tools.py <run-dir with tool-cases.json> <out-dir>
"""
import hashlib, io, json, os, re, shutil, subprocess, sys, tarfile, tempfile, zipfile
import numpy as np
from PIL import Image, ImageOps

RUN, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
TMP = tempfile.mkdtemp(prefix="vtools-")
HEIF_DEC = shutil.which("heif-dec") or shutil.which("heif-convert") or "heif-dec"

def sh(cmd, timeout=300, binary=False):
    p = subprocess.run(cmd, capture_output=True, timeout=timeout, text=not binary)
    return p.returncode, p.stdout, p.stderr

def sha_file(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""): h.update(b)
    return h.hexdigest()

def sniff(path):
    with open(path, "rb") as f: b = f.read(64)
    if b[:3] == b"\xff\xd8\xff": return "jpg"
    if b[:8] == b"\x89PNG\r\n\x1a\n": return "png"
    if b[:4] == b"RIFF": return {b"WEBP": "webp", b"WAVE": "wav", b"AVI ": "avi"}.get(b[8:12], "riff?")
    if b[:4] in (b"II*\x00", b"MM\x00*"): return "tiff"
    if b[:5] == b"%PDF-": return "pdf"
    if b[:6] in (b"GIF87a", b"GIF89a"): return "gif"
    if b[:4] == b"fLaC": return "flac"
    if b[:4] == b"\x1a\x45\xdf\xa3": return "webm" if b"webm" in b[:64] else "mkv"
    if b[4:8] == b"ftyp":
        br = b[8:12]
        if br in (b"heic", b"heix", b"mif1"): return "heic"
        if br == b"qt  ": return "mov"
        if br in (b"M4A ", b"M4B "): return "m4a"
        return "mp4"
    if b[:3] == b"ID3" or (b[0] == 0xFF and (b[1] & 0xE0) == 0xE0): return "mp3"
    return "?"

# ---------- metadata (exiftool) ----------
DESC_TAGS = re.compile(r"^(GPS.*|Make|Model|SerialNumber|InternalSerialNumber|Lens(Model|ID|Make)?|DateTimeOriginal|CreateDate|"
                       r"Software|Artist|Copyright|UserComment|ImageDescription|Title|Author|Creator|Producer|Subject|Keywords|"
                       r"Comment|Album|AlbumArtist|Band|Genre|Year|Picture.*|CoverArt|Description|Encoder|EncodedBy|"
                       r"EncoderSettings|CreatorTool|MetadataDate|Location.*|Owner.*|CameraSerialNumber)$")
DESC_GROUP = re.compile(r"^(GPS|XMP.*|IPTC|MakerNotes|Panasonic|ID3.*|Vorbis|ItemList|UserData|Keys)$")
# Structural / generic entries that aren't about a person, place, device or content.
NOT_PERSONAL = re.compile(r"^(Vendor|Format|PDFVersion|Linearized|PageCount|TaggedPDF|ImageWidth|ImageHeight|.*Flags|VP8Version|"
                          r"HorizontalScale|VerticalScale|XMPToolkit)$")
ZERO_DATE = re.compile(r"^0000[:\-]00[:\-]00")
STRUCTURAL = re.compile(r"^(File|System|Composite|ExifTool|ICC.*|JFIF|PNG|PNG-pHYs|Matroska|QuickTime|Track\d*|Video|Audio|MPEG|FLAC|RIFF-fmt)$")

def exif(path):
    rc, so, se = sh(["exiftool", "-j", "-a", "-G1", "-n", "-api", "LargeFileSupport=1", path])
    return json.loads(so)[0] if rc == 0 and so.strip() else {}

def descriptive(meta):
    """Tags that identify a person, place, device, time or content (what “Remove All” must remove)."""
    out = {}
    for k, v in meta.items():
        if ":" not in k or v in ("", None): continue
        g, t = k.split(":", 1)
        if STRUCTURAL.match(g) and not DESC_TAGS.match(t): continue
        if NOT_PERSONAL.match(t) or ZERO_DATE.match(str(v)): continue
        if DESC_GROUP.match(g) or DESC_TAGS.match(t): out[k] = str(v)[:60]
    return out

ALWAYS_PERSONAL = re.compile(r"^(GPS.*|Make|Model|SerialNumber|InternalSerialNumber|CameraSerialNumber|Lens(Model|ID|Make)?|Owner.*|"
                             r"Artist|Author|Creator|Title|Comment|Album|AlbumArtist|Description|ImageDescription|UserComment|Picture.*|CoverArt)$")

def left_from_original(mi, mo):
    """Descriptive tags in the output that came from the original (same value) or are always personal.
    Anything else (e.g. a new Producer/creation date written by macOS's PDF writer) is reported separately."""
    vals = {str(v).strip() for v in mi.values() if len(str(v).strip()) >= 3}
    from_orig, added = {}, {}
    for k, v in descriptive(mo).items():
        t = k.split(":", 1)[-1]
        if str(v).strip() in vals or ALWAYS_PERSONAL.match(t): from_orig[k] = v
        else: added[k] = v
    return from_orig, added

def has_gps(meta): return any(k.split(":", 1)[-1].startswith("GPSLatitude") for k in meta)

# ---------- images ----------
def decode_image(path, orient=True):
    fmt = sniff(path)
    if fmt == "heic":
        png = os.path.join(TMP, hashlib.md5(path.encode()).hexdigest() + ".png")
        rc, _, se = sh([HEIF_DEC, path, png])
        if rc != 0: raise RuntimeError("heif decode: " + se[-200:])
        path = png
    im = Image.open(path); im.load()
    if orient: im = ImageOps.exif_transpose(im)
    im = im.convert("RGBA")
    bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
    return np.asarray(Image.alpha_composite(bg, im).convert("RGB"), dtype=np.float64)

def luma(a): return 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]

def psnr(a, b):
    m = np.mean((a - b) ** 2)
    return 99.0 if m == 0 else float(10 * np.log10(255.0 ** 2 / m))

def resized(a, w, h):
    return np.asarray(Image.fromarray(a.astype(np.uint8)).resize((w, h), Image.LANCZOS), dtype=np.float64)

# ---------- audio / video ----------
def probe(path):
    rc, so, se = sh(["ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", path])
    if rc != 0: raise RuntimeError("ffprobe: " + se[-200:])
    return json.loads(so)

def streams(info, kind, real_only=True):
    return [s for s in info["streams"] if s["codec_type"] == kind and not (real_only and s.get("disposition", {}).get("attached_pic"))]

def duration(path):
    return float(probe(path)["format"].get("duration", 0))

def packet_hashes(path, sel):
    """MD5 of every packet of the selected stream(s), read without decoding (stream copy)."""
    rc, so, se = sh(["ffmpeg", "-hide_banner", "-nostdin", "-v", "error", "-i", path, "-map", sel, "-c", "copy", "-f", "framemd5", "-"])
    if rc != 0: return []
    return [l.split(",")[-1].strip() for l in so.splitlines() if l and not l.startswith("#")]

def pcm(path, rate=None, mono=False, fmt="s32le"):
    cmd = ["ffmpeg", "-hide_banner", "-nostdin", "-v", "error", "-i", path, "-vn"]
    if mono: cmd += ["-ac", "1"]
    if rate: cmd += ["-ar", str(rate)]
    rc, so, se = sh(cmd + ["-f", fmt, "-"], binary=True)
    if rc != 0: raise RuntimeError("audio decode: " + se.decode("utf-8", "replace")[-200:])
    return np.frombuffer(so, dtype=np.int32 if fmt == "s32le" else np.int16).astype(np.float64)

def correlation(a, b):
    """Best normalised cross-correlation within ±0.25 s (signals at 8 kHz)."""
    n = min(len(a), len(b))
    if n < 8000: return 0.0
    best = 0.0
    for lag in range(-2000, 2001, 20):
        x = a[max(0, lag):n + min(0, lag)]; y = b[max(0, -lag):n - max(0, lag)]
        m = min(len(x), len(y)); x, y = x[:m], y[:m]
        d = np.linalg.norm(x) * np.linalg.norm(y)
        if d > 0: best = max(best, float(np.dot(x, y) / d))
    return best

def envelope(sig, rate=8000, win=0.02):
    n = int(rate * win)
    m = len(sig) // n
    return np.sqrt(np.mean(sig[:m * n].reshape(m, n) ** 2, axis=1))

def envelope_corr(a, b):
    """Correlation of 20 ms loudness contours (robust to the phase changes lossy codecs make)."""
    ea, eb = envelope(a), envelope(b)
    best = 0.0
    for lag in range(-15, 16):
        x = ea[max(0, lag):]; y = eb[max(0, -lag):]; m = min(len(x), len(y))
        if m > 10:
            x, y = x[:m] - x[:m].mean(), y[:m] - y[:m].mean(); d = np.linalg.norm(x) * np.linalg.norm(y)
            if d > 0: best = max(best, float(np.dot(x, y) / d))
    return best

def decoded_seconds(path):
    return len(pcm(path, 8000, True, "s16le")) / 8000.0

def luma_frames(path, w, h, n=90, start=None):
    cmd = ["ffmpeg", "-hide_banner", "-nostdin", "-v", "error"]
    if start is not None: cmd += ["-ss", f"{start:.3f}"]
    rc, so, se = sh(cmd + ["-i", path, "-an", "-vf", f"scale={w}:{h}", "-frames:v", str(n), "-pix_fmt", "gray", "-f", "rawvideo", "-"], binary=True)
    if rc != 0 or not so: raise RuntimeError("video decode: " + se.decode("utf-8", "replace")[-200:])
    return np.frombuffer(so, dtype=np.uint8).astype(np.float64).reshape(-1, h, w)

def aligned_psnr(S, O, window=4):
    best = (0.0, 0)
    for k in range(-window, window + 1):
        pairs = [(i, i + k) for i in range(0, min(len(O), len(S))) if 0 <= i + k < len(S)]
        if pairs: best = max(best, (float(np.mean([psnr(S[j], O[i]) for i, j in pairs])), k))
    return best

# ---------- PDF ----------
def pdf_pages(p):
    rc, so, _ = sh(["pdfinfo", p]); m = re.search(r"Pages:\s+(\d+)", so)
    return int(m.group(1)) if rc == 0 and m else 0

def pdf_text(p):
    rc, so, _ = sh(["pdftotext", "-layout", p, "-"]); return re.sub(r"\s+", " ", so).strip() if rc == 0 else None

def pdf_info(p):
    rc, so, _ = sh(["pdfinfo", p])
    return {k.strip(): v.strip() for k, v in (l.split(":", 1) for l in so.splitlines() if ":" in l)} if rc == 0 else {}

def pdf_render(p, page=1, dpi=50):
    base = os.path.join(TMP, hashlib.md5((p + str(page)).encode()).hexdigest())
    sh(["pdftoppm", "-r", str(dpi), "-f", str(page), "-l", str(page), "-gray", "-singlefile", "-png", p, base])
    return np.asarray(Image.open(base + ".png").convert("L"), dtype=np.float64)

# ---------- archives ----------
def archive_listing(path):
    out = {}; kind = sniff(path)
    with open(path, "rb") as f: head = f.read(8)
    if head[:4] == b"PK\x03\x04":
        with zipfile.ZipFile(path) as z:
            for i in z.infolist():
                if i.is_dir(): continue
                n = i.filename.rstrip("/")
                out[n] = ("symlink→" + z.read(i).decode()) if (i.external_attr >> 16) & 0o170000 == 0o120000 else hashlib.sha256(z.read(i)).hexdigest()
    elif head[:4] == b"Rar!":
        d = tempfile.mkdtemp(dir=TMP); sh(["bsdtar", "-x", "-f", path, "-C", d]); out = folder_listing(d)
    else:
        with tarfile.open(path) as t:
            for m in t.getmembers():
                n = m.name.lstrip("./")
                if m.issym(): out[n] = "symlink→" + m.linkname
                elif m.isfile(): out[n] = hashlib.sha256(t.extractfile(m).read()).hexdigest()
    return {k: v for k, v in out.items() if k}

def folder_listing(d):
    out = {}
    for root, _, files in os.walk(d):
        for f in files:
            p = os.path.join(root, f); rel = os.path.relpath(p, d)
            out[rel] = ("symlink→" + os.readlink(p)) if os.path.islink(p) else sha_file(p)
    return out

# ---------------------------------------------------------------------------------------------------------
class Checks:
    def __init__(self): self.items = []
    def add(self, name, ok, detail=""): self.items.append((name, bool(ok), detail))
    @property
    def ok(self): return bool(self.items) and all(i[1] for i in self.items)
    def summary(self): return " · ".join(f"{'✓' if ok else '✗'} {n}{(' ' + d) if d else ''}" for n, ok, d in self.items)

def opt(o, name, cast=str, default=None):
    return cast(o[o.index(name) + 1]) if name in o and o.index(name) + 1 < len(o) else default

def check_compress(c, inp, out):
    k = Checks(); o = c["options"]
    fin, fout = sniff(inp), sniff(out)
    k.add("format", fout == fin or (fin == "wav" and fout == "flac"), f"{fin}→{fout}")
    si, so_ = os.path.getsize(inp), os.path.getsize(out)
    k.add("smaller", so_ < si, f"{si:,}→{so_:,} B (−{100 * (1 - so_ / si):.0f}%)")
    av = fin in ("mp3", "m4a", "wav", "flac", "mp4", "mov", "mkv")
    slack = 1.05 if av else 1.0     # audio/video target size is reached by bitrate; allow 5 %
    if opt(o, "--goal") == "targetSize":
        t = opt(o, "--bytes", int); k.add("target size", so_ <= t * slack, f"≤ {t:,} B{' (+5%)' if av else ''}")
    if opt(o, "--goal") == "percentage":
        p = opt(o, "--pct", int); t = si * (100 - p) / 100; k.add("percentage", so_ <= t * slack, f"−{p}% → ≤ {int(t):,} B")
    if fin in ("jpg", "png", "webp", "heic", "tiff"):
        a, b = decode_image(inp), decode_image(out)
        md = opt(o, "--max-dim", int)
        if md and max(a.shape[:2]) > md:
            k.add("max dimension", max(b.shape[:2]) == md, f"{a.shape[1]}x{a.shape[0]}→{b.shape[1]}x{b.shape[0]}")
            a = resized(a, b.shape[1], b.shape[0])
        else:
            k.add("same size", a.shape == b.shape, f"{b.shape[1]}x{b.shape[0]}")
        if a.shape == b.shape:
            p = psnr(luma(a), luma(b)); th = {"smallest": 27}.get(opt(o, "--preset"), 30)
            k.add("same picture", p >= th, f"luma PSNR {p:.1f} dB (≥{th})")
        mi, mo = exif(inp), exif(out)
        if "--no-meta" in o: k.add("metadata removed (Keep off)", not has_gps(mo) and "IFD0:Model" not in mo, f"{len(descriptive(mo))} descriptive tags")
        elif has_gps(mi): k.add("metadata kept (Keep on)", has_gps(mo) and mo.get("IFD0:Model") == mi.get("IFD0:Model"), f"GPS + {mo.get('IFD0:Model')}")
    elif fin == "pdf":
        k.add("same pages", pdf_pages(out) == pdf_pages(inp), f"{pdf_pages(out)} pages")
        k.add("same text", pdf_text(out) == pdf_text(inp), f"{len(pdf_text(out) or '')} chars")
        p = min(psnr(pdf_render(inp, i), pdf_render(out, i)) for i in range(1, pdf_pages(inp) + 1))
        k.add("same pages visually", p >= 25, f"min page PSNR {p:.1f} dB (≥25)")
    elif fin in ("wav", "flac"):
        a, b = pcm(inp), pcm(out)
        k.add("lossless (sample-exact)", len(a) == len(b) and np.array_equal(a, b), f"{len(b):,} samples identical")
    elif fin in ("mp3", "m4a"):
        a, b = pcm(inp, 8000, True, "s16le"), pcm(out, 8000, True, "s16le")
        r = envelope_corr(a, b); di, do = len(a) / 8000, len(b) / 8000
        k.add("same sound", r >= 0.95 and abs(di - do) <= 0.1, f"loudness-contour correlation {r:.3f} (≥0.95) · {do:.2f}s (src {di:.2f}s)")
    elif fin in ("mp4", "mov", "mkv"):
        ii, io_ = probe(inp), probe(out)
        vi, vo = streams(ii, "video")[0], streams(io_, "video")[0]
        k.add("same frame size", (vi["width"], vi["height"]) == (vo["width"], vo["height"]), f"{vo['width']}x{vo['height']}")
        w, h = int(vo["width"]), int(vo["height"])
        p, off = aligned_psnr(luma_frames(inp, w, h), luma_frames(out, w, h))
        k.add("same picture", p >= 30, f"luma PSNR {p:.1f} dB (≥30, offset {off:+d})")
        r = envelope_corr(pcm(inp, 8000, True, "s16le"), pcm(out, 8000, True, "s16le"))
        k.add("same soundtrack", r >= 0.95, f"loudness-contour correlation {r:.3f} (≥0.95)")
    return k

def check_metadata(c, inp, out):
    k = Checks()
    mi, mo = exif(inp), exif(out)
    di, do = descriptive(mi), descriptive(mo)
    fin = sniff(inp)
    k.add("input had metadata", len(di) > 0, f"{len(di)} tags e.g. {', '.join(list(di)[:4])}")
    orig, added = left_from_original(mi, mo)
    k.add("nothing from the original left", not orig, ("left: " + ", ".join(f"{a}={b}" for a, b in list(orig.items())[:5])) if orig else "")
    if added: k.add("note: written by the OS writer, not from your file", True, ", ".join(f"{a}={b}" for a, b in added.items()))
    if fin in ("jpg", "png", "webp", "gif"):
        same = np.array_equal(decode_image(inp, orient=False), decode_image(out, orient=False))
        k.add("pixels identical", same, "lossless strip")
    elif fin in ("heic", "tiff"):
        p = psnr(luma(decode_image(inp)), luma(decode_image(out)))
        k.add("same picture", p >= 40, f"luma PSNR {p:.1f} dB (≥40)")
    elif fin == "pdf":
        k.add("same pages + text", pdf_pages(out) == pdf_pages(inp) and pdf_text(out) == pdf_text(inp))
        info = pdf_info(out)
        ii = pdf_info(inp)
        left = {x: info[x] for x in ("Title", "Author", "Creator", "Producer", "Subject", "Keywords") if info.get(x) and info.get(x) == ii.get(x)}
        k.add("PDF Info: no original values", not left, ", ".join(f"{a}={b}" for a, b in left.items()))
    else:
        for kind, sel in (("audio", "0:a"), ("video", "0:V")):
            hi = packet_hashes(inp, sel) if streams(probe(inp), kind) else []
            if not hi: continue
            ho = packet_hashes(out, sel)
            k.add(f"{kind} packets identical", hi == ho, f"{len(ho)} packets")
        ci = len([s for s in probe(inp)["streams"] if s.get("disposition", {}).get("attached_pic")])
        co = len([s for s in probe(out)["streams"] if s.get("disposition", {}).get("attached_pic")])
        if ci: k.add("cover art removed", co == 0, f"{ci}→{co}")
    return k

def expected_crop(o, W, H):
    if "--rect" in o:
        x, y, w, h = [float(v) for v in opt(o, "--rect").split(",")]
    else:
        a = opt(o, "--aspect"); n, d = [float(v) for v in a.split(":")]; r = n / d
        w, h = W, W / r
        if h > H: h, w = H, H * r
        w, h = int(w), int(h); x, y = (W - w) / 2, (H - h) / 2
    return int(round(x)), int(round(y)), int(w), int(h)

def check_crop(c, inp, out):
    k = Checks(); o = c["options"]
    src, dst = decode_image(inp), decode_image(out)
    H, W = src.shape[:2]
    x, y, w, h = expected_crop(o, W, H)
    size = opt(o, "--out-size")
    want = tuple(int(v) for v in size.split("x")) if size else (w, h)
    got = (dst.shape[1], dst.shape[0])
    k.add("dimensions", abs(got[0] - want[0]) <= 1 and abs(got[1] - want[1]) <= 1, f"{got[0]}x{got[1]} (want {want[0]}x{want[1]})")
    best = 0.0
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            xx, yy = max(0, x + dx), max(0, y + dy)
            region = src[yy:yy + got[1], xx:xx + got[0]] if not size else resized(src[yy:yy + h, xx:xx + w], got[0], got[1])
            if region.shape == dst.shape: best = max(best, psnr(luma(region), luma(dst)))
    th = 30 if size else 35
    k.add("pixels = requested region", best >= th, f"luma PSNR {best:.1f} dB (≥{th})")
    return k

def check_trim(c, inp, out):
    k = Checks(); o = c["options"]; fin = sniff(inp)
    if c["autoSilence"]:
        s, e, d = c["autoSilence"]
    else:
        s, e = opt(o, "--start", float), opt(o, "--end", float)
    want = e - s
    # Audio: what actually plays (decoded), not the container's packet span (AAC carries hidden pre-roll).
    do = decoded_seconds(out) if fin in ("mp3", "m4a", "wav", "flac") else duration(out)
    tol = 0.12 if fin in ("mp4", "mov", "mkv") else 0.06 if fin in ("mp3", "m4a") else 0.02
    k.add("duration", abs(do - want) <= tol, f"{do:.3f}s (want {want:.3f}s ±{tol})")
    if fin in ("wav", "flac"):
        a, b = pcm(inp), pcm(out)
        ch = int(streams(probe(inp), "audio")[0]["channels"]); sr = int(streams(probe(inp), "audio")[0]["sample_rate"])
        start = int(round(s * sr)) * ch
        hit = None
        for off in range(-int(0.02 * sr) * ch, int(0.02 * sr) * ch + 1, ch):
            j = start + off
            if 0 <= j and j + len(b) <= len(a) and np.array_equal(a[j:j + 2048], b[:2048]) and np.array_equal(a[j:j + len(b)], b):
                hit = off / ch / sr; break
        k.add("samples = source slice (lossless)", hit is not None, f"exact match at start {s + (hit or 0):.4f}s" if hit is not None else "no exact match")
    elif fin in ("mp3", "m4a"):
        hi, ho = packet_hashes(inp, "0:a"), packet_hashes(out, "0:a")
        found = sum(h in set(hi) for h in ho)
        k.add("packets copied from source (no re-encode)", ho and found >= 0.9 * len(ho), f"{found}/{len(ho)} packets found in source")
    else:
        vo = streams(probe(out), "video")[0]; w, h = int(vo["width"]), int(vo["height"])
        p, off = aligned_psnr(luma_frames(inp, w, h, 60, start=s), luma_frames(out, w, h, 60))
        k.add("frames = source from start", p >= 35, f"luma PSNR {p:.1f} dB (≥35, offset {off:+d} frames)")
        hi, ho = packet_hashes(inp, "0:V"), packet_hashes(out, "0:V")
        found = sum(h in set(hi) for h in ho)
        lossless = found >= 0.9 * len(ho) if ho else False
        if c["id"] == "trim-mkv-midgop":
            k.add("re-encoded (start not on a keyframe, as the window states)", not lossless, f"{found}/{len(ho)} packets reused")
        else:
            k.add("lossless (video packets copied)", lossless, f"{found}/{len(ho)} packets found in source")
    if c["autoSilence"]:
        s, e, d = c["autoSilence"]
        a = pcm(inp, mono=True, fmt="s16le"); sr = int(streams(probe(inp), "audio")[0]["sample_rate"])
        peak = lambda seg: 20 * np.log10(max(1.0, float(np.max(np.abs(seg))) if len(seg) else 1.0) / 32768)
        head, tail = a[:int(s * sr)], a[int(e * sr):]
        edge = max(peak(a[:int(0.1 * sr)]), peak(a[-int(0.1 * sr):]))
        if s < 0.01 and e > d - 0.01:
            k.add("nothing to trim (edges aren't silent)", edge > -50, f"edge peak {edge:.1f} dBFS")
        else:
            k.add("removed parts are silent", max(peak(head), peak(tail)) <= -45,
                  f"removed {s:.2f}s + {d - e:.2f}s, peak {max(peak(head), peak(tail)):.1f} dBFS (≤−45)")
    return k

def check_mute(c, inp, out):
    k = Checks(); po = probe(out)
    k.add("no audio", not streams(po, "audio", real_only=False), f"{len(po['streams'])} stream(s) left")
    hi, ho = packet_hashes(inp, "0:V"), packet_hashes(out, "0:V")
    k.add("video packets identical (no re-encode)", hi and hi == ho, f"{len(ho)} packets")
    return k

def check_extract(c, inp, out):
    k = Checks()
    want, got = archive_listing(inp), folder_listing(out)
    k.add("same files", sorted(want) == sorted(got), f"{len(got)} files (archive: {len(want)})")
    bad = [n for n in want if got.get(n) != want[n]]
    k.add("identical content (SHA-256)", not bad and len(want) > 0, f"{len(bad)} differ" if bad else "all match")
    return k

CHECK = {"compress": check_compress, "removeMetadata": check_metadata, "cropImage": check_crop,
         "trimVideo": check_trim, "trimAudio": check_trim, "muteVideo": check_mute, "extractArchive": check_extract}

def fake_for(c, inp, out):
    """A fake result: the input copied (or a tampered extract folder)."""
    if c["tool"] == "extractArchive":
        d = os.path.join(TMP, "fake-" + c["id"]); shutil.copytree(out, d, symlinks=True)
        files = sorted(p for p in (os.path.join(r, f) for r, _, fs in os.walk(d) for f in fs) if os.path.isfile(p) and not os.path.islink(p))
        os.remove(files[0])
        if len(files) > 1:
            with open(files[1], "ab") as f: f.write(b"tampered")
        return d
    f = os.path.join(TMP, "fake-" + c["id"] + "-" + os.path.basename(out)); shutil.copyfile(inp, f); return f

# ---------------------------------------------------------------------------------------------------------
cases = json.load(open(os.path.join(RUN, "tool-cases.json")))
rows = []
for c in cases:
    if c.get("skipped"): rows.append({"id": c["id"], "tool": c["tool"], "ok": False, "summary": "SKIPPED " + c["skipped"], "control": None}); continue
    ins = [os.path.join(RUN, x) for x in c["inputs"]]; outs = [os.path.join(RUN, x) for x in c["outputs"]]
    if c["expect"] == "decline":
        made = [f for f in os.listdir(os.path.dirname(ins[0])) if "Compressed" in f]
        msg = (c["stderr"].strip().splitlines() or [""])[0]
        ok = c["exit"] != 0 and not made and "already well compressed" in c["stderr"] and os.path.getsize(ins[0]) > 0
        rows.append({"id": c["id"], "tool": c["tool"], "ok": ok, "control": None,
                     "summary": ("✓ declined, no bigger file written · " if ok else f"✗ expected a refusal, got exit {c['exit']} files {made} · ") + msg[:150]})
        print(("PASS " if ok else "FAIL ") + c["id"], flush=True); continue
    if c["expect"] == "refuse":
        escaped = [os.path.join(r, f) for r, _, fs in os.walk(RUN) for f in fs if f == "ESCAPED-by-morph-test.txt"]
        ok = not escaped
        rows.append({"id": c["id"], "tool": c["tool"], "ok": ok, "control": None,
                     "summary": ("✓ nothing written outside the folder" if ok else f"✗ escaped file at {escaped}") +
                                f" · Morph exit {c['exit']}: {(c['stderr'].strip().splitlines() or [''])[0][:110]}"})
        print(("PASS " if ok else "FAIL ") + c["id"], flush=True); continue
    if c["exit"] != 0 or len(outs) != len(ins):
        rows.append({"id": c["id"], "tool": c["tool"], "ok": False, "control": None, "summary": f"✗ Morph failed (exit {c['exit']}): {c['stderr'][-200:]}"})
        print("FAIL " + c["id"] + " (morph error)", flush=True); continue
    parts, ok, control_caught = [], True, True
    for inp, out in zip(ins, outs):
        try:
            k = CHECK[c["tool"]](c, inp, out)
            parts.append((os.path.basename(out) + ": " if len(outs) > 1 else "") + k.summary()); ok = ok and k.ok
        except Exception as e:
            parts.append(f"✗ {type(e).__name__}: {str(e)[:160]}"); ok = False
        try:
            fk = CHECK[c["tool"]](c, inp, fake_for(c, inp, out))
            control_caught = control_caught and not fk.ok
        except Exception:
            pass  # a fake that crashes the checks is caught
    rows.append({"id": c["id"], "tool": c["tool"], "ok": ok, "summary": " | ".join(parts), "control": control_caught, "corpus": c.get("corpus")})
    print(("PASS " if ok else "FAIL ") + f"{c['id']:30} {'' if control_caught else '[CONTROL NOT CAUGHT] '}{' | '.join(parts)[:230]}", flush=True)

tested = [r for r in rows if not r["summary"].startswith("SKIPPED")]
passed = sum(r["ok"] for r in tested)
ctrl = [r for r in tested if r["control"] is not None]
caught = sum(r["control"] for r in ctrl)
names = {"compress": "Compress", "removeMetadata": "Metadata (Remove All)", "cropImage": "Crop Image", "trimVideo": "Trim Video",
         "trimAudio": "Trim Audio", "muteVideo": "Remove Audio", "extractArchive": "Extract"}
lines = ["# Independent tool verification (real-world files)", "",
         "Checked on Linux with tools that did **not** produce the results: exiftool, Ubuntu FFmpeg 6.1 (ffprobe, framemd5), "
         "Pillow, libheif, poppler, Python zipfile/tarfile, Ubuntu bsdtar. Inputs: [test-corpus/real](../test-corpus/real/SOURCES.md) "
         "(CC0 / public-domain photo, speech, MP3 with cover art, NASA video, USACE PDF, real software archives).", "",
         f"- **Tool results proven real: {passed} / {len(tested)}**",
         f"- **Fake results caught: {caught} / {len(ctrl)}** (input copied as the “result”, or a tampered extract folder)", ""]
for t in names:
    rs = [r for r in tested if r["tool"] == t]
    if not rs: continue
    lines += [f"## {names[t]} — {sum(r['ok'] for r in rs)}/{len(rs)}", "", "| | Case | Checks | Fake caught |", "|---|---|---|---|"]
    for r in rs:
        lines.append(f"| {'✅' if r['ok'] else '❌'} | {r['id']} | {r['summary'][:400].replace('|', '/')} | "
                     f"{'—' if r['control'] is None else '✅' if r['control'] else '❌'} |")
    lines.append("")
open(os.path.join(OUT, "tool-proof.md"), "w").write("\n".join(lines) + "\n")
json.dump(rows, open(os.path.join(OUT, "tool-proof.json"), "w"), indent=2)
shutil.rmtree(TMP, ignore_errors=True)
print(f"\nTOOLS PROVEN: {passed}/{len(tested)}   FAKES CAUGHT: {caught}/{len(ctrl)}")
sys.exit(0 if passed == len(tested) and caught == len(ctrl) else 1)
