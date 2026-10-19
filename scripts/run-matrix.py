#!/usr/bin/env python3
"""Golden-matrix conformance run (spec §12 "Engine conformance"; M1 exit criterion "every path passes golden tests").

For every M1 conversion path the running macOS supports (from `morph-cli caps`) and every M1 tool, run the real
engine through morph-cli and validate the output structurally with `morph-cli verify` (codec, dimensions, duration,
cue count, archive entries, metadata removed…). Writes results.json + report.md; exits 1 on any failure.

usage: run-matrix.py <morph-cli> <corpus-dir> <out-dir>
"""
import json, os, shutil, subprocess, sys, time

cli, corpus, out = sys.argv[1], sys.argv[2], sys.argv[3]
shutil.rmtree(out, ignore_errors=True)
os.makedirs(out)
caps = json.loads(subprocess.run([cli, "caps"], capture_output=True, text=True, check=True).stdout)
json.dump(caps, open(os.path.join(out, "caps.json"), "w"), indent=2)
ext = lambda f: "tar.gz" if f == "gz" else f
results = []

def run(args, timeout=240):
    t = time.time()
    try:
        p = subprocess.run([cli] + args, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout.strip(), p.stderr.strip(), time.time() - t
    except subprocess.TimeoutExpired:
        return 124, "", "timeout", time.time() - t

def case(group, name, src, cli_args, kind, target, expect_outputs=1):
    """Copy src into an isolated work dir, run, verify each output."""
    work = os.path.join(out, "work", f"{group}-{name}".replace("/", "_"))
    os.makedirs(work, exist_ok=True)
    srcs = src if isinstance(src, list) else [src]
    local = []
    for s in srcs:
        d = os.path.join(work, os.path.basename(s))
        shutil.copy2(s, d)
        local.append(d)
    code, so, se, dt = run(cli_args(local))
    rec = {"group": group, "name": name, "ok": False, "seconds": round(dt, 2), "detail": ""}
    outs = [l for l in so.splitlines() if l.strip()]
    if code != 0:
        rec["detail"] = (se.splitlines() or ["exit %d" % code])[0][:300]
        rec["log"] = se[-2000:]
    elif len(outs) != expect_outputs:
        rec["detail"] = f"expected {expect_outputs} outputs, got {len(outs)}"
    else:
        details, ok = [], True
        for i, o in enumerate(outs):
            vc, vo, ve, _ = run(["verify", local[min(i, len(local) - 1)], o, kind, target])
            try:
                v = json.loads(vo)
            except Exception:
                v = {"ok": False, "detail": ve[:200]}
            ok = ok and v["ok"]
            details.append(f"{os.path.basename(o)}: {v['detail']}")
        rec["ok"], rec["detail"] = ok, " | ".join(details)
    results.append(rec)
    print(("PASS " if rec["ok"] else "FAIL ") + f"{group:10} {name:28} {rec['detail'][:150]}", flush=True)
    return outs

def sample(fmt, tagged=False):
    p = os.path.join(corpus, "tagged" if tagged else "", f"{'tagged' if tagged else 'sample'}.{ext(fmt)}")
    return p if os.path.exists(p) else None

# 1. Conversions — every M1 path available on this macOS.
expected_paths = caps["conversionPaths"]
for fmt, targets in caps["conversions"].items():
    src = sample(fmt)
    for t in targets:
        if not src:
            results.append({"group": "convert", "name": f"{fmt}→{t}", "ok": False, "skipped": True, "detail": "no corpus sample (see CORPUS-NOTES)"})
            print(f"SKIP convert     {fmt}→{t}", flush=True)
            continue
        case("convert", f"{fmt}→{t}", src, lambda l, t=t: ["convert", l[0], t], "convert", t)

# 2. Naming: converting twice never overwrites ("sample 2.png").
work = os.path.join(out, "work", "naming"); os.makedirs(work)
shutil.copy2(sample("jpg"), work)
o1 = run(["convert", os.path.join(work, "sample.jpg"), "png"])[1]; o2 = run(["convert", os.path.join(work, "sample.jpg"), "png"])[1]
ok = os.path.basename(o1) == "sample.png" and os.path.basename(o2) == "sample 2.png"
results.append({"group": "naming", "name": "collision → 'sample 2.png'", "ok": ok, "detail": f"{os.path.basename(o1)}, {os.path.basename(o2)}"})
print(("PASS " if ok else "FAIL ") + "naming     collision", flush=True)

# 3. Tools (M1: Compress, Metadata, Crop Image, Trim Video/Audio, Mute, Extract).
for f in ["jpg", "png", "webp", "heic", "tiff", "mp3", "m4a", "wav", "flac", "mp4", "mov", "mkv", "pdf"]:
    if sample(f): case("compress", f, sample(f), lambda l: ["tool", "compress", l[0]], "compress", "")
if sample("jpg"):
    size = os.path.getsize(sample("jpg")); target = size // 2
    outs = case("compress", "jpg target-size", sample("jpg"), lambda l: ["tool", "compress", l[0], "--goal", "targetSize", "--bytes", str(target)], "compress", "")
    if outs and os.path.getsize(outs[0]) > target:
        results[-1]["ok"] = False; results[-1]["detail"] += f" | {os.path.getsize(outs[0])} > target {target}"
    case("compress", "2 jpgs (batch)", [sample("jpg"), sample("png")], lambda l: ["tool", "compress", l[0], l[1]], "compress", "", expect_outputs=2)
if sample("mp4"):
    case("compress", "mp4 50%", sample("mp4"), lambda l: ["tool", "compress", l[0], "--goal", "percentage", "--pct", "50"], "compress", "")
for f in ["jpg", "png", "tiff", "heic", "webp"]:
    if sample(f, tagged=True): case("metadata", f"tagged.{f}", sample(f, tagged=True), lambda l: ["tool", "removeMetadata", l[0]], "removeMetadata", "")
for f in ["mp3", "m4a", "wav", "flac", "mp4", "mov", "mkv", "gif", "pdf"]:
    if sample(f): case("metadata", f, sample(f), lambda l: ["tool", "removeMetadata", l[0]], "removeMetadata", "")
for f in ["jpg", "png", "webp", "heic", "tiff"]:
    if sample(f): case("crop", f, sample(f), lambda l: ["tool", "cropImage", l[0], "--aspect", "1:1"], "cropImage", "")
for f in ["mp4", "mov", "mkv"]:
    case("trim", f, sample(f), lambda l: ["tool", "trimVideo", l[0], "--start", "0.5", "--end", "2.0"], "trimVideo", "1.5")
    case("mute", f, sample(f), lambda l: ["tool", "muteVideo", l[0]], "muteVideo", "")
for f in ["mp3", "m4a", "wav", "flac"]:
    case("trim", f, sample(f), lambda l: ["tool", "trimAudio", l[0], "--start", "0.5", "--end", "2.0"], "trimAudio", "1.5")
for f in ["zip", "tar", "gz", "rar"]:
    case("extract", f, sample(f), lambda l: ["tool", "extractArchive", l[0]], "extractArchive", "")

# Report
passed = sum(r["ok"] for r in results); failed = [r for r in results if not r["ok"]]
conv = [r for r in results if r["group"] == "convert"]
conv_ok = sum(r["ok"] for r in conv)
notes = open(os.path.join(corpus, "CORPUS-NOTES.txt")).read() if os.path.exists(os.path.join(corpus, "CORPUS-NOTES.txt")) else ""
lines = [f"# Golden matrix — {caps['macOS']}", "",
         f"- Conversion paths available on this macOS: **{expected_paths}** of 174 (unavailable targets: {', '.join(caps['unavailableTargets']) or 'none'})",
         f"- Conversions passed: **{conv_ok} / {len(conv)}**",
         f"- All checks passed: **{passed} / {len(results)}**", ""]
if notes: lines += ["Corpus notes:", "```", notes.strip(), "```", ""]
lines += ["| Result | Group | Case | Seconds | Detail |", "|---|---|---|---:|---|"]
for r in results:
    lines.append(f"| {'✅' if r['ok'] else ('⏭️' if r.get('skipped') else '❌')} | {r['group']} | {r['name']} | {r.get('seconds', '')} | {r['detail'][:160].replace('|', '/')} |")
open(os.path.join(out, "report.md"), "w").write("\n".join(lines) + "\n")
json.dump(results, open(os.path.join(out, "results.json"), "w"), indent=2)
print(f"\n{passed}/{len(results)} passed; conversions {conv_ok}/{len(conv)}")
sys.exit(0 if not failed else 1)
