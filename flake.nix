{
  description = "dialo's shared nix overlays and packages";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = {
    self,
    nixpkgs,
  }: let
    lib = nixpkgs.lib;
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = f:
      lib.genAttrs systems (system:
        f (import nixpkgs {inherit system;}));
  in {
    # Every package added here must carry passthru.updateScript —
    # `nix run .#update` sweeps them all.
    overlays.default = final: prev: {
      atlas = final.callPackage ./pkgs/atlas {};
    };

    packages = forAllSystems (pkgs: let
      ours = self.overlays.default pkgs pkgs;
      names = builtins.attrNames ours;
    in
      ours
      // {
        # Runs every package's passthru.updateScript, then builds the
        # updated packages so a broken re-pin never lands.
        update = pkgs.writeShellApplication {
          name = "update";
          runtimeInputs = [pkgs.git];
          text =
            ''
              cd "$(git rev-parse --show-toplevel)"
            ''
            + lib.concatMapStrings (name: ''
              echo "==> updating ${name}"
              ${lib.getExe ours.${name}.passthru.updateScript}
            '')
            names
            + ''
              echo "==> building updated packages"
              nix build --no-link ${lib.concatMapStringsSep " " (n: "\".#${n}\"") names}
            '';
        };
      });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}
