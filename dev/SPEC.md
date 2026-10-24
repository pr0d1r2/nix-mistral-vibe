# SPEC

## §G GOAL

`dev/` — repo gate: dev flake w/ fleet guardrail tools, hk steps from `.pklith`, CI workflows, cachix push, upstream bump. rules & tasks moved here from root keep their numbers.

## §N NAV

rel|path|lens
up|.|-
self|dev|repo gate: dev flake, guardrail tools, hk steps, CI workflows, cachix push, upstream bump

## §C CONSTRAINTS

- `dev/flake.nix` = separate flake ∴ package consumers ⊥ lock guardrail tools. inputs `nixpkgs-lock` (nixpkgs follows), `nix-hk`, `pklith`, `actlith`, `microlith`, `itok`, `sherd`, `characterminator`, `rekall`, `xenolith`; ∀ follow `nixpkgs-lock`; fleet tools pinned by tag. dev shell = pklith `lib.devShell`; `.envrc` `use flake ./dev`. systems = 3 (pklith ⊥ `x86_64-darwin`).
- gate = hk via pklith-generated `hk.pklith.pkl` from `.pklith`; `fast` pre-commit, `all` pre-push. `pkl/**` vendored, ⊥ fixer, ⊥ linter.
- `pkl/Config.pkl` = hk 2.7.0 release schema, copied from pklith main (#57) until pklith release > v0.1.0 ships it.
- native runners: `ubuntu-24.04`, `ubuntu-24.04-arm`, `macos-14`. ⊥ qemu, ⊥ cross.
- `cachix-action` pushes ∈ POST step, logs 403 w/o failing job ∴ separate `verify-cache` job.
- ⊥ workflow pushes branch or opens PR. bumps by hand or loop.
- CI hand-written, ⊥ actlith v0.1.0: its `build` kind has ⊥ `assert-pins`. 1-host eval works since `.:V21`. actions SHA-pinned as actlith.

## §I INTERFACES

- cmd: `nix develop ./dev` | `direnv allow` → shell w/ hk, pklith & fleet tools
- cmd: `hk check --all` → exit 0; `pklith confirm` → exit 0
- env: `CACHIX_AUTH_TOKEN` repo secret, per-cache token w/ WRITE on `pr0d1r2`
- ci: `.github/workflows/build.yml` (build, verify-cache, eval, assert-pins, gate)
- ci: `.github/workflows/upstream.yml` (daily, detection only)
- script: `scripts/bump-mistral-vibe.sh` → bump tag in `flake.nix`, relock, build; prints `NEW_VERSION=` when moved
- script: `scripts/verify-cache.sh <sys> <pkg>...`, `scripts/assert-pins.sh`

## §V INVARIANTS

V4: cachix push ∀ tier-1 on `main` push only. PR ⊥ push
V5: push filter → own paths only, ⊥ mirror nixpkgs closure
V13: `main` build → ∀ tier-1 path ∈ cachix, asserted by `<hash>.narinfo` ≡ 200 from separate job (`needs: build`)
V14: upstream workflow = detection only. newer tag that builds → job red w/ bump command. ⊥ PR, ⊥ push
V16: hooks live before package code; ∀ later commit via real hooks; ⊥ `--no-verify`
V17: 1 check = 1 commit. exception ! named in body: checks that cannot land apart (`gen-check` + `pklith-check`)
V18: `dev/flake.lock` ∃ exactly 1 nixpkgs node; rev ≡ root `flake.lock` nixpkgs rev
V19: ∀ tracked file type has `.pklith` row; `pklith check` & `pklith gen --check` ∈ gate

## §T TASKS

id|status|task|cites
T22|.|on pklith release > v0.1.0: bump `dev/flake.nix` pklith tag, drop hand-vendored `pkl/Config.pkl` if seed matches (B1). lay bugs reported as comments on pklith #29 (B2), #42 (tools ⊥ PATH); inline guards on #16|V16,V17

## §B BUGS

id|date|cause|fix
B1|2026-10-17|pklith v0.1.0 seeds `pkl/Config.pkl` older than hk 2.7.0 → `union property 'command' has no selected default`, ∀ commit refused|V16
B2|2026-10-17|`pklith lay`: `gen-check` fixer (`pklith gen`) runs ∈ pre-commit, regenerates ∀ steps → `pklith-check` lands early, its own commit empty → lay rolls back ∀|V17
B3|2026-10-17|`dev/flake.nix` repeated `inputs.<name>.follows` keys → statix W20; shims & `.envrc` failed shfmt (8-space indent) & shellcheck SC2148|V19
