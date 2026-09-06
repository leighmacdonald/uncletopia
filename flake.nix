{
  description = "Uncletopia TF2 server cluster - Ansible environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
    nix-sourcemod.url = "github:leighmacdonald/nix-sourcemod";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      nix-sourcemod,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        sourcemod = nix-sourcemod.packages.${system}.sourcemod_stable;
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
