#!/bin/bash
# Runs the engine harness on the Tokyo VM (spec §9.3). From the repo root on your Mac:
#   engine-harness/run-on-vm.sh [ssh-host]   (default: sandbox-vm-tokyo)
set -euo pipefail
HOST=${1:-sandbox-vm-tokyo}
cd "$(dirname "$0")/.."
tar --exclude .build --exclude .git --exclude docs --exclude vendor-out --exclude dist -czf /tmp/morph-harness.tgz .
scp -q /tmp/morph-harness.tgz "$HOST":/tmp/morph-harness.tgz
ssh "$HOST" 'set -e; rm -rf ~/morph-harness && mkdir ~/morph-harness && tar -xzf /tmp/morph-harness.tgz -C ~/morph-harness 2>/dev/null
  cd ~/morph-harness && df -h / | tail -1
  docker build -q -t morph-engine-harness -f engine-harness/Dockerfile . >/dev/null
  docker run --rm -v "$PWD":/harness morph-engine-harness python3 engine-harness/run-harness.py /harness /harness/engine-harness/out'
scp -q "$HOST":morph-harness/engine-harness/out/report.md engine-harness/REPORT.md
echo "report: engine-harness/REPORT.md"
