# Pinned atlas binary (canary), fetched from ariga's release bucket —
# nixpkgs' atlas lags behind. passthru.updateScript (swept by `nix run
# .#update`) re-pins to whatever the -latest pointer currently serves.
{
  stdenv,
  fetchurl,
  writeShellApplication,
  curl,
  jq,
  git,
  gnused,
  gawk,
}: let
  version = "v1.2.4-a205a7f-canary";
  fetchSrc =
    if stdenv.isDarwin
    then
      (
        if stdenv.isAarch64
        then {
          url = "https://release.ariga.io/atlas/atlas-darwin-arm64-${version}";
          hash = "sha256-lyySXD/N9VpVL5+LWGNMvsFlejiuwD5uWP38cKPzFNo=";
        }
        else {
          url = "https://release.ariga.io/atlas/atlas-darwin-amd64-${version}";
          hash = "sha256-PNKCplNFuhcEphNJbYmjqrEEMW7GSsug4WdjChK/dfU=";
        }
      )
    else if stdenv.isLinux
    then
      (
        if stdenv.isAarch64
        then {
          url = "https://release.ariga.io/atlas/atlas-linux-arm64-${version}";
          hash = "sha256-W31tYFndQN8P2rv+TYIzvaeRNSj5nba2wLfDJTtYia0=";
        }
        else {
          url = "https://release.ariga.io/atlas/atlas-linux-amd64-${version}";
          hash = "sha256-569SUq7RkzrVWynAUb1h0ZCBU88zRcOHRB2LKQzjo1U=";
        }
      )
    else (throw "unsupported platform to fetch atlas binary");
in
  stdenv.mkDerivation {
    inherit version;
    name = "atlasgo";

    src = fetchurl fetchSrc;

    dontUnpack = true;
    sourceRoot = ".";

    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/atlas
      chmod +x $out/bin/atlas
    '';

    # Re-pins this file to whatever ariga's `-latest` pointer currently
    # serves: reads the version from the downloaded binary, rewrites the
    # version string, and prefetches the four platform hashes.
    passthru.updateScript = writeShellApplication {
      name = "update-atlas";
      runtimeInputs = [curl jq git gnused gawk];
      text = ''
        cd "$(git rev-parse --show-toplevel)"
        pkg=pkgs/atlas/default.nix

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

        if [ "$latest" = "${version}" ]; then
          echo "atlas already at ${version}"
          exit 0
        fi

        echo "updating atlas ${version} -> $latest"
        sed -i.bak "s|${version}|$latest|" "$pkg"

        # The url lines interpolate the version; only the hash below
        # each url needs recomputing per platform.
        for target in darwin-arm64 darwin-amd64 linux-arm64 linux-amd64; do
          url="https://release.ariga.io/atlas/atlas-$target-$latest"
          hash=$(nix store prefetch-file --json "$url" | jq -r .hash)
          sed -i.bak "\|atlas-$target-|{n;s|hash = \"[^\"]*\"|hash = \"$hash\"|;}" "$pkg"
        done
        rm -f "$pkg.bak"
      '';
    };
  }
