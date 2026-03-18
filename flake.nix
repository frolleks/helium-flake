{
  description = "Helium browser packaged from upstream Linux release tarballs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      sources = builtins.fromJSON (builtins.readFile ./sources.json);
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      mkPackage = system:
        let
          pkgs = import nixpkgs { inherit system; };
          source = sources.packages.${system};
        in
        pkgs.stdenv.mkDerivation {
          pname = "helium";
          version = sources.version;
          dontConfigure = true;
          dontBuild = true;

          src = pkgs.fetchurl {
            inherit (source) url hash;
          };

          sourceRoot = source.archiveRoot;

          nativeBuildInputs = with pkgs; [
            autoPatchelfHook
            makeWrapper
          ];

          autoPatchelfIgnoreMissingDeps = [
            "libQt5Core.so.5"
            "libQt5Gui.so.5"
            "libQt5Widgets.so.5"
            "libQt6Core.so.6"
            "libQt6Gui.so.6"
            "libQt6Widgets.so.6"
          ];

          buildInputs = with pkgs; [
            alsa-lib
            atk
            at-spi2-atk
            at-spi2-core
            cairo
            cups
            dbus
            expat
            fontconfig
            freetype
            glib
            gtk3
            libdrm
            libx11
            libxcomposite
            libxdamage
            libxext
            libxfixes
            libxrandr
            libxcb
            libxkbcommon
            nspr
            nss
            pango
            stdenv.cc.cc.lib
            systemd
            zlib
          ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
            pkgs.mesa
          ];

          installPhase = ''
            runHook preInstall

            mkdir -p $out/bin $out/libexec/helium $out/share/applications
            mkdir -p $out/share/icons/hicolor/256x256/apps

            cp -R . $out/libexec/helium
            chmod +x $out/libexec/helium/helium

            makeWrapper $out/libexec/helium/helium $out/bin/helium

            install -Dm644 helium.desktop $out/share/applications/helium.desktop
            substituteInPlace $out/share/applications/helium.desktop \
              --replace-fail "Exec=helium" "Exec=$out/bin/helium"

            install -Dm644 product_logo_256.png \
              $out/share/icons/hicolor/256x256/apps/helium.png

            runHook postInstall
          '';

          passthru = {
            signature = pkgs.fetchurl {
              url = source.signatureUrl;
              hash = source.signatureHash;
            };
          };

          meta = with pkgs.lib; {
            description = "Helium browser packaged from upstream Linux binaries";
            homepage = "https://github.com/imputnet/helium-linux";
            license = with licenses; [ gpl3Only bsd3 ];
            mainProgram = "helium";
            platforms = [ system ];
            sourceProvenance = with sourceTypes; [ binaryNativeCode ];
          };
        };
    in
    {
      packages = lib.genAttrs systems (system:
        let
          helium = mkPackage system;
        in
        {
          inherit helium;
          default = helium;
        });

      apps = lib.genAttrs systems (system: {
        helium = {
          type = "app";
          program = "${self.packages.${system}.helium}/bin/helium";
        };
        default = {
          type = "app";
          program = "${self.packages.${system}.helium}/bin/helium";
        };
      });
    };
}
