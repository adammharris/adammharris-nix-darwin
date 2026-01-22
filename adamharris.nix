{ pkgs, ... }: {
  home.username = "adamharris";
  home.homeDirectory = "/Users/adamharris";

  # Do not change this unless you know what you are doing. 
  # It's used for state versioning.
  home.stateVersion = "23.11"; 

  # The Fish configuration
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # Optional: Add any extra shell init here
    '';
    shellAliases = {
      rebuild = "darwin-rebuild switch --flake ~/.config/nix-darwin#adams-mac";
      e = "hx";
      shellconfig = "$EDITOR ~/.config/fish/config.fish";
      userconfig = "cd /Users/adamharris/.config/nix-dfarwin && $EDITOR adamharris.nix";
    };
  };

  # The Ghostty configuration
  programs.ghostty = {
    enable = true;
    settings = {
      theme = "catppuccin-mocha";
      font-family = "JetBrainsMono Nerd Font";
      font-size = 13;
      command = "${pkgs.fish}/bin/fish";
    };
  };

  # Packages specific to your user
  home.packages = [
    pkgs.ripgrep
    pkgs.bat
    pkgs.helix
    pkgs.eza
    pkgs.zoxide
  ];

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;
}
