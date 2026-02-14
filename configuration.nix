{ config, pkgs, inputs, ... }:
let
  scripts = import ./scripts/new-window.nix { inherit pkgs; };
in
{
  networking.hostName = "adams-mac";
  networking.computerName = "Adams MacBook";

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.primaryUser = "adamharris";
  system.defaults = {
    dock.autohide = true;
  };
  environment.systemPackages =
    [ pkgs.vim
      pkgs.fish
    ];

  
  homebrew = {
    enable = true;
    casks = [
      "ghostty@tip"
      "gpg-suite"
      "amethyst"
      "codex"
    ];
  };

  services.skhd = {
    enable = true;
    skhdConfig = ''
      alt - return : ${scripts.new-window-script}/bin/new-window Ghostty
      alt - b      : ${scripts.new-window-script}/bin/new-window Orion
    '';
  };

  users.users.adamharris = {
    name = "adamharris";
    home = "/Users/adamharris";
    shell = pkgs.fish;
  };

  programs.tmux = {
    enable = true;
    # This ensures tmux always starts with Fish
    extraConfig = ''
      set -g default-shell ${pkgs.fish}/bin/fish
    '';
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  nix.settings.experimental-features = "nix-command flakes";  

  # Enable alternative shell support in nix-darwin.
  programs.fish.enable = true;
  security.pam.services.sudo_local.touchIdAuth = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;
}
