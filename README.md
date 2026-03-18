# Helium Browser Flake

Nix flake for installing the Linux release builds of [Helium](https://github.com/imputnet/helium-linux).

## What it provides

- `packages.x86_64-linux.helium`
- `packages.aarch64-linux.helium`
- `apps.<system>.helium`

The package is built from the upstream release tarballs listed in [`sources.json`](/home/frolleks/flakes/helium-flake/sources.json).

## Install

Directly from this repository:

```bash
nix profile install .#helium
```

From GitHub:

```bash
nix profile install github:frolleks/helium-flake#helium
```

Run it without installing:

```bash
nix run .#helium
```

## Verify

Check that the package evaluates:

```bash
nix flake show
```

Build the current system package:

```bash
nix build .#helium
```

After building, the browser is available at:

```bash
./result/bin/helium
```

`result` is only a build symlink created by `nix build`. It should not be committed.

## Update workflow

The GitHub Action in [`.github/workflows/update-helium.yml`](/home/frolleks/flakes/helium-flake/.github/workflows/update-helium.yml) checks `imputnet/helium-linux` for new releases, recomputes the release hashes, validates the flake, and pushes updates directly to `main` when [`sources.json`](/home/frolleks/flakes/helium-flake/sources.json) changes.
