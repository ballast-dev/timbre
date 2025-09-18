# Timbre - Turn those logs into quality lumber 🪵

Debugging a program with tons of output? Pass them to `timbre`

## Features

- 🔍 Smart log filtering with regex support
- 📁 Organized log categorization
- ⚙️ TOML configuration
- 🚀 High performance
- 📊 Detailed diagnostics

```sh
./app_with_tons_of_output | timbre
```
Structured logs add soundness to the noise of development. Add custom filters and categories to timbre with a configuration file to chop those logs in their respective files.
```
ls -l .timbre/
  error.log
  warn.log
  info.log
  debug.log
```

[![CI](https://github.com/ballast-dev/timbre/actions/workflows/ci.yml/badge.svg)](https://github.com/ballast-dev/timbre/actions/workflows/ci.yml)
[![Release](https://github.com/ballast-dev/timbre/actions/workflows/release.yml/badge.svg)](https://github.com/ballast-dev/timbre/actions/workflows/release.yml)

## Quick Start

### Installation

Timbre is available through multiple package managers:

#### Debian/Ubuntu

```bash
# For AMD64 (x86_64)
curl -LO https://github.com/ballast-dev/timbre/releases/latest/download/timbre_*_amd64.deb
sudo dpkg -i timbre_*_amd64.deb

# For ARM64 (aarch64)
curl -LO https://github.com/ballast-dev/timbre/releases/latest/download/timbre_*_arm64.deb
sudo dpkg -i timbre_*_arm64.deb
```

#### Arch Linux

```bash
# Install from AUR
yay -S timbre

# Or build from source
git clone https://github.com/ballast-dev/timbre.git
cd timbre/pkg/archlinux
makepkg -si
```

#### Nix/NixOS

```bash
# Install with Nix flakes
nix profile install github:ballast-dev/timbre

# Or add to your NixOS configuration
environment.systemPackages = with pkgs; [ timbre ];

# Development shell
nix develop github:ballast-dev/timbre
```

### Basic Usage

```bash
# Process logs with default settings
./app | timbre

# Use custom configuration
./app | timbre --config=timbre.toml

# Enable verbose output
./app | timbre --verbose
```

### Configuration

```toml
[timbre]
log_dir = "/var/log/timbre"

[log_level]
debug = "debug"
warn = "warn(ing)?"
error = "error|exception|fail"
```

## Documentation

- [Workflow](docs/workflow.md) - Detailed CI/CD and development workflow
- [Contributing](docs/CONTRIBUTING.md) - How to contribute to Timbre
- [Changelog](CHANGELOG.md) - Version history and changes
- [Commit Convention](docs/commit_convention.md)
- [Packaging](pkg/README.md) - Package creation and distribution

## Packaging

Timbre supports multiple package formats:

- **Debian/Ubuntu**: `.deb` packages for APT-based systems
- **Arch Linux**: `PKGBUILD` for Arch User Repository (AUR)
- **Nix**: Flake-based package for Nix/NixOS

See [`pkg/README.md`](pkg/README.md) for detailed packaging instructions and maintenance guidelines.

## Building from Source

### Prerequisites

- Zig 0.15.1 or later
- A C++17 compatible compiler

### Build Instructions

#### Container building is encouraged!
1. First **get Docker**
    - [Download Docker Desktop](https://www.docker.com) (for Windows and Mac)
    - Use your package manager in Linux, i.e. `apt`, `pacman`, etc...
    - Or just run: `curl -fsSL https://get.docker.com | sh -`
1. Get code, `git clone github.com/ballast-dev/timbre.git && cd timbre` 
1. Build image, `docker build -t timbre:latest - < Dockerfile`
1. Jump into image, 

       docker run -it --rm -v $(pwd):/app -w /app timbre:latest 

#### Zig Build System!
Timbre uses Zig's build system for cross-compilation to various platforms. The build system automatically detects your platform and builds the appropriate version by default.

```bash
# Build for your current platform (debug)
zig build

# Build with release optimizations
zig build --release=fast
```

### Cross-Compilation Targets

Timbre supports building for multiple platforms:

```bash
zig build all
```

### Build Output
```
zig-out/
|-- aarch64-linux-musl
|-- aarch64-macos
|-- aarch64-windows
|-- x86_64-linux-musl
|-- x86_64-macos
`-- x86_64-windows
```

### Testing

Tests can be run for any target platform:

```bash
zig build test
```

## Project Structure

```
.
├── src/           # Source files
│   ├── main.cpp   # Main entry point
│   ├── timbre.cpp # Core audio processing
│   ├── config.cpp # Configuration handling
│   └── log.cpp    # Logging utilities
├── inc/           # Header files
├── tests/         # Test files
└── build.zig      # Build system definition
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## LICENSE

This project is licensed under the MIT License - see the [license](LICENSE) file for details.