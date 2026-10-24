#!/usr/bin/env bash
# mistral-vibe prePatch (nix/vibe.nix): put crane's vibe-rs where the wheel's
# vibe/_bin include picks it up.
# Usage: pre-patch.sh VIBE-RS-BINARY
set -euo pipefail
mkdir -p vibe/_bin
cp "$1" vibe/_bin/vibe-rs
