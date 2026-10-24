#!/usr/bin/env bash
# mistral-vibe preBuild (nix/vibe.nix): point cargo at the vendored Harness
# crates; cargo reads .cargo/config.toml from the source root upward.
# Usage: pre-build.sh CONFIG-TOML
set -euo pipefail
mkdir -p .cargo
cat "$1" >>.cargo/config.toml
