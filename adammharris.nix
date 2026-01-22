{ config, pkgs, ... }:

{
  networking.hostName = "adams-mac";
  networking.computerName = "Adams MacBook";

  nixpkgs.hostPlatform = "aarch64-darwin";
  
  environment.systemPackages =
    [ pkgs.vim
      pkgs.tmux
    ];

  nix.settings.experimental-features = "nix-command flakes";
  services.nix-daemon.enable = true;
  

  # Enable alternative shell support in nix-darwin.
  programs.fish.enable = true;
  security.pam.enableSudoTouchIdAuth = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;
}
