{ pkgs, inputs, ... }:
{
  home.username = "adamharris";
  home.homeDirectory = "/Users/adamharris";

  # Do not change this unless you know what you are doing. 
  # It's used for state versioning.
  home.stateVersion = "23.11";

  # The Fish configuration
  programs.fish = {
    enable = true;
    shellAbbrs = {
      rebuild = "sudo darwin-rebuild switch --flake ~/.config/nix-darwin#adams-mac";
      e = "hx";
      config = "cd /Users/adamharris/.config/nix-darwin && $EDITOR adamharris.nix";
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Adam Harris";
        email = "adam@diaryx.org";
      };
    };
    signing = {
      key = "6D8BDF997ED474FD";
      signByDefault = true;
    };
  };

  # The Ghostty configuration
  programs.ghostty = {
    enable = true;
    package = null;
    settings = {
      theme = "Gruvbox Dark Hard";
      font-size = 13;
    };
  };

  programs.helix = {
    enable = true;
    defaultEditor = true;
  };

  # Packages specific to your user
  home.packages = [
    pkgs.ripgrep
    pkgs.bat
    pkgs.eza
    pkgs.zoxide
    pkgs.gnupg
    pkgs.pinentry_mac
    inputs.diaryx.packages.${pkgs.system}.default
    pkgs.gh
    pkgs.bun
    pkgs.rustup
  ];

  programs.gpg = {
    enable = true;
  };

  services.gpg-agent = {
    enable = true;
    enableFishIntegration = true;
  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;
}
