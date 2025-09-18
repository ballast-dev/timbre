{ lib
, stdenv
, fetchFromGitHub
, zig
}:

stdenv.mkDerivation rec {
  pname = "timbre";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "ballast-dev";
    repo = "timbre";
    rev = "v${version}";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Update with actual hash
  };

  nativeBuildInputs = [
    zig
  ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    
    export HOME=$TMPDIR
    zig build --release=fast --prefix $out
    
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    
    # Binary is already installed by zig build --prefix
    # Install configuration file
    mkdir -p $out/etc/timbre
    cp cfg/timbre.toml $out/etc/timbre/
    
    # Install man page
    mkdir -p $out/share/man/man1
    cp pkg/debian/timbre.1 $out/share/man/man1/
    
    runHook postInstall
  '';

  doCheck = true;

  checkPhase = ''
    runHook preCheck
    zig build test
    runHook postCheck
  '';

  meta = with lib; {
    description = "Smart log filtering and categorization tool";
    longDescription = ''
      Timbre is a high-performance log processing tool that filters and categorizes
      log output using regex patterns. It provides smart log filtering with regex
      support, organized log categorization into separate files, TOML configuration
      support, and detailed diagnostics.
    '';
    homepage = "https://github.com/ballast-dev/timbre";
    license = licenses.mit;
    maintainers = with maintainers; [ ]; # Add maintainer handles here
    platforms = platforms.unix;
    mainProgram = "timbre";
  };
}
