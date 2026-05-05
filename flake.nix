{
  description = "Cardano development shell";

  inputs = {
    cardano-api.url = "git+file:./cardano-api";
  };

  outputs = {cardano-api, ...}: let
    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    forAllSystems = f:
      builtins.listToAttrs (map (system: {
          name = system;
          value = f system;
        })
        supportedSystems);
  in {
    devShells = forAllSystems (system: let
      pkgs = cardano-api.legacyPackages.${system}.nixpkgs;
      cardanoApiShell = cardano-api.legacyPackages.${system}.cabalProject.shell;
    in {
      default =
        pkgs.mkShell {
          # Inherit all tools, GHC, and libraries from cardano-api's shell
          inputsFrom = [cardanoApiShell];

          # Extra packages needed for cardano-node and other projects
          packages =
            [
              pkgs.lmdb
            ]
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
      forAllSystems (system:
        cardano-api.legacyPackages.${system}.nixpkgs.alejandra);
  };

  nixConfig = {
    extra-substituters = ["https://cache.iog.io"];
    extra-trusted-public-keys = ["hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="];
    allow-import-from-derivation = true;
  };
}
