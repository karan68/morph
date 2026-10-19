#!/usr/bin/env python3
"""Morph engine harness (spec §9) — runs inside engine-harness/Dockerfile on the Tokyo VM.

Exercises the SAME FFmpeg command lines as the macOS app (engine-recipes/ffmpeg-recipes.json) and the SAME bsdtar
argument shapes as Sources/Engines/Archives.swift, using the LGPL FFmpeg 7.1 / bsdtar 3.7.7 built from the pinned
sources. Validates outputs with ffprobe (codec, duration) and bsdtar listings. Recipes that need VideoToolbox are
macOS-only and are reported as such (they're covered by the macOS CI golden matrix).

usage: run-harness.py <repo-root> <out-dir>
"""
import binascii, json, os, shutil, subprocess, sys, time

repo, out = sys.argv[1], sys.argv[2]
FF, FP, TAR, GEN = os.environ["MORPH_FFMPEG"], os.environ["MORPH_FFPROBE"], os.environ["MORPH_BSDTAR"], os.environ["CORPUS_FFMPEG"]
recipes_doc = json.load(open(os.path.join(repo, "engine-recipes/ffmpeg-recipes.json")))
recipes, defaults = recipes_doc["recipes"], recipes_doc["harness_defaults"]
shutil.rmtree(out, ignore_errors=True)
corpus, work = os.path.join(out, "corpus"), os.path.join(out, "work")
os.makedirs(corpus); os.makedirs(work)
results = []

def sh(cmd, timeout=300):
    t = time.time()
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    return p.returncode, p.stdout, p.stderr, time.time() - t

def probe(path):
    rc, so, _, _ = sh([FP, "-v", "error", "-show_format", "-show_streams", "-of", "json", path])
    return json.loads(so) if rc == 0 else None

def resolve(args):
    return [defaults.get(a, a) if a in defaults else _sub(a) for a in args]

def _sub(a):
    for k, v in defaults.items(): a = a.replace(k, v)
    return a

# --- corpus (Ubuntu's GPL ffmpeg: inputs only, never shipped) ---
A = ["-f", "lavfi", "-i", "sine=frequency=440:duration=3:sample_rate=44100", "-ac", "2", "-metadata", "title=MorphSecret"]
V = ["-f", "lavfi", "-i", "testsrc2=size=320x240:rate=30:duration=3", "-f", "lavfi", "-i", "sine=frequency=330:duration=3", "-shortest", "-metadata", "title=MorphSecret"]
gen = {
    "sample.mp3": A + ["-c:a", "libmp3lame"], "sample.m4a": A + ["-c:a", "aac"], "sample.wav": A + ["-c:a", "pcm_s16le"],
    "sample.flac": A + ["-c:a", "flac"], "sample.ogg": A + ["-c:a", "libvorbis"], "sample.opus": A + ["-c:a", "libopus"],
    "sample.aiff": A + ["-c:a", "pcm_s16be"], "sample.wma": A + ["-c:a", "wmav2"],
    "sample.mp4": V + ["-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac"], "sample.mov": V + ["-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac"],
    "sample.mkv": V + ["-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac"], "sample.webm": V + ["-c:v", "libvpx-vp9", "-deadline", "realtime", "-c:a", "libopus"],
    "sample.avi": V + ["-c:v", "mpeg4", "-c:a", "libmp3lame"], "sample.wmv": V + ["-c:v", "wmv2", "-c:a", "wmav2"],
    "sample.gif": ["-f", "lavfi", "-i", "testsrc2=size=240x180:rate=10:duration=2"],
    "sample.png": ["-f", "lavfi", "-i", "testsrc2=size=640x480:duration=1", "-frames:v", "1"],
}
for name, args in gen.items():
    rc, _, se, _ = sh([GEN, "-hide_banner", "-loglevel", "error", "-y"] + args + [os.path.join(corpus, name)])
    if rc != 0: print("corpus failed:", name, se[:300]); sys.exit(2)

EXPECT_A = {"mp3": ["mp3"], "m4a": ["aac"], "wav": ["pcm_s16le"], "flac": ["flac"], "ogg": ["vorbis"], "opus": ["opus"], "aiff": ["pcm_s16be"], "wma": ["wmav2"]}
EXPECT_V = {"webm": ["vp9"], "avi": ["mpeg4"], "wmv": ["wmv2"], "gif": ["gif"], "mp3": ["mp3"]}

def record(group, name, ok, detail, dt=0.0):
    results.append({"group": group, "name": name, "ok": ok, "detail": detail, "seconds": round(dt, 2)})
    print(("PASS " if ok else "FAIL ") + f"{group:9} {name:24} {detail[:140]}", flush=True)

def run_recipe(group, name, src, key, out_name, check):
    r = recipes[key]
    if "videotoolbox" in r.get("requires", []):
        results.append({"group": group, "name": name, "ok": True, "macosOnly": True, "detail": "requires VideoToolbox — covered by macOS CI", "seconds": 0})
        print(f"MACOS    {group:9} {name}", flush=True); return
    dst = os.path.join(work, out_name)
    rc, _, se, dt = sh([FF, "-hide_banner", "-nostdin", "-y", "-loglevel", "error", "-i", src] + resolve(r["args"]) + [dst])
    if rc != 0: return record(group, name, False, se.strip().splitlines()[-1] if se.strip() else f"exit {rc}", dt)
    ok, detail = check(dst, src)
    record(group, name, ok, detail, dt)

def codec_check(kind, allowed, tol):
    def f(dst, src):
        p, s = probe(dst), probe(src)
        if not p: return False, "ffprobe failed"
        st = next((x for x in p["streams"] if x["codec_type"] == kind), None)
        if not st: return False, f"no {kind} stream"
        if st["codec_name"] not in allowed: return False, f"codec {st['codec_name']}"
        d, ds = float(p["format"].get("duration", 0)), float(s["format"].get("duration", 0))
        if abs(d - ds) > tol: return False, f"duration {d:.2f} vs {ds:.2f}"
        return True, f"{st['codec_name']} {d:.2f}s"
    return f

# --- audio: every audio→audio path (56) via the shared recipes ---
for i in ["mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "wma"]:
    for t in ["mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "wma"]:
        if i == t: continue
        run_recipe("audio", f"{i}→{t}", os.path.join(corpus, f"sample.{i}"), f"audio.{t}", f"a-{i}-{t}.{t}", codec_check("audio", EXPECT_A[t], 0.2))

# --- video: every video/GIF path; VideoToolbox ones reported as macOS-only ---
for i in ["mp4", "mov", "mkv", "webm", "avi", "wmv", "gif"]:
    targets = ["mp4", "mov", "mkv", "webm", "avi", "wmv"] if i == "gif" else ["mp4", "mov", "mkv", "webm", "avi", "wmv", "gif", "mp3"]
    for t in targets:
        if i == t: continue
        kind = "audio" if t == "mp3" else "video"
        tol = 0.6 if "gif" in (i, t) else 0.3
        run_recipe("video", f"{i}→{t}", os.path.join(corpus, f"sample.{i}"), f"video.{t}", f"v-{i}-{t}.{t}",
                   codec_check(kind, EXPECT_V.get(t, ["h264"]), tol))

# --- image → WebP (libwebp) ---
run_recipe("image", "png→webp", os.path.join(corpus, "sample.png"), "image.webp", "i.webp", codec_check("video", ["webp"], 99))

# --- tools: Remove Audio + Metadata on AV ---
def no_audio(dst, src):
    p = probe(dst); return (p is not None and not any(s["codec_type"] == "audio" for s in p["streams"])), "audio removed"
def no_secret(dst, src):
    p = probe(dst)
    if not p: return False, "ffprobe failed"
    blob = json.dumps(p.get("format", {}).get("tags", {})) + json.dumps([s.get("tags", {}) for s in p["streams"]])
    return ("MorphSecret" not in blob), "title tag removed"
for f in ["mp4", "mov", "mkv"]:
    run_recipe("tool", f"mute {f}", os.path.join(corpus, f"sample.{f}"), "tool.muteVideo", f"m.{f}", no_audio)
for f in ["mp3", "m4a", "wav", "flac", "mp4", "mov", "mkv"]:
    run_recipe("tool", f"metadata {f}", os.path.join(corpus, f"sample.{f}"), "tool.removeMetadata.av", f"md.{f}", no_secret)

# --- archives: exact argument shapes from Archives.swift ---
pay = os.path.join(work, "payload"); os.makedirs(os.path.join(pay, "docs"))
open(os.path.join(pay, "a.txt"), "w").write("alpha\n"); open(os.path.join(pay, "-dash.txt"), "w").write("dash\n")
open(os.path.join(pay, "docs", "b.txt"), "w").write("beta\n")
entries = sorted(os.listdir(pay))
def listing(p):
    rc, so, _, _ = sh([TAR, "-t", "-f", p])
    return sorted(x.rstrip("/").removeprefix("./") for x in so.splitlines() if x.strip() and x != "./")
archives = {}
for t, args in {"zip": ["--format", "zip", "-c"], "tar": ["--format", "pax", "-c"], "gz": ["--format", "pax", "-z", "-c"]}.items():
    dst = os.path.join(corpus, f"sample.{'tar.gz' if t == 'gz' else t}")
    rc, _, se, dt = sh([TAR] + args + ["-f", dst, "-C", pay, "--"] + entries)
    archives[t] = dst
    record("archive", f"create {t} (with '--')", rc == 0 and "-dash.txt" in listing(dst), se.strip()[:120] or ", ".join(listing(dst)), dt)
data = b""; started = False
for line in open("/fixtures/test_read_format_rar.rar.uu").read().splitlines():
    if line.startswith("begin "): started = True; continue
    if line == "end": break
    if started and line: data += binascii.a2b_uu(line)
archives["rar"] = os.path.join(corpus, "sample.rar"); open(archives["rar"], "wb").write(data)
for i, src in archives.items():
    want = listing(src)
    for t in ["zip", "tar", "gz"]:
        if i == t: continue
        x = os.path.join(work, f"x-{i}-{t}"); os.makedirs(x)
        rc1, _, se1, _ = sh([TAR, "-x", "-f", src, "-C", x])
        ents = sorted(os.listdir(x))
        dst = os.path.join(work, f"conv-{i}.{'tar.gz' if t == 'gz' else t}")
        args = {"zip": ["--format", "zip", "-c"], "tar": ["--format", "pax", "-c"], "gz": ["--format", "pax", "-z", "-c"]}[t]
        rc2, _, se2, dt = sh([TAR] + args + ["-f", dst, "-C", x, "--"] + ents)
        got = listing(dst) if rc2 == 0 else []
        record("archive", f"{i}→{t}", rc1 == 0 and rc2 == 0 and got == want, (se1 + se2).strip()[:120] or f"{len(got)} entries")
    x = os.path.join(work, f"extract-{i}"); os.makedirs(x)
    rc, _, se, dt = sh([TAR, "-x", "-f", src, "-C", x])
    n = sum(len(f) + len(d) for _, d, f in os.walk(x))
    record("tool", f"extract {i}", rc == 0 and n > 0, se.strip()[:120] or f"{n} entries", dt)

# --- report ---
ran = [r for r in results if not r.get("macosOnly")]
passed = sum(r["ok"] for r in ran)
macos_only = [r["name"] for r in results if r.get("macosOnly")]
ver = sh([FF, "-hide_banner", "-version"])[1].splitlines()[0]
lines = [f"# Engine harness (Tokyo VM) — {ver}", "", f"- Checks run on Linux: **{passed} / {len(ran)} passed**",
         f"- macOS-only (VideoToolbox, covered by the macOS CI golden matrix): {len(macos_only)} — {', '.join(macos_only)}", "",
         "| Result | Group | Case | Seconds | Detail |", "|---|---|---|---:|---|"]
for r in ran:
    lines.append(f"| {'✅' if r['ok'] else '❌'} | {r['group']} | {r['name']} | {r['seconds']} | {r['detail'][:150].replace('|', '/')} |")
open(os.path.join(out, "report.md"), "w").write("\n".join(lines) + "\n")
json.dump(results, open(os.path.join(out, "results.json"), "w"), indent=2)
print(f"\n{passed}/{len(ran)} passed on Linux; {len(macos_only)} macOS-only")
sys.exit(0 if passed == len(ran) else 1)
