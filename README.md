# nix-overlays

dialo's shared nix overlays and packages.

## Usage

```nix
inputs.nix-overlays.url = "github:dialohq/nix-overlays";
```

Either apply the overlay:

```nix
import nixpkgs {
  inherit system;
  overlays = [inputs.nix-overlays.overlays.default];
}
```

or use the packages directly: `inputs.nix-overlays.packages.${system}.atlas`.

## Packages

- `atlas` — pinned [atlas](https://atlasgo.io) canary binary (nixpkgs' atlas lags behind). Overrides `pkgs.atlas`.

## Updates

Every package carries a `passthru.updateScript` that re-pins it to the
latest upstream release. `nix run .#update` runs all of them and then
builds the updated packages; the `update packages` workflow does this
hourly and pushes any bumps.

Adding a package: drop it in `pkgs/<name>/`, register it in the
overlay in `flake.nix`, and give it a `passthru.updateScript` — the
update sweep and workflow pick it up automatically.
