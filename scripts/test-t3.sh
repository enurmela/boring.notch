#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/T3Tests
swiftc -parse-as-library \
  boringNotch/private/T3Sessions/T3Models.swift \
  boringNotch/private/T3Sessions/T3AgentAwareness.swift \
  boringNotch/private/T3Sessions/T3ThreadRoute.swift \
  boringNotch/private/T3Sessions/T3Client.swift \
  boringNotch/private/T3Sessions/T3AutoPair.swift \
  scripts/tests/T3CompatibilityTests.swift \
  -o build/T3Tests/compatibility
build/T3Tests/compatibility "$@"
