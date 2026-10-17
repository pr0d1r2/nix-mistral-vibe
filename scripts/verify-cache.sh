#!/usr/bin/env bash
# Asserts that this system's packages are in the binary cache (V13).
#
#   scripts/verify-cache.sh <system> <package>...
#
# cachix-action pushes in its post step and logs a failed push without failing
# the job, so a green build is no evidence of a populated cache. This asks the
# cache itself. It evaluates on the runner of <system>: upstream's flake needs
# a builder for the system it is evaluated for.
set -euo pipefail

cache="https://pr0d1r2.cachix.org"
system="$1"
shift

rc=0
for pkg in "$@"; do
  path="$(nix eval --raw ".#packages.$system.$pkg.outPath")"
  hash="$(basename "$path" | cut -d- -f1)"
  code="$(curl -s -o /dev/null -w '%{http_code}' "$cache/$hash.narinfo")"
  echo "$system $pkg $hash -> $code"
  [ "$code" = "200" ] || rc=1
done

if [ "$rc" -ne 0 ]; then
  echo "::error::missing from $cache after a main build." >&2
  echo "::error::CACHIX_AUTH_TOKEN must be a per-cache token with WRITE access to pr0d1r2." >&2
fi
exit "$rc"
