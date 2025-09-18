{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    zig
    zls  # Zig Language Server for development
  ];

  shellHook = ''
    echo "Timbre development environment"
    echo "Zig version: $(zig version)"
    echo ""
    echo "Available commands:"
    echo "  zig build         - Build the project"
    echo "  zig build test    - Run tests"
    echo "  zig build run     - Build and run"
    echo ""
  '';
}
