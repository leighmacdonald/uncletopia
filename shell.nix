let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-25.11";

  pkgs = import nixpkgs {
    config = { };
    overlays = [ ];
  };
in

pkgs.mkShellNoCC {
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
  ];
}
