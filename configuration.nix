{ config, pkgs, ... }:

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
      pkgs.tmux
      pkgs.fish
    ];

  
  homebrew = {
    enable = true;
    casks = [
      "ghostty"
    ];
  };

  programs.ghostty = {
    enable = true;
    settings = {
      theme = "Gruvbox Dark Hard"; # Example theme
      font-size = 13;      
    };
  };


    

  users.users.adammharris = {
    name = "adammharris";
    shell = pkgs.fish;
  };

  nix.settings.experimental-features = "nix-command flakes";  

  # Enable alternative shell support in nix-darwin.
  programs.fish.enable = true;
  security.pam.services.sudo_local.touchIdAuth = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;
}
