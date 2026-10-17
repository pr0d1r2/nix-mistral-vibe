#!/usr/bin/env bash
# Asserts the nixpkgs pins this repo depends on for cache hits (V7, V8, V18).
#
#   scripts/assert-pins.sh
#
# Each lock (root and dev/) holds exactly one nixpkgs node, and that node's
# rev is the one nixpkgs-lock publishes. Drift shows up nowhere else: a second
# rev only turns into a silent cache miss for consumers.
set -euo pipefail

cd "$(dirname "$0")/.."

theirs="$(nix flake metadata --json github:pr0d1r2/nixpkgs-lock |
  jq -r '.locks.nodes.nixpkgs.locked.rev')"
echo "nixpkgs-lock publishes $theirs"

rc=0
for lock in flake.lock dev/flake.lock; do
  revs="$(jq -r '[.nodes[] | select(.locked.repo? == "nixpkgs") | .locked.rev] | unique | join(" ")' "$lock")"
  count="$(jq '[.nodes[] | select(.locked.repo? == "nixpkgs")] | length' "$lock")"
  echo "$lock: $count nixpkgs node(s): $revs"
  if [ "$count" -ne 1 ]; then
    echo "::error::$lock has $count nixpkgs nodes; an input is not following nixpkgs-lock" >&2
    rc=1
  elif [ "$revs" != "$theirs" ]; then
    echo "::error::$lock pins nixpkgs $revs, nixpkgs-lock publishes $theirs" >&2
    rc=1
  fi
done
exit "$rc"
