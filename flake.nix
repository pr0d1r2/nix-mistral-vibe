{
  description = "mistral-vibe for nixos 26.05 -- upstream's flake, built from the fleet's pinned nixpkgs";

  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [
      "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM="
    ];
  };

  # nixpkgs-lock is the fleet's sole nixpkgs authority. Upstream's flake pins
  # its own nixos-unstable; following ours instead puts vibe on the toolchain the
  # rest of the fleet already has, and makes the cachix paths the ones consumers
  # who follow nixpkgs-lock will ask for. Upstream's pyproject-nix, uv2nix and
  # build-system-pkgs all follow upstream's root nixpkgs, so this one edge
  # redirects them too; crane has no nixpkgs input.
  #
  # The version lives in the URL tag, not in a package.nix: there is nothing to
  # hash here, uv2nix and crane derive everything from upstream's lockfiles.
  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";
    mistral-vibe = {
      url = "github:mistralai/mistral-vibe/v2.26.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, mistral-vibe, ... }:
    let
      # Declared: 4. CI builds and caches 3 of them; x86_64-darwin is tier-2 --
      # it must evaluate everywhere but is built locally, not by CI. GitHub's
      # only Intel macOS runner is macos-13, which is on its way out. It is also
      # the one system where upstream builds cryptography from source.
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems f;
      # Upstream leaves meta.mainProgram unset, so `lib.getExe` warns. meta is
      # not part of the derivation: the store path, and the cache hit, are
      # upstream's own.
      # A plain attribute merge: overrideAttrs (and lib.addMetaAttrs, which
      # calls it) re-instantiates the derivation and changes its path.
      vibeFor =
        system:
        let
          pkg = mistral-vibe.packages.${system}.default;
        in
        pkg
        // {
          meta = pkg.meta // {
            mainProgram = "vibe";
          };
        };
      app = pkg: bin: {
        type = "app";
        program = "${pkg}/bin/${bin}";
      };
    in
    {
      packages = forAllSystems (system: {
        mistral-vibe = vibeFor system;
        default = vibeFor system;
        inherit (mistral-vibe.packages.${system}) rustCli;
      });

      # The package ships three programs; upstream exposes only `vibe`.
      apps = forAllSystems (
        system:
        mistral-vibe.apps.${system}
        // {
          vibe-acp = app (vibeFor system) "vibe-acp";
          vibe-app-server = app (vibeFor system) "vibe-app-server";
        }
      );

      overlays.default = final: _prev: {
        mistral-vibe = vibeFor final.stdenv.hostPlatform.system;
      };

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          vibe = vibeFor system;
        in
        {
          inherit (mistral-vibe.packages.${system}) default rustCli;
          # V1: the binary reports the version the input tag names.
          version =
            pkgs.runCommand "mistral-vibe-version-check" { }
              "${pkgs.bash}/bin/bash ${./scripts/version-check.sh} ${pkgs.lib.getExe vibe} ${vibe.version} $out";
        }
      );
    };
}
