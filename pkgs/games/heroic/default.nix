{ lib
, stdenv
, fetchFromGitHub
, fetchYarnDeps
, yarn
, prefetch-yarn-deps
, nodejs
, python3
, makeWrapper
, electron
, vulkan-helper
, gogdl
, legendary-gl
, nile
}:

let appName = "heroic";
in stdenv.mkDerivation rec {
  pname = "heroic-unwrapped";
  version = "2.12.1";

  src = fetchFromGitHub {
    owner = "Heroic-Games-Launcher";
    repo = "HeroicGamesLauncher";
    rev = "v${version}";
    hash = "sha256-dfyyxE2U5rSSoTY2L5bKsnjQ8u53GgAXa+V+idDr51Q=";
  };

  offlineCache = fetchYarnDeps {
    yarnLock = "${src}/yarn.lock";
    hash = "sha256-27r6lZiD1Ptk0WIYdwNLSZy6iMnmaZjKXBUjr+5+1lQ=";
  };

  nativeBuildInputs = [
    yarn
    prefetch-yarn-deps
    nodejs
    python3
    makeWrapper
  ];

  patches = [
    # Reverts part of upstream PR 2761 so that we don't have to use a non-free Electron fork.
    # https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/pull/2761
    ./remove-drm-support.patch
    # Make Heroic create Steam shortcuts (to non-steam games) with the correct path to heroic.
    ./fix-non-steam-shortcuts.patch
  ];

  postPatch = ''
    # We are not packaging this as an Electron application bundle, so Electron
    # reports to the application that is is not "packaged", which causes Heroic
    # to take some incorrect codepaths meant for development environments.
    substituteInPlace src/**/*.ts --replace 'app.isPackaged' 'true'
  '';

  configurePhase = ''
    runHook preConfigure

    export HOME=$(mktemp -d)
    yarn config --offline set yarn-offline-mirror $offlineCache
    fixup-yarn-lock yarn.lock
    yarn install --offline --frozen-lockfile --ignore-platform --ignore-scripts --no-progress --non-interactive
    patchShebangs node_modules/

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    yarn --offline vite build

    # Remove dev dependencies.
    yarn install --production --offline --frozen-lockfile --ignore-platform --ignore-scripts --no-progress --non-interactive

    runHook postBuild
  '';

  # --disable-gpu-compositing is to work around upstream bug
  # https://github.com/electron/electron/issues/32317
  installPhase = let
    binPlatform = if stdenv.isDarwin then "darwin" else "linux";
  in ''
    runHook preInstall

    mkdir -p $out/share/{applications,${appName}}
    cp -r . $out/share/${appName}
    rm -rf $out/share/${appName}/{.devcontainer,.vscode,.husky,.idea,.github}

    chmod -R u+w "$out/share/${appName}/public/bin" "$out/share/${appName}/build/bin"
    rm -rf "$out/share/${appName}/public/bin" "$out/share/${appName}/build/bin"
    mkdir -p "$out/share/${appName}/build/bin/${binPlatform}"
    ln -s \
      "${gogdl}/bin/gogdl" \
      "${legendary-gl}/bin/legendary" \
      "${nile}/bin/nile" \
      "${lib.optionalString stdenv.isLinux "${vulkan-helper}/bin/vulkan-helper"}" \
      "$out/share/${appName}/build/bin/${binPlatform}"

    makeWrapper "${electron}/bin/electron" "$out/bin/heroic" \
      --inherit-argv0 \
      --add-flags --disable-gpu-compositing \
      --add-flags $out/share/${appName} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime}}"

    substituteInPlace "$out/share/${appName}/flatpak/com.heroicgameslauncher.hgl.desktop" \
      --replace "Exec=heroic-run" "Exec=heroic"
    mkdir -p "$out/share/applications" "$out/share/icons/hicolor/512x512/apps"
    ln -s "$out/share/${appName}/flatpak/com.heroicgameslauncher.hgl.desktop" "$out/share/applications"
    ln -s "$out/share/${appName}/flatpak/com.heroicgameslauncher.hgl.png" "$out/share/icons/hicolor/512x512/apps"

    runHook postInstall
  '';

  meta = with lib; {
    description = "A Native GOG, Epic, and Amazon Games Launcher for Linux, Windows and Mac";
    homepage = "https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher";
    changelog = "https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/releases";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ aidalgol ];
    platforms = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
    mainProgram = appName;
  };
}
