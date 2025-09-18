#!/bin/bash
# Build script for creating packages across different distributions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VERSION="1.0.0"

echo "Building packages for Timbre v$VERSION"
echo "Project root: $PROJECT_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [[ ! -f "$PROJECT_ROOT/build.zig" ]]; then
    print_error "Not in Timbre project root directory"
    exit 1
fi

# Build Debian package
build_debian() {
    print_status "Building Debian package..."
    
    if ! command -v dpkg-buildpackage &> /dev/null; then
        print_warning "dpkg-buildpackage not found, skipping Debian package"
        return 1
    fi
    
    cd "$PROJECT_ROOT"
    
    # Copy debian files to project root
    cp -r pkg/debian .
    
    # Build package
    dpkg-buildpackage -us -uc -b
    
    # Clean up
    rm -rf debian
    
    print_status "Debian package built successfully"
}

# Build Arch package
build_arch() {
    print_status "Building Arch Linux package..."
    
    if ! command -v makepkg &> /dev/null; then
        print_warning "makepkg not found, skipping Arch package"
        return 1
    fi
    
    cd "$SCRIPT_DIR/archlinux"
    
    # Update .SRCINFO
    makepkg --printsrcinfo > .SRCINFO
    
    # Build package
    makepkg -f
    
    print_status "Arch Linux package built successfully"
}

# Build Nix package
build_nix() {
    print_status "Building Nix package..."
    
    if ! command -v nix-build &> /dev/null; then
        print_warning "nix-build not found, skipping Nix package"
        return 1
    fi
    
    cd "$SCRIPT_DIR/nix"
    
    # Build package
    nix-build
    
    print_status "Nix package built successfully"
}

# Main execution
main() {
    case "${1:-all}" in
        debian)
            build_debian
            ;;
        arch)
            build_arch
            ;;
        nix)
            build_nix
            ;;
        all)
            print_status "Building all packages..."
            build_debian || true
            build_arch || true
            build_nix || true
            ;;
        *)
            echo "Usage: $0 [debian|arch|nix|all]"
            echo "  debian - Build Debian/Ubuntu package"
            echo "  arch   - Build Arch Linux package"
            echo "  nix    - Build Nix package"
            echo "  all    - Build all packages (default)"
            exit 1
            ;;
    esac
    
    print_status "Package building complete!"
}

main "$@"
