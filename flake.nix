{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    naersk.url = "github:nix-community/naersk";
    nixpkgs-mozilla = {
      url = "github:mozilla/nixpkgs-mozilla";
      flake = false;
    };
  };

  outputs =
    {
      self,
      flake-utils,
      naersk,
      nixpkgs,
      nixpkgs-mozilla,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = (import nixpkgs) {
          inherit system;
          overlays = [ (import nixpkgs-mozilla) ];
        };

        toolchain =
          (pkgs.rustChannelOf {
            channel = "1.76.0";
            sha256 = "sha256-e4mlaJehWBymYxJGgnbuCObVlqMlQSilZ8FljG9zPHY=";
          }).rust;

        naersk' = pkgs.callPackage naersk {
          cargo = toolchain;
          rustc = toolchain;
        };

      in
      with pkgs;
      rec {
        packages = {
          default = naersk'.buildPackage {
            src = ./.;
            buildInputs = [
              pkg-config
              glib
              gtk3
              xdg-utils
            ];
            nativeBuildInputs = [
              pkg-config
              wrapGAppsHook
              makeWrapper
            ];

            postInstall = ''
              cp -r $src/share $out/share
              wrapProgram "$out/bin/openaws-vpn-client" \
                --set-default OPENVPN_FILE "${openvpn-patched}/bin/openvpn" \
                --set-default SHARED_DIR "$out/share"
            '';
          };
        };

          overlays.default = final: prev: {
            openaws-vpn-client = self.outputs.defaultPackage.${prev.system};
          };

          openvpn-patched = import ./openvpn.nix { inherit (pkgs) fetchpatch openvpn; };

        devShell = mkShell {
          buildInputs = [
            pkg-config
            glib
            gtk3
            openvpn-patched
          ];
          nativeBuildInputs = [
            pkg-config
            wrapGAppsHook
            makeWrapper
            toolchain
          ];
        };
      }
    );
}
