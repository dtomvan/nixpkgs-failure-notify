{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem =
        {
          self',
          pkgs,
          lib,
          ...
        }:
        {
          devShells.default = pkgs.mkShell {
            # ensure default configuration
            env.CFLAGS = "";

            packages = builtins.attrValues {
              inherit (pkgs)
                curl
                gcc
                python3
                jq
                gh
                ;
            };
          };

          packages =
            let
              python-script =
                name: path:
                pkgs.writers.writePython3Bin name {
                  doCheck = false;
                } (builtins.readFile path);
            in
            {
              default = pkgs.symlinkJoin {
                name = "collect-multiple-full";
                paths = builtins.attrValues {
                  inherit (self'.packages)
                    collect
                    collect-multiple
                    fast-hydra-parser
                    hydra-parser
                    create-issues
                    ;
                };

                meta.mainProgram = "collect-multiple.sh";
              };

              hydra-parser =
                let
                  inherit (lib.importTOML ./python_hydra_parser/pyproject.toml) project;
                in
                pkgs.python3Packages.buildPythonPackage {
                  pname = project.name;
                  inherit (project) version;
                  pyproject = true;
                  src = lib.cleanSource ./python_hydra_parser;

                  build-system = [
                    pkgs.python3Packages.uv-build
                  ];

                  pythonImportsCheck = [ "hydra_parser" ];

                  meta = {
                    inherit (project) description;
                    mainProgram = "hydra-to-csv";
                    license = lib.getLicenseFromSpdxId project.license;
                  };
                };

              create-issues = python-script "create-issues.py" ./create-issues.py;

              collect = pkgs.writeShellApplication {
                name = "collect.sh";
                text = (builtins.readFile ./collect.sh);
                runtimeInputs = builtins.attrValues {
                  inherit (pkgs)
                    curl
                    gcc
                    python3
                    jq
                    ;
                  inherit (self'.packages)
                    fast-hydra-parser
                    hydra-parser
                    ;
                };
              };

              collect-multiple = pkgs.writeShellApplication {
                name = "collect-multiple.sh";
                text = builtins.readFile ./collect-multiple.sh;
                runtimeInputs = lib.singleton self'.packages.collect;
              };

              fast-hydra-parser = pkgs.callPackage (
                { stdenv, lib }:
                stdenv.mkDerivation {
                  pname = "fast-hydra-parser";
                  version = "0.0.1";
                  src = lib.fileset.toSource {
                    root = ./.;
                    fileset = lib.fileset.unions [
                      ./Makefile
                      ./fast-hydra-parser.c
                    ];
                  };

                  env.PREFIX = "${placeholder "out"}";
                  meta = {
                    description = "Parser collecting a hydra jobset overview to CSV";
                    maintainers = with lib.maintainers; [ sigmanificient ];
                    license = lib.licenses.bsd3;
                    mainProgram = "fhp";
                  };
                }
              ) { };
            };
        };
    };
}
