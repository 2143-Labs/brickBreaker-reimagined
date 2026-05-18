{
  description = "Godot Bricker - Godot 4 HTML5 game";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        godot = pkgs.godot_4_5;
        export-templates = pkgs.godot_4_5-export-templates-bin;

        web-game = pkgs.stdenv.mkDerivation {
          pname = "godot-bricker-web";
          version = "0.1.0";
          src = ./.;
          nativeBuildInputs = [ godot ];

          buildPhase = ''
            export HOME=$TMPDIR
            mkdir -p $HOME/.local/share/godot
            ln -s ${export-templates}/share/godot/export_templates \
                  $HOME/.local/share/godot/export_templates
            mkdir -p $TMPDIR/build
            godot --headless --export-release "Brick breaker Web" $TMPDIR/build/index.html
          '';

          installPhase = ''
            mkdir -p $out
            cp -r $TMPDIR/build/* $out/
          '';
        };

        container = pkgs.dockerTools.buildLayeredImage {
          name = "ghcr.io/2143-labs/godot-bricker";
          tag = "web-latest";
          contents = [
            web-game
            pkgs.python3
            pkgs.cacert
          ];
          config = {
            Cmd = [
              "${pkgs.python3}/bin/python3"
              "-c"
              ''
import http.server, socketserver, os
class H(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy","same-origin")
        self.send_header("Cross-Origin-Embedder-Policy","require-corp")
        super().end_headers()
os.chdir("${web-game}")
with socketserver.TCPServer(("0.0.0.0",8080), H) as s:
    s.serve_forever()
              ''
            ];
            ExposedPorts = { "8080/tcp" = {}; };
          };
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [ godot ];

          shellHook = ''
            echo "Godot $(godot --version 2>/dev/null | head -n1)"
          '';
        };

        packages = {
          default = web-game;
          editor = godot;
          web-game = web-game;
          container = container;
        };

        apps = {
          default = {
            type = "app";
            program = "${pkgs.writeShellScript "serve-game" ''
              cd ${web-game}
              echo "Serving Godot Bricker at http://localhost:8080"
              ${pkgs.python3}/bin/python3 -m http.server 8080
            ''}";
          };
          edit = {
            type = "app";
            program = "${godot}/bin/godot";
          };
          serve = self.apps.${system}.default;
        };
      });
}
