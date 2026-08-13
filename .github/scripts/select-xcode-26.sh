#!/bin/bash
# Select the newest Xcode 26.x on the runner.
#
# Why this exists: every package declares `// swift-tools-version: 6.2`, which needs
# Xcode 26 (Swift 6.2). The workflow used to run on `macos-15` and take whatever Xcode
# the image happened to default to — Swift 6.1 — so every job died in dependency
# resolution within ~15 seconds, before compiling a single file:
#
#   error: 'kinopubkit': package 'kinopubkit' is using Swift tools version 6.2.0
#          but the installed version is 6.1.0
#
# CI was red on every commit from 2026-08-05 to 2026-08-13 for that reason alone.
#
# So: pick the major explicitly, never the image default. Matching 26.* rather than one
# exact version means an image refresh that drops the oldest Xcode cannot break us, and
# a runner with no Xcode 26 at all fails here with a readable message instead of an
# obscure resolve error seven jobs deep.

set -euo pipefail

xcode=$(ls -d /Applications/Xcode_26*.app 2>/dev/null | sort -V | tail -1 || true)

if [ -z "$xcode" ]; then
  echo "::error::No Xcode 26.x on this runner. The packages declare swift-tools-version 6.2, which needs it."
  echo "Xcodes present on this image:"
  ls -d /Applications/Xcode*.app 2>/dev/null || echo "  (none)"
  exit 1
fi

echo "Selecting $xcode"
sudo xcode-select -s "$xcode"
