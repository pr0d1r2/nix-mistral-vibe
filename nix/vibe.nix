# Upstream's build recipe, vendored from mistral-vibe's own flake.nix at the
# pinned tag (V10, owner 2026-10-24). One change: crane gets a plain source
# path, not the `vibe-rs-src` runCommand derivation, so evaluating any
# system builds nothing (no IFD, V15). This is the fix filed upstream as
# mistralai/mistral-vibe#1282; drop this file and re-export again once a
# release carries it (T23).
#
# Everything else is upstream's, in upstream's order; its hook shell is
# in nix/vibe/, one file per step (xenolith). A tag bump re-syncs
# this file against upstream's flake.nix (scripts/bump-mistral-vibe.sh says
# so). The inputs are upstream's own locked ones, so the lock graph is the
# same as when this flake only re-exported (V6, V7).
{
  pkgs,
  src,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
  crane,
}:
let
  inherit (pkgs) lib;

  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = src; };

  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  pyprojectOverrides = final: prev: {
    untokenize = prev.untokenize.overrideAttrs (old: {
      buildInputs = (old.buildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; };
    });

    # cryptography 50.0.0 has no macOS x86_64 wheel. Source builds need
    # the Python backend and vendored Rust crates inside the Nix sandbox.
    cryptography = prev.cryptography.overrideAttrs (
      old:
      lib.optionalAttrs (old.passthru.format == "pyproject") {
        cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
          inherit (old) pname version src;
          # Matches cryptography 50.0.0 in nixpkgs (a7e1a760ab81).
          hash = "sha256-heJGLh0MgDPpksWyPLaIkZ5gVEWx8UnaJKv4GvclpmI=";
        };
        buildInputs =
          (old.buildInputs or [ ])
          ++ [ pkgs.openssl ]
          ++ lib.optionals pkgs.stdenv.isDarwin [ pkgs.libiconv ];
        nativeBuildInputs =
          (old.nativeBuildInputs or [ ])
          ++ final.resolveBuildSystem {
            maturin = [ ];
            cffi = [ ];
            setuptools = [ ];
          }
          ++ [
            pkgs.rustPlatform.cargoSetupHook
            pkgs.cargo
            pkgs.rustc
            pkgs.pkg-config
          ];
      }
    );

    # The wheel override applies only where the Harness lockfile at
    # harness/core is reachable.
    mistral-vibe =
      if builtins.pathExists "${src}/harness/core/Cargo.lock" then
        prev.mistral-vibe.overrideAttrs (
          old:
          let
            # The v8 crate's build script downloads a prebuilt librusty_v8
            # archive; the sandbox has no network, so fetch it here and point
            # RUSTY_V8_ARCHIVE at it. Hashes match v8 150.3.0, pinned by
            # harness/core's Cargo.lock.
            rustyV8Archive = pkgs.fetchurl {
              url = "https://github.com/denoland/rusty_v8/releases/download/v150.3.0/librusty_v8_simdutf_release_${pkgs.stdenv.hostPlatform.rust.rustcTarget}.a.gz";
              hash =
                {
                  "x86_64-linux" = "sha256-2wl+bvpVp14L3oayuhl5g9CpG76DAfRVDEkNecB9evA=";
                  "aarch64-linux" = "sha256-WR80+czoM+IAeYduyM4gsR0Y6jGk9BL0u6EQGB3ZdrY=";
                  "x86_64-darwin" = "sha256-fs7glB27R0inqhS4+PufsVLUhj09NCLOshbnRBc+5mI=";
                  "aarch64-darwin" = "sha256-UfWFt8OGkwYSn/1haKjwuJqNSjhw3LBwlgwrT9fQSCU=";
                }
                .${pkgs.stdenv.hostPlatform.system}
                  or (throw "librusty_v8 prebuilt archive not pinned for ${pkgs.stdenv.hostPlatform.system}");
            };
            # Vendored Harness crates for the Maturin build, derived from
            # the lockfile; cargo is wired at the config level because
            # crane's layout does not satisfy cargoSetupHook.
            harnessVendor = craneLib.vendorCargoDeps {
              cargoLock = "${src}/harness/core/Cargo.lock";
            };
          in
          {
            env = (old.env or { }) // {
              VIBE_SKIP_RUST_TUI = "1";
              MATURIN_NO_INSTALL_RUST = "1";
              RUSTY_V8_ARCHIVE = "${rustyV8Archive}";
            };
            # The Rust CLI is built by crane below and lands in the wheel
            # through its vibe/_bin include.
            prePatch = (old.prePatch or "") + "\nbash ${./vibe/pre-patch.sh} ${vibeRs}/bin/vibe-rs\n";
            # The backend detects an sdist by a PKG-INFO at the project root.
            postPatch = (old.postPatch or "") + "\ntouch PKG-INFO";
            # Shell steps live in nix/vibe/, one file each (xenolith).
            preBuild = (old.preBuild or "") + "\nbash ${./vibe/pre-build.sh} ${harnessVendor}/config.toml\n";
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
              pkgs.cargo
              pkgs.rustc
            ];
          }
        )
      else
        prev.mistral-vibe;
  };

  python = pkgs.python312;

  craneLib = crane.mkLib pkgs;

  # The one change from upstream (#1282): a plain path as `src`. crane reads
  # Cargo.toml and walks the tree while evaluating; reading a derivation's
  # output there is import-from-derivation. The whats_new.md fixup moves to
  # postPatch (nix/vibe/vibe-rs-post-patch.sh).
  vibeRs = craneLib.buildPackage {
    src = "${src}/vibe/cli-rust";
    postPatch = "bash ${./vibe/vibe-rs-post-patch.sh} ${src}/vibe/whats_new.md";
    cargoVendorDir = craneLib.vendorCargoDeps {
      cargoLock = "${src}/vibe/cli-rust/Cargo.lock";
    };
    # The default `voice` feature pulls in cpal: ALSA on Linux, bindgen
    # (libclang) on macOS.
    buildInputs = lib.optionals pkgs.stdenv.isLinux [ pkgs.alsa-lib ];
    nativeBuildInputs = [
      pkgs.pkg-config
      pkgs.libclang
    ];
    env = {
      LIBCLANG_PATH = "${lib.getLib pkgs.libclang}/lib";
    };
    cargoExtraArgs = "--locked";
    doCheck = false;
  };

  pythonSet =
    (pkgs.callPackage pyproject-nix.build.packages {
      inherit python;
    }).overrideScope
      (
        lib.composeManyExtensions [
          pyproject-build-systems.overlays.default
          overlay
          pyprojectOverrides
        ]
      );
  inherit (pkgs.callPackages pyproject-nix.build.util { }) mkApplication;

  default = mkApplication {
    venv = pythonSet.mkVirtualEnv "mistralai-vibe-env" workspace.deps.default;
    package = pythonSet.mistral-vibe;
  };
in
{
  inherit default;
  # The full application with the Rust TUI forced via VIBE_CLI; one command,
  # so it stays inline (xenolith).
  rustCli = pkgs.writeShellScriptBin "vibe" ''exec env VIBE_CLI=rust "${default}/bin/vibe" "$@"'';
}
