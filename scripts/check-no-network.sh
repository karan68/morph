#!/bin/bash
# Static "no network" check over EVERY Mach-O in the bundle (spec §7.3): the app binary, helpers and all
# bundled dylibs. Fails on networking frameworks or socket/DNS/URL-session symbols outside the allowlist.
# Allowlist (documented): the app links WebKit only to rasterize SVG from an in-memory string with a
# Content-Security-Policy of default-src 'none' (see Sources/Engines/SVGRasterizer.swift).
# usage: check-no-network.sh <Morph.app>
set -euo pipefail
APP=$1
FAIL=0
BAD_FRAMEWORKS='/(Network|CFNetwork|SystemConfiguration|MultipeerConnectivity)\.framework/'
BAD_SYMBOLS='^_(socket|connect|getaddrinfo|gethostbyname|getnameinfo|sendto|recvfrom|nw_[a-z_]+|CFStream(Create|Get)[A-Za-z]*Socket[A-Za-z]*|CFHTTP[A-Za-z]+|SCNetwork[A-Za-z]+)$|URLSession|NSURLConnection'
while IFS= read -r -d '' f; do
  file -b "$f" | grep -q "Mach-O" || continue
  rel=${f#"$APP/"}
  if otool -L "$f" | grep -E "$BAD_FRAMEWORKS"; then echo "✗ $rel links a networking framework"; FAIL=1; fi
  hits=$(nm -u "$f" 2>/dev/null | grep -E "$BAD_SYMBOLS" || true)
  if [ -n "$hits" ]; then echo "✗ $rel imports network symbols:"; echo "$hits" | sed 's/^/    /'; FAIL=1; else echo "✓ $rel"; fi
done < <(find "$APP/Contents" -type f -print0)
if [ $FAIL -ne 0 ]; then echo "check-no-network: FAILED"; exit 1; fi
echo "check-no-network: OK (no networking frameworks or socket/DNS/URL-session imports)"
