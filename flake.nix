{
  description = "Relays NG";
  inputs = {
    nixpkgs = {
      url = github:vkleen/machines/flake;
    };
    flake-utils = {
      url = github:numtide/flake-utils;
    };
    skidl-src = {
      url = github:vkleen/skidl;
      flake = false;
    };
    kinet2pcb-src = {
      url = github:vkleen/kinet2pcb;
      flake = false;
    };
    kinparse-src = {
      url = github:vkleen/kinparse;
      flake = false;
    };
    hierplace-src = {
      url = github:devbisme/hierplace;
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }: flake-utils.lib.eachDefaultSystem (system: {
    legacyPackages = nixpkgs.legacyPackages.${system}.extend (final: prev: {
      python3 = prev.python3.override (o: {
        packageOverrides = final.lib.composeExtensions
          (o.packageOverrides or (_:_: { }))
          (pfinal: pprev: {
            kicad = pfinal.toPythonModule (final.runCommand "kicad-python" { } ''
              mkdir -p $(dirname "$out/${pfinal.python.sitePackages}")
              ln -s "${final.kicad-master.base}/${pfinal.python.sitePackages}" "$out/${pfinal.python.sitePackages}"
            '');
            hierplace = pfinal.callPackage
              ({ buildPythonPackage }: buildPythonPackage {
                pname = "hierplace";
                version = "master";
                src = inputs.hierplace-src;
                doCheck = false;
              })
              { };
            kinet2pcb = pfinal.callPackage
              ({ buildPythonPackage, pytest-runner, pytest, kinparse, hierplace, kicad }: buildPythonPackage {
                pname = "kinet2pcb";
                version = "master";
                src = inputs.kinet2pcb-src;
                propagatedBuildInputs = [ pytest-runner pytest kinparse hierplace kicad ];
                doCheck = false;
              })
              { };
            kinparse = pprev.kinparse.overrideAttrs (o: {
              src = inputs.kinparse-src;
            });
            skidl = pprev.skidl.overrideAttrs (o: {
              src = inputs.skidl-src;
              propagatedBuildInputs = (o.propagatedBuildInputs or [ ]) ++ [ pfinal.kinet2pcb ];
            });
          });
      });
    });
    devShell =
      let
        pkgs = self.legacyPackages.${system};

        pythonEnv = pkgs.python3.withPackages (p: with p; [
          eseries
          kinet2pcb
          skidl
          sympy
        ]);
      in
      pkgs.mkShell {
        buildInputs = [
          pythonEnv
        ] ++ (with pkgs; [
          openocd
          libftdi1
          pyright
        ]);
        shellHook = with pkgs.kicad-master.libraries; ''
          export KICAD_SYMBOL_DIR=${symbols}/share/kicad/symbols
          export KICAD6_SYMBOL_DIR=${symbols}/share/kicad/symbols
          export KICAD_FOOTPRINT_DIR=${footprints}/share/kicad/footprints
          export KICAD6_FOOTPRINT_DIR=${footprints}/share/kicad/footprints
        '';
      };
  });
}
