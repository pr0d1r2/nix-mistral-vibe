# nix-mistral-vibe

[Mistral Vibe](https://github.com/mistralai/mistral-vibe) 2.26.1 as a Nix
flake, built against the nixpkgs the rest of the pr0d1r2 fleet pins
(`nixos-26.05`), and served prebuilt from cachix.

It is a thin layer. The build is upstream's own `flake.nix` (uv2nix for the
Python package, crane for the Rust TUI, maturin for the Harness); this repo
pins it to a release tag and points its nixpkgs at the fleet pin. There is no
recipe here to drift from upstream's.

## Why this repo exists

nixos-26.05 ships `mistral-vibe` 2.10.1 and nixos-unstable 2.25.0, while
upstream releases about weekly. Upstream's flake tracks current releases but
pins its own nixos-unstable (2026-06-29 at v2.26.1), so taking it as an input
pulls a second nixpkgs into your lock and a second Python, stdenv and rustc
into your closure.

This repo builds upstream's flake on the fleet's nixpkgs instead, so Vibe
shares the toolchain your 26.05 system already has, and the tier-1 systems
come prebuilt from cachix.

## Do you need this?

- **One machine, any channel, no shared cache:** using upstream's flake
  directly is a fine choice. It costs you a second nixpkgs.
- **nixpkgs' `mistral-vibe` is recent enough for you:** use that. It is
  cached by cache.nixos.org.
- **Several repositories or machines on the fleet pin:** use this. Every
  consumer that follows `nixpkgs-lock` resolves the same store path, so they
  all hit one cache entry.

## Use it

```nix
inputs = {
  nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
  nixpkgs.follows = "nixpkgs-lock/nixpkgs";
  nix-mistral-vibe.url = "github:pr0d1r2/nix-mistral-vibe";
  nix-mistral-vibe.inputs.nixpkgs-lock.follows = "nixpkgs-lock";
};
```

The `follows` lines matter. A cache hit requires that every repository
resolve the same nixpkgs revision; an unfollowed nixpkgs edge changes the
store path, and you rebuild Vibe from source without any error.

Then `pkgs.mistral-vibe` via `overlays.default`, or
`nix-mistral-vibe.packages.${system}.mistral-vibe` directly.

```sh
nix run github:pr0d1r2/nix-mistral-vibe -- --version   # vibe 2.26.1
nix run github:pr0d1r2/nix-mistral-vibe#rustCli        # the Rust TUI
nix run github:pr0d1r2/nix-mistral-vibe#vibe-acp       # Agent Client Protocol server
nix run github:pr0d1r2/nix-mistral-vibe#vibe-app-server
```

| output                        | what                                        |
| ----------------------------- | ------------------------------------------- |
| `packages.<sys>.mistral-vibe` | upstream's package; `default` is the same   |
| `packages.<sys>.rustCli`      | upstream's wrapper that starts the Rust TUI |
| `apps.<sys>.default`          | `vibe`                                      |
| `apps.<sys>.rustCli`          | `vibe` with `VIBE_CLI=rust`                 |
| `apps.<sys>.vibe-acp`         | `vibe-acp`                                  |
| `apps.<sys>.vibe-app-server`  | `vibe-app-server`                           |
| `overlays.default`            | adds `pkgs.mistral-vibe`                    |
| `checks.<sys>.version`        | `vibe --version` reports the pinned version |

The package's store path is exactly upstream's: `meta.mainProgram` is added
by attribute merge, not `overrideAttrs`, so it does not rebuild anything.

## Binary cache

```text
substituter: https://pr0d1r2.cachix.org
public key:  pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=
```

**The flake's `nixConfig` is not enough on its own.** If your user is not in
`trusted-users`, nix ignores the substituter and builds from source, with
only a warning:

```text
warning: ignoring untrusted substituter 'https://pr0d1r2.cachix.org', you are not a trusted user
```

Add yourself once, in `/etc/nix/nix.conf` or the NixOS / nix-darwin
equivalent:

```text
trusted-users = root <your-user>
```

To confirm you are substituting, `nix build --max-jobs 0` fails instead of
falling back to a local build.

## Platform support

| system           | tier | CI builds | cached | notes                                  |
| ---------------- | ---- | --------- | ------ | -------------------------------------- |
| `aarch64-darwin` | 1    | yes       | yes    | native runner `macos-14`               |
| `x86_64-linux`   | 1    | yes       | yes    | native runner `ubuntu-24.04`           |
| `aarch64-linux`  | 1    | yes       | yes    | native runner `ubuntu-24.04-arm`       |
| `x86_64-darwin`  | 2    | no        | **no** | declared, built locally by hand        |

`x86_64-darwin` is declared and evaluates, but CI never builds it and nothing
is pushed for it: GitHub's only Intel macOS runner is being retired. It is
also the one system where upstream builds `cryptography` from source.

**Evaluation needs a builder for the system.** Upstream builds the Rust
TUI's source with `runCommand` and crane reads its `Cargo.toml` while
evaluating (import from derivation). Evaluating `packages.x86_64-linux` on a
Mac therefore fails with `Cannot build '...-vibe-rs-src.drv'` unless a Linux
builder is configured. On your own system this is invisible.

## Closure size

The runtime closure is large, and most of it is not Vibe:

- The Harness extension (`mistralai_vibe_local_harness/_native.abi3.so`)
  embeds the source paths of its vendored Rust crates in panic messages, which
  keeps about 530 MiB of crate sources (v8 alone is 166 MiB) alive at
  runtime. The fix belongs in upstream's build (`--remap-path-prefix`); this
  repo cannot reach the inner derivation without vendoring the recipe.
- On darwin, nixpkgs' Python 3.12 references the Apple SDK and LLVM, about
  1.3 GiB that every Python application on the pin shares.

## Pin graph

```text
nixpkgs-lock --> nix-mistral-vibe --> consumers
     \-----------------------------------^
```

`nixpkgs-lock` is the fleet's only nixpkgs authority. Bump order matters:
`nixpkgs-lock`, then this repo, then consumers. A consumer that refreshes
first resolves a revision nothing has been cached for.

## Development

```sh
direnv allow        # or: nix develop ./dev
hk check --all
```

The dev shell is a separate flake in `dev/` so consumers of the package never
lock the guardrail tools. Commits go through an hk gate generated by
[pklith](https://github.com/pr0d1r2/pklith) from `.pklith`, one check per
commit. The design and its history are in [`SPEC.md`](SPEC.md) and
[`dev/SPEC.md`](dev/SPEC.md).

## License

MIT for this repository's files, see [LICENSE](LICENSE). Mistral Vibe itself
is Apache-2.0.
