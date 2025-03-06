{ pkgs ? (import <nixpkgs> {}).pkgs }:
with pkgs;
let
  foundryFHS = buildFHSEnv {
    name = "foundry-env";
    # Provide glibc so that Foundry’s binary finds the proper dynamic linker.
    targetPkgs = pkgs: [ glibc ];
    multiPkgs  = pkgs: [];
    # Mount your Foundry installation (adjust if it isn’t in ~/.foundry)
    extraMounts = [
      {
        hostPath  = "${builtins.getEnv "HOME"}/.foundry";
        guestPath = "/home/foundry/.foundry";
      }
    ];
    # We set runScript to /bin/sh so nothing auto-executes on entry.
    runScript = "/bin/sh";
  };
in mkShell {
  buildInputs = [ foundryFHS ];
  shellHook = ''
    # Fix common library issues (e.g. libstdc++ and libGL).
    export LD_LIBRARY_PATH=${stdenv.cc.cc.lib}/lib/:/run/opengl-driver/lib/
    echo "Entering Foundry FHS environment..."
    # Re-exec the shell using the FHS environment executable.
    exec ${foundryFHS}/bin/foundry-env
  '';
}
