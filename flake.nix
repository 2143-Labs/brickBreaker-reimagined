{
  description = "Godot Bricker - Godot 4 development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.godot
          ];

          shellHook = ''
            echo "Godot $(godot --version 2>/dev/null | head -n1)"
          '';
        };

        packages.default = pkgs.godot;

        apps.default = {
          type = "app";
          program = "${pkgs.godot}/bin/godot";
        };
      });
}
