# Pinned atlas binary (canary), fetched from ariga's release bucket —
# nixpkgs' atlas lags behind. The pin (version + per-platform hashes)
# lives in pin.json; passthru.updateScript (swept by `nix run .#update`)
# re-pins it to whatever the -latest pointer currently serves.
{
  stdenv,
  fetchurl,
  writeShellApplication,
  curl,
  jq,
  git,
  gawk,
}: let
  pin = builtins.fromJSON (builtins.readFile ./pin.json);
  target =
    if stdenv.isDarwin && stdenv.isAarch64
    then "darwin-arm64"
    else if stdenv.isDarwin
    then "darwin-amd64"
    else if stdenv.isLinux && stdenv.isAarch64
    then "linux-arm64"
    else if stdenv.isLinux
    then "linux-amd64"
    else throw "unsupported platform to fetch atlas binary";
in
  stdenv.mkDerivation {
    name = "atlasgo";
    version = pin.version;

    src = fetchurl {
      url = "https://release.ariga.io/atlas/atlas-${target}-${pin.version}";
      hash = pin.hashes.${target};
    };

    dontUnpack = true;
    sourceRoot = ".";

    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/atlas
      chmod +x $out/bin/atlas
    '';

    # Reads the current upstream version off the downloaded -latest
    # binary and regenerates pin.json with freshly prefetched hashes.
    passthru.updateScript = writeShellApplication {
      name = "update-atlas";
      runtimeInputs = [curl jq git gawk];
      text = ''
        cd "$(git rev-parse --show-toplevel)"
        pin=pkgs/atlas/pin.json

        os=$(uname -s | tr '[:upper:]' '[:lower:]')
        arch=$(uname -m)
        case "$arch" in
        x86_64) arch=amd64 ;;
        aarch64 | arm64) arch=arm64 ;;
        esac

        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        curl -sfo "$tmp/atlas" "https://release.ariga.io/atlas/atlas-$os-$arch-latest"
        chmod +x "$tmp/atlas"
        latest=$("$tmp/atlas" version | head -1 | awk '{print $3}')

        if [ "$latest" = "${pin.version}" ]; then
          echo "atlas already at ${pin.version}"
          exit 0
        fi

        echo "updating atlas ${pin.version} -> $latest"
        for t in darwin-arm64 darwin-amd64 linux-arm64 linux-amd64; do
          hash=$(nix store prefetch-file --json "https://release.ariga.io/atlas/atlas-$t-$latest" | jq -r .hash)
          jq --arg t "$t" --arg h "$hash" '.hashes[$t] = $h' "$pin" >"$tmp/pin.json"
          mv "$tmp/pin.json" "$pin"
        done
        jq --arg v "$latest" '.version = $v' "$pin" >"$tmp/pin.json"
        mv "$tmp/pin.json" "$pin"
      '';
    };
  }
