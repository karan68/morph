#!/usr/bin/env python3
"""Runs every M1 tool through morph-cli on the real-world corpus (and the synthetic one) and records each case's
tool, options, input and output(s) for independent verification on Linux (scripts/verify-tools.py).

usage: run-tools.py <morph-cli> <real-corpus> <synthetic-corpus> <out-dir>
"""
import json, os, re, shutil, subprocess, sys, time

CLI, REAL, SYN, OUT = sys.argv[1:5]
shutil.rmtree(OUT, ignore_errors=True)
os.makedirs(os.path.join(OUT, "work"))
cases = []

def run(case_id, tool, src, opts=(), corpus="real", expect="ok"):
    """expect: 'ok' (must produce output) or 'refuse' (hostile input: must not write outside its folder)."""
    srcs = src if isinstance(src, list) else [src]
    srcs = [os.path.join(REAL if corpus == "real" else SYN, s) for s in srcs]
    if not all(os.path.exists(s) for s in srcs):
        cases.append({"id": case_id, "tool": tool, "skipped": f"missing input {srcs}"}); print("SKIP", case_id); return
    work = os.path.join(OUT, "work", case_id)
    os.makedirs(work)
    local = []
    for s in srcs:
        shutil.copy2(s, work); local.append(os.path.join(work, os.path.basename(s)))
    t = time.time()
    p = subprocess.run([CLI, "tool", tool, *local, *opts], capture_output=True, text=True, timeout=600)
    outs = [l.strip() for l in p.stdout.splitlines() if l.strip() and os.path.exists(l.strip())]
    rng = re.search(r"auto-silence range ([\d.]+)–([\d.]+) of ([\d.]+)", p.stderr)
    cases.append({
        "id": case_id, "tool": tool, "options": list(opts), "corpus": corpus, "expect": expect,
        "inputs": [os.path.relpath(x, OUT) for x in local], "outputs": [os.path.relpath(o, OUT) for o in outs],
        "exit": p.returncode, "stderr": p.stderr[-1500:], "seconds": round(time.time() - t, 2),
        "autoSilence": [float(rng.group(1)), float(rng.group(2)), float(rng.group(3))] if rng else None,
    })
    print(f"{'OK  ' if p.returncode == 0 else 'EXIT' + str(p.returncode)} {case_id:34} → {', '.join(os.path.basename(o) for o in outs)[:90]}", flush=True)

J, W, M = "jellyfish-panasonic-gps", "armstrong-small-step", "apollo8-merry-christmas.mp3"
V = "nasa-ksc-swearing-in"

# Compress
run("compress-jpg-balanced", "compress", f"{J}.jpg")
run("compress-jpg-smallest", "compress", f"{J}.jpg", ["--preset", "smallest"])
run("compress-jpg-target-40pct", "compress", f"{J}.jpg", ["--goal", "targetSize", "--bytes", str(int(os.path.getsize(os.path.join(REAL, f"{J}.jpg")) * 0.4))])
run("compress-jpg-percent-60", "compress", f"{J}.jpg", ["--goal", "percentage", "--pct", "60"])
run("compress-jpg-maxdim-1080", "compress", f"{J}.jpg", ["--max-dim", "1080"])
run("compress-jpg-no-meta", "compress", f"{J}.jpg", ["--no-meta"])
for f in ["png", "heic", "webp", "tiff"]:
    run(f"compress-{f}-strong", "compress", f"{J}.{f}", ["--preset", "strong"])
run("compress-mp3-balanced", "compress", M)
run("compress-mp3-target-50pct", "compress", M, ["--goal", "targetSize", "--bytes", str(int(os.path.getsize(os.path.join(REAL, M)) * 0.5))])
run("compress-wav-balanced", "compress", f"{W}.wav")
run("compress-wav-smallest", "compress", f"{W}.wav", ["--preset", "smallest"])
run("compress-flac-balanced", "compress", f"{W}.flac")
run("compress-m4a-strong", "compress", f"{W}.m4a", ["--preset", "strong"])
for f in ["mp4", "mov", "mkv"]:
    run(f"compress-{f}-balanced", "compress", f"{V}.{f}")
run("compress-mp4-percent-50", "compress", f"{V}.mp4", ["--goal", "percentage", "--pct", "50"])
run("compress-pdf-balanced", "compress", "nasa-plum-brook-factsheet-2008.pdf")
run("compress-pdf-strong", "compress", "nasa-plum-brook-factsheet-2008.pdf", ["--preset", "strong"])

# Metadata → Remove All
for f in ["jpg", "png", "heic", "webp", "tiff"]:
    run(f"metadata-{f}", "removeMetadata", f"{J}.{f}")
run("metadata-mp3-coverart", "removeMetadata", M)
for f in ["flac", "m4a"]:
    run(f"metadata-{f}", "removeMetadata", f"{W}.{f}")
for f in ["mp4", "mov", "mkv"]:
    run(f"metadata-{f}", "removeMetadata", f"{V}.{f}")
run("metadata-pdf", "removeMetadata", "nasa-plum-brook-factsheet-2008.pdf")
run("metadata-gif", "removeMetadata", "sample.gif", corpus="synthetic")

# Crop Image
run("crop-jpg-1x1", "cropImage", f"{J}.jpg", ["--aspect", "1:1"])
run("crop-jpg-16x9", "cropImage", f"{J}.jpg", ["--aspect", "16:9"])
run("crop-jpg-rect", "cropImage", f"{J}.jpg", ["--rect", "400,300,1200,900"])
run("crop-jpg-rect-resize", "cropImage", f"{J}.jpg", ["--rect", "400,300,1200,900", "--out-size", "800x600"])
run("crop-png-4x3", "cropImage", f"{J}.png", ["--aspect", "4:3"])
run("crop-heic-9x16", "cropImage", f"{J}.heic", ["--aspect", "9:16"])
run("crop-batch-2-jpgs", "cropImage", [f"{J}.jpg", f"{J}.png"], ["--aspect", "1:1"])

# Trim Video (MP4/MOV lossless; MKV from a keyframe = stream copy; MKV mid-GOP = re-encode)
run("trim-mp4", "trimVideo", f"{V}.mp4", ["--start", "10.0", "--end", "25.5"])
run("trim-mov", "trimVideo", f"{V}.mov", ["--start", "10.0", "--end", "25.5"])
run("trim-mkv-keyframe", "trimVideo", f"{V}.mkv", ["--start", "0", "--end", "12.0"])
run("trim-mkv-midgop", "trimVideo", f"{V}.mkv", ["--start", "10.3", "--end", "25.5"])

# Trim Audio
run("trim-wav", "trimAudio", f"{W}.wav", ["--start", "2.0", "--end", "10.0"])
run("trim-flac", "trimAudio", f"{W}.flac", ["--start", "2.0", "--end", "10.0"])
run("trim-mp3", "trimAudio", M, ["--start", "1.0", "--end", "9.0"])
run("trim-m4a", "trimAudio", f"{W}.m4a", ["--start", "2.0", "--end", "10.0"])
run("trim-wav-auto-silence", "trimAudio", f"{W}.wav", ["--auto-silence"])

# Remove Audio
for f in ["mp4", "mov", "mkv"]:
    run(f"mute-{f}", "muteVideo", f"{V}.{f}")

# Extract
run("extract-tar-gz", "extractArchive", "lame-3.100.tar.gz")
run("extract-tar", "extractArchive", "lame-3.100.tar")
run("extract-zip", "extractArchive", "libogg-1.3.5.zip")
run("extract-rar", "extractArchive", "sample.rar", corpus="synthetic")
run("extract-traversal-zip", "extractArchive", "traversal.zip", expect="refuse")

json.dump(cases, open(os.path.join(OUT, "tool-cases.json"), "w"), indent=2)
print(f"\n{len(cases)} cases recorded")
