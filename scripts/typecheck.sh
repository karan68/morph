#!/bin/bash
# Type-checks every Morph module with swiftc directly (no SwiftPM manifest execution, no binaries run).
# Used on machines where executing freshly built binaries is blocked (e.g. Santa Lockdown); CI uses `swift build`.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=.build/typecheck
mkdir -p "$OUT"
TARGET="arm64-apple-macos13.0"
SDK="$(xcrun --show-sdk-path)"
common=(-target "$TARGET" -sdk "$SDK" -swift-version 5 -I "$OUT" -module-cache-path "$OUT/cache" -suppress-warnings)

module() { # name deps...
  local name=$1; shift
  echo "• $name"
  swiftc "${common[@]}" -parse-as-library -emit-module -module-name "$name" \
    -emit-module-path "$OUT/$name.swiftmodule" Sources/"$name"/*.swift
}
module Capabilities
module Jobs
module Engines
module A11y
module DragKit
module ToolWindows
echo "• MorphApp (typecheck)"; swiftc "${common[@]}" -typecheck -module-name MorphApp Sources/MorphApp/*.swift
echo "• MorphCLI (typecheck)"; swiftc "${common[@]}" -typecheck -module-name MorphCLI Sources/MorphCLI/*.swift
echo "OK: all modules type-check"
