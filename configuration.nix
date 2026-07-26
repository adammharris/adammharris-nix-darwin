{ pkgs, ... }:
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
    taps = [
      "jackielii/tap" # for skhd-zig
    ];
    casks = [
      "skhd-zig"
      "karabiner-elements"
      "ghostty"
      "gpg-suite"
      "codex"
      "codex-app"
      "dolphin"
      "google-chrome"
      "markedit"
      "tiled"
    ];
    masApps = {
      "Amphetamine" = 937984704;
      "iMovie" = 408981434;
      "Kindle" = 302584613;
      "Logic Pro" = 634148309;
      "Microsoft Word" = 462054704;
      "Numbers" = 361304891;
      "Obsidian Web Clipper" = 6720708363;
      "Pages" = 361309726;
      "Prime Video" = 545519333;
      "Strongbox" = 897283731;
      "Synctrain" = 6553985316;
      "Tailscale" = 1475387142;
      "TestFlight" = 899247664;
      "uBlock Origin Lite" = 6745342698;
      "Xcode" = 497799835;
    };
  };

  users.users.adamharris = {
    name = "adamharris";
    home = "/Users/adamharris";
    shell = pkgs.nushell;
  };

  programs.tmux = {
    enable = true;
    # This ensures tmux always starts with Nushell
    extraConfig = ''
      set -g default-shell ${pkgs.nushell}/bin/nu
    '';
  };

  # gpg-agent is home-manager's job (services.gpg-agent in adamharris.nix):
  # it owns ~/.gnupg/gpg-agent.conf, the launchd agent, and GPG_TTY for every
  # shell. nix-darwin's programs.gnupg.agent duplicated all of that, which is
  # how enableSSHSupport came to be set in two places and pointed SSH_AUTH_SOCK
  # at a keyless agent from a file only POSIX shells read. One owner now.

  nix.settings.experimental-features = "nix-command flakes";  

  # Enable alternative shell support in nix-darwin.
  programs.fish.enable = true;
  security.pam.services.sudo_local.touchIdAuth = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  system.activationScripts.postActivation.text = ''
    # Clean up the old, stale plist if it exists (pointing to old cellar path)
    if [ -f /Users/adamharris/Library/LaunchAgents/com.jackielii.skhd.plist ]; then
      if grep -q "Cellar/skhd-zig" /Users/adamharris/Library/LaunchAgents/com.jackielii.skhd.plist; then
        echo "Removing stale skhd-zig cellar plist..."
        sudo -u adamharris launchctl unload /Users/adamharris/Library/LaunchAgents/com.jackielii.skhd.plist || true
        rm -f /Users/adamharris/Library/LaunchAgents/com.jackielii.skhd.plist
      fi
    fi

    # Start skhd-zig service if installed
    if [ -x /Applications/skhd.app/Contents/MacOS/skhd ]; then
      echo "Ensuring skhd-zig service is active..."
      sudo -u adamharris /Applications/skhd.app/Contents/MacOS/skhd --start-service || true
      /bin/launchctl kickstart -k "gui/$(/usr/bin/id -u adamharris)/com.jackielii.skhd" || true
    fi
  '';
}
