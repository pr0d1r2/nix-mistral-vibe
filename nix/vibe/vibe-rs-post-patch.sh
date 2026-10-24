#!/usr/bin/env bash
# vibe-rs postPatch (nix/vibe.nix, #1282): banners.rs include_str!s
# whats_new.md from above the crate. Copy it beside the crate and fix the
# path. The dependency-only build sees crane's dummy sources, where the
# include is absent, so then there is nothing to do.
# Usage: vibe-rs-post-patch.sh WHATS-NEW-MD
set -euo pipefail
banners=src/startup/banners.rs
grep -qF '../../../whats_new.md' "$banners" 2>/dev/null || exit 0
cp "$1" whats_new.md
sed -i 's|\.\./\.\./\.\./whats_new\.md|../../whats_new.md|' "$banners"
if grep -qF '../../../whats_new.md' "$banners"; then
  echo "vibe-rs-post-patch: $banners still includes ../../../whats_new.md" >&2
  exit 1
fi
