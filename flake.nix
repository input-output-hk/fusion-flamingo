{
  description = "Cardano development shell";

  inputs = {
    cardano-api.url = "github:intersectmbo/cardano-api";
    haskdogs-src = {
      url = "github:carbolymer/haskdogs/feature/read-dump";
      flake = false;
    };
  };

  outputs = {
    cardano-api,
    haskdogs-src,
    ...
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = f:
      builtins.listToAttrs (map (system: {
          name = system;
          value = f system;
        })
        supportedSystems);
  in {
    devShells = forAllSystems (system: let
      pkgs = cardano-api.legacyPackages.${system}.nixpkgs;
      cabalProject = cardano-api.legacyPackages.${system}.cabalProject;
      cardanoApiShell = cabalProject.shell;
      haskellNix = pkgs.haskell-nix;
      inherit (cabalProject.args) compiler-nix-name;
      haskdogs =
        (haskellNix.cabalProject' {
          src = haskdogs-src;
          inherit compiler-nix-name;
        }).hsPkgs.haskdogs.components.exes.haskdogs;
      hasktags =
        (haskellNix.hackage-package {
          name = "hasktags";
          inherit compiler-nix-name;
        }).components.exes.hasktags;
      stylish-haskell =
        (haskellNix.hackage-package {
          name = "stylish-haskell";
          inherit compiler-nix-name;
        }).components.exes.stylish-haskell;
    in {
      default =
        pkgs.mkShell {
          # Inherit all tools, GHC, and libraries from cardano-api's shell
          inputsFrom = [cardanoApiShell];

          # Extra packages needed for cardano-node and other projects
          packages =
            [pkgs.lmdb pkgs.parallel haskdogs hasktags stylish-haskell]
            ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
              pkgs.systemdLibs
              pkgs.glibcLocales
              pkgs.inotify-tools
            ];

          LANG = "C.UTF-8";
        }
        // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
        };
    });

    formatter =
      forAllSystems
      (system: cardano-api.legacyPackages.${system}.nixpkgs.nixfmt);
  };

  nixConfig = {
    extra-substituters = ["https://cache.iog.io"];
    extra-trusted-public-keys = ["hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="];
    allow-import-from-derivation = true;
  };
}
