#!/usr/bin/env bash
# Moves the mistral-vibe input to upstream's latest release tag and proves it.
#
#   scripts/bump-mistral-vibe.sh           # bump if upstream is newer
#   scripts/bump-mistral-vibe.sh --force   # re-lock and rebuild the current tag
#
# Rewrites the tag in flake.nix, re-locks only that input and builds the
# package and its version check. Prints NEW_VERSION=<version> on stdout when
# the tag moved, so CI can report it. Nothing else in the repo carries the
# version, except README.md and SPEC.md prose, which a person updates.
set -euo pipefail

cd "$(dirname "$0")/.."
force=false
[ "${1:-}" = "--force" ] && force=true

current="$(sed -n 's|.*"github:mistralai/mistral-vibe/v\([^"]*\)".*|\1|p' flake.nix)"
[ -n "$current" ] || {
  echo "cannot read the mistral-vibe tag from flake.nix" >&2
  exit 1
}

latest="$(gh api repos/mistralai/mistral-vibe/releases/latest --jq .tag_name)"
latest="${latest#v}"
[ -n "$latest" ] || {
  echo "cannot read upstream's latest release" >&2
  exit 1
}

echo "current=$current latest=$latest force=$force" >&2
if [ "$current" = "$latest" ] && [ "$force" = false ]; then
  echo "already current" >&2
  exit 0
fi

sed -i.bak "s|github:mistralai/mistral-vibe/v$current\"|github:mistralai/mistral-vibe/v$latest\"|" flake.nix
rm -f flake.nix.bak
nix flake update mistral-vibe

system="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix build --no-link --print-build-logs \
  ".#packages.$system.mistral-vibe" \
  ".#packages.$system.rustCli" \
  ".#checks.$system.version"

if [ "$current" != "$latest" ]; then
  echo "NEW_VERSION=$latest"
fi
