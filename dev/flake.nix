{
  description = "Dev shell for nix-mistral-vibe (hk gate + fleet tools); not consumed downstream";

  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [
      "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM="
    ];
  };

  # A separate flake so consumers of the package never lock the guardrail
  # tools: the root flake keeps its two inputs. ONE nixpkgs here too:
  # nixpkgs-lock, which every tool follows. The root locks the same input;
  # the two locks must name the same rev. Tools are pinned to TAGS, each
  # bumped in its own commit.
  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";
    nix-hk = {
      url = "github:pr0d1r2/nix-hk";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
    };
    # Hook guardrails materialised from the repository's files.
    pklith = {
      url = "github:pr0d1r2/pklith/v0.1.0";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
      inputs.nix-hk.follows = "nix-hk";
    };
    # Hardened, SHA-pinned GitHub Actions workflows from `.actlith`.
    actlith = {
      url = "github:pr0d1r2/actlith/v0.1.0";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
      inputs.nix-hk.follows = "nix-hk";
      inputs.microlith.follows = "microlith";
      inputs.itok.follows = "itok";
      inputs.sherd.follows = "sherd";
      inputs.characterminator.follows = "characterminator";
      inputs.pklith.follows = "pklith";
      inputs.rekall.follows = "rekall";
      inputs.xenolith.follows = "xenolith";
    };
    # Spec form and spec operations (`mth`).
    microlith = {
      url = "github:pr0d1r2/microlith/v0.7.4";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
      inputs.nix-hk.follows = "nix-hk";
    };
    # Context limits (`itok check`).
    itok = {
      url = "github:pr0d1r2/itok/v0.3.1";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
      inputs.hk.follows = "nix-hk";
    };
    # SPEC-DAG federation, budgets, waves.
    sherd = {
      url = "github:pr0d1r2/sherd/v0.5.4";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
      inputs.nix-hk.follows = "nix-hk";
    };
    # Allowed characters per file type (`ctrm`).
    characterminator = {
      url = "github:pr0d1r2/characterminator/v0.1.1";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
      inputs.nix-hk.follows = "nix-hk";
    };
    # Rules extracted from agent memory, and the honesty gate on them.
    rekall = {
      url = "github:pr0d1r2/rekall/v0.4.0";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
      inputs.nix-hk.follows = "nix-hk";
    };
    # One language per file, 1:1 test mirror, TDD order (`xnl`).
    xenolith = {
      url = "github:pr0d1r2/xenolith/v0.1.0";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
    };
  };

  outputs =
    {
      nixpkgs,
      nix-hk,
      pklith,
      actlith,
      microlith,
      itok,
      sherd,
      characterminator,
      rekall,
      xenolith,
      ...
    }:
    let
      # pklith's lib.devShell and most fleet tools have no x86_64-darwin build;
      # the dev shell is offered only where the gate can actually run.
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      # The overlay makes `pkgs.hk` nix-hk's hk rather than nixpkgs'.
      forAll =
        f: nixpkgs.lib.genAttrs systems (s: f (nixpkgs.legacyPackages.${s}.extend nix-hk.overlays.default));
    in
    {
      devShells = forAll (
        pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
          tools =
            map (input: input.packages.${system}.default) [
              actlith
              microlith
              itok
              sherd
              characterminator
              rekall
              xenolith
            ]
            ++ [
              pkgs.nixfmt
              pkgs.statix
              pkgs.shellcheck
              pkgs.actionlint
            ];
        in
        {
          default =
            (pklith.lib.devShell {
              inherit pkgs;
              src = ../.;
              packages = tools;
            }).overrideAttrs
              (old: {
                # Our pinned tools first on PATH: pklith's catalog carries its
                # own (older) copies, and mkShell puts `packages` after them.
                nativeBuildInputs = tools ++ old.nativeBuildInputs;
                LANG = "C.UTF-8";
              });
        }
      );

      formatter = forAll (pkgs: pkgs.nixfmt);
    };
}
