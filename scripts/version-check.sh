#!/usr/bin/env bash
# Asserts that a vibe binary reports the version the flake input names (V1).
#
#   scripts/version-check.sh <vibe> <expected-version> <stamp>
#
# Writes <stamp> on success so it can serve as a derivation's $out.
set -euo pipefail

vibe="$1"
expected="$2"
stamp="$3"

# vibe writes a history file under HOME; the build sandbox has none.
HOME="$(mktemp -d)"
export HOME

got="$("$vibe" --version)"
echo "$got"
case "$got" in
*"$expected"*) ;;
*)
  echo "expected vibe $expected, got: $got" >&2
  exit 1
  ;;
esac
touch "$stamp"
