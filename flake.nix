{
  description = "Dev shell with pandoc";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system:
          f {
            pkgs = import nixpkgs { inherit system; };
          });
    in {
      devShells = forAllSystems ({ pkgs }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            pandoc
            plantuml
            pandoc-plantuml-filter
            texlive.combined.scheme-medium
            librsvg

            (pkgs.python3.withPackages (pythonPkgs: [
              pythonPkgs.python-docx
              (pythonPkgs.callPackage ./.nix/docxcompose.nix { })
            ]))
          ];
        };
      });
    };
}