# Timbre Packaging

This directory contains packaging configurations for different package managers and distributions.

## Directory Structure

```
pkg/
├── debian/      # Debian/Ubuntu packaging files
├── archlinux/   # Arch Linux packaging files
├── nix/         # Nix package expressions
└── README.md    # This file
```

## Debian/Ubuntu Packaging

The `debian/` directory contains all necessary files for creating `.deb` packages:

- `control` - Package metadata and dependencies
- `rules` - Build instructions
- `changelog` - Version history
- `copyright` - License information
- `compat` - Debhelper compatibility level
- `timbre.1` - Man page

### Building Debian Package

```bash
# Install build dependencies (requires Zig >= 0.15.1)
sudo apt install debhelper-compat zig

# Build the package
dpkg-buildpackage -us -uc
```

## Arch Linux Packaging

The `archlinux/` directory contains:

- `PKGBUILD` - Package build script
- `.SRCINFO` - Package metadata (generated from PKGBUILD)

### Building Arch Package

```bash
# Install build dependencies (requires Zig >= 0.15.1)
sudo pacman -S zig git

# Build the package
cd pkg/archlinux
makepkg -si
```

### Submitting to AUR

1. Update `.SRCINFO` with `makepkg --printsrcinfo > .SRCINFO`
2. Submit to the Arch User Repository (AUR)

## Nix Packaging

The `nix/` directory contains:

- `default.nix` - Main package expression
- `flake.nix` - Nix flake configuration
- `shell.nix` - Development shell

### Building with Nix

```bash
# Traditional nix-build
nix-build pkg/nix/

# With flakes
nix build .#timbre

# Development shell
nix-shell pkg/nix/shell.nix
```

### Installing

```bash
# Install directly from GitHub
nix profile install github:ballast-dev/timbre

# Or with flakes
nix profile install .#timbre
```

## Package Maintenance

When updating packages:

1. Update version numbers in all packaging files
2. Update checksums/hashes where needed
3. Test build on respective platforms
4. Update changelogs/release notes

## Contributing

When adding support for new package managers:

1. Create a new subdirectory under `pkg/`
2. Add appropriate packaging files
3. Update this README
4. Test the packaging process
5. Update the main README with installation instructions
