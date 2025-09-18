{
  description = "Smart log filtering and categorization tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        timbre = pkgs.callPackage ./default.nix { };
      in
      {
        packages = {
          default = timbre;
          timbre = timbre;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            zig
            zls  # Zig Language Server
          ];
        };

        apps.default = {
          type = "app";
          program = "${timbre}/bin/timbre";
        };
      }
    );
}
