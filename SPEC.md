# SPEC

## §G GOAL

Deliver `mistral-vibe` (upstream tag `v2.26.1`) to **nixos 26.05** hosts, built against fleet's pinned nixpkgs, served prebuilt from cachix `pr0d1r2`. recipe vendored w/ IFD fix (`nix/vibe.nix`, owner 2026-10-24; T23).

FIRST BUILT: guardrails (`dev` node), 1 check per commit, hooks live before any package code.

FEDERATED: rules & tasks moved to a node keep their numbers ∴ freed numbers ⊥ reused here.

## §F FEDERATION

dir|owns|⊥owns|tokens
dev|repo gate: dev flake, guardrail tools, hk steps, CI workflows, cachix push, upstream bump|the package flake|-

## §N NAV

rel|path|lens
up|-|-
self|.|-

## §C CONSTRAINTS

- src: `github:mistralai/mistral-vibe` tag `v2.26.1` (released 2026-10-09). Pin by tag ∈ input URL, ⊥ `main` (moves ∀ commit → new store path ∀ commit).
- build = uv2nix (Python, wheels preferred) + crane (Rust `vibe-rs`, vendored from `vibe/cli-rust/Cargo.lock`) + maturin (Harness, `harness/core/Cargo.lock`). ⊥ hash to maintain here: crane & uv2nix derive ∀ from upstream lockfiles.
- v8 ⊥ compiled: upstream `fetchurl`s prebuilt `librusty_v8` per system (hash pinned upstream ∀ 4 systems).
- `cryptography 50.0.0` ⊥ wheel for `x86_64-darwin` → source build w/ `fetchCargoVendor` hash upstream says "matches nixpkgs a7e1a760ab81". Risk on our pin; tier-2 only.
- python = `python312` (upstream hardcodes).
- `mistral-vibe.inputs.nixpkgs.follows = "nixpkgs"` → upstream builds on our pin. Upstream's `pyproject-nix`, `uv2nix`, `pyproject-build-systems` follow upstream root nixpkgs ∴ one edge redirects ∀. `crane` ⊥ nixpkgs input.
- ⊥ 2nd nixpkgs: unfollowed upstream nixpkgs → parallel closure → silent cache miss ∀ consumer.
- upstream tests only against unstable ∴ 26.05 compat = measured, ⊥ assumed.
- systems: declared **4** (`aarch64-darwin`, `x86_64-darwin`, `x86_64-linux`, `aarch64-linux`). tier-1 **3**: `aarch64-darwin`, `x86_64-linux`, `aarch64-linux`, CI builds native & pushes cachix. tier-2 `x86_64-darwin`: eval only, ⊥ CI build, ⊥ cached.
- MEASURED 2026-10-17 aarch64-darwin: `.#mistral-vibe` & `.#rustCli` build on 26.05 pin w/ ⊥ override; `vibe --version` → `vibe 2.26.1`. `x86_64-darwin` evals from aarch64-darwin.
- upstream IFD (B4): crane reads `Cargo.toml` of `rustCliSrc` (`runCommand` drv) @ eval. vendored: `src` = path (#1282). tag bump ! re-sync `nix/vibe.nix` vs upstream `flake.nix`.
- `nixConfig` substituter inert for untrusted users (warn `ignoring untrusted substituter`) → README ! say `trusted-users`.

## §I INTERFACES

- input (this repo): `nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock"`; `nixpkgs.follows = "nixpkgs-lock/nixpkgs"`; `mistral-vibe.url = "github:mistralai/mistral-vibe/v2.26.1"` w/ `inputs.nixpkgs.follows = "nixpkgs"`
- flake: `packages.<sys>.mistral-vibe` ≡ `nix/vibe.nix` `default`
- flake: `packages.<sys>.default` ≡ `packages.<sys>.mistral-vibe`
- flake: `packages.<sys>.rustCli` ≡ `nix/vibe.nix` `rustCli`
- flake: `apps.<sys>.{default,rustCli,vibe-acp,vibe-app-server}`
- flake: `overlays.default` → adds `pkgs.mistral-vibe`
- flake: `checks.<sys>.{default,rustCli}`
- consumer: `nix-mistral-vibe.url = "github:pr0d1r2/nix-mistral-vibe"` w/ `inputs.nixpkgs-lock.follows = "nixpkgs-lock"`
- cachix: `https://pr0d1r2.cachix.org`, key `pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=`
- cmd: `nix build .#mistral-vibe` → `result/bin/vibe`
- cmd: `nix run . -- --version` → contains `2.26.1`
- cmd: `nix flake check --all-systems` → exit 0

## §V INVARIANTS

V1: `vibe --version` from `.#mistral-vibe` → contains pinned tag version
V2: ∀ sys ∈ tier-1 → `packages.<sys>.{mistral-vibe,rustCli}` eval & build
V3: `flake.lock` committed. `nix flake check --all-systems` pass
V6: `flake.nix` inputs ≡ {`nixpkgs-lock`, `mistral-vibe`}. ⊥ direct nixpkgs URL. `mistral-vibe.inputs.nixpkgs` ! follow `nixpkgs`
V7: `flake.lock` ∃ exactly 1 nixpkgs node. 2nd → fail (unfollowed edge)
V8: nixpkgs rev ≡ nixpkgs-lock published rev
V9: upstream pinned by release tag. ⊥ branch ref
V10: ⊥ own build recipe while upstream builds on pin. Fix via `overrideAttrs` on re-export first [superseded by V20]
V11: declared systems ≡ 4. Eval ! pass ∀ 4 on a builder for that system (upstream IFD, §C). `x86_64-darwin` build ⊥ gate `main` [superseded by V21]
V12: README states `x86_64-darwin` = local build, uncached
V15: ⊥ IFD in this repo's own code, ⊥ `--impure`. upstream IFD tolerated while re-exporting (V10) [superseded by V21]
V20: `nix/vibe.nix` ≡ upstream `flake.nix` recipe at pinned tag, except crane `src` (#1282); inputs = upstream's locked ones (V6)
V21: declared systems ≡ 4; ∀ 4 eval on 1 host w/ `allow-import-from-derivation = false`; ⊥ `--impure`. `x86_64-darwin` build ⊥ gate `main`

## §T TASKS

id|status|task|cites
T21|x|upstream fixes filed, tested on v2.26.1: mistralai/mistral-vibe#1282 (path `src` → ⊥ IFD), #1283 (`--remap-path-prefix` → ⊥ 530 MiB vendor tree). on merge + release: drop per-runner eval (B4), re-measure closure|V11,V15
T23|.|upstream release w/ #1282 → drop `nix/vibe.nix`, re-export again; #1283 (530 MiB) left upstream's|V20,V21

## §B BUGS

id|date|cause|fix
B4|2026-10-17|§V.15 claimed ⊥ IFD; upstream crane reads `Cargo.toml` from `rustCliSrc` drv @ eval → linux eval from darwin fails|V11
B5|2026-10-18|`itok` gate: SPEC.md 2050 tok > ceiling 1990 (T21 text duplicated §C, §T)|§C trimmed, stale-lock bullet dropped
