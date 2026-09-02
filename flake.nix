{
  description = "Uncletopia TF2 server cluster - Ansible development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        sourcemod = pkgs.stdenv.mkDerivation {
          pname = "sourcemod";
          version = "1.13.0-git7441";

          src = pkgs.fetchurl {
            url = "https://github.com/alliedmodders/sourcemod/releases/download/1.13.0.7441/sourcemod-1.13.0-git7441-linux.tar.gz";
            sha256 = "sha256-dEvfmAnluzLPC+xmMv6AXUspLoU24hbj/fC1kZVPzCc=";
          };

          dontConfigure = true;
          dontBuild = true;
          dontUnpack = true;

          installPhase = ''
            mkdir -p $out
            tar xzf $src
            mv ./* $out/
          '';

          meta = {
            description = "SourceMod - Source engine scripting and administration";
            homepage = "https://www.sourcemod.net/";
            license = pkgs.lib.licenses.gpl3Plus;
            platforms = pkgs.lib.platforms.linux;
            mainProgram = "spcomp64";
          };
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            ansible
            ansible-lint
            yamllint
            just
            just-lsp
            nix
            nil
            nixd
            just-formatter
            rcon-cli
            nodejs
            sourcemod
          ];

          shellHook = ''
            export PATH=${sourcemod}/addons/sourcemod/scripting:$PATH
            # Recreate the venv if missing, created by a different (stale) Python,
            # or broken — a nixpkgs update can leave an old venv behind.
            if [ ! -x .venv/bin/python ] || \
               [ "$(readlink -f .venv/bin/python)" != "$(readlink -f "$(command -v python)")" ] || \
               ! .venv/bin/python -m pip --version >/dev/null 2>&1; then
              rm -rf .venv
              python -m venv .venv
            fi
            source .venv/bin/activate
            pip install ansible-dev-tools
            # Symlink project .sourcemod to the Nix package root
            if [ -n "$sourcemod" ] && [ ! -L .sourcemod ]; then
              ln -sfn "$sourcemod" .sourcemod
            elif [ -x "$(which spcomp64 2>/dev/null)" ]; then
              ln -sfn "$(dirname "$(which spcomp64)")" .sourcemod
            fi
          '';
        };
      }
    );
}
