{ pkgs, ... }:
{
  networking.hostName = "adams-mac";
  networking.computerName = "Adams MacBook";

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.primaryUser = "adamharris";
  system.defaults = {
    dock.autohide = true;
    # Leave the global "use F1-F12 as standard function keys" toggle OFF.
    # Karabiner's fn_function_keys (adamharris.nix) does the per-key work:
    # F3-F9 become plain function keys, F1/F2 stay brightness and
    # F10/F11/F12 stay mute/volume. Flipping this to true would invert all
    # twelve at once and fight that mapping.
    NSGlobalDomain."com.apple.keyboard.fnState" = false;
  };
  environment.systemPackages =
    [ pkgs.vim
      pkgs.fish
    ];

  
  homebrew = {
    enable = true;
    taps = [
      "jackielii/tap" # for skhd-zig
      "diaryx-org/tap"
    ];
    casks = [
      "skhd-zig"
      "karabiner-elements"
      "ghostty"
      "gpg-suite"
      "codex"
      "dolphin"
      "google-chrome"
      "markedit"
      "tiled"
      "helium-browser"
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

    # Start skhd-zig service if installed.
    #
    # `-H` is load-bearing. Activation runs as root with HOME=/var/root, and
    # macOS sudoers preserves HOME across `sudo -u`, so skhd resolved its
    # config as /var/root/.config/skhd/skhdrc and printed "could not read
    # config skhdrc: FileNotFound - skipping grabber check" on every rebuild.
    # The daemon was never affected - launchd runs it in the user's gui domain
    # with the right HOME - but --start-service does two things, and the
    # second one (read the config, install skhd-grabber if a caps_lock-class
    # rule needs it) was silently skipped rather than answered. With -H it
    # reads the real skhdrc and says "skhd-grabber not needed", which is the
    # true answer here because Karabiner does the caps lock work.
    if [ -x /Applications/skhd.app/Contents/MacOS/skhd ]; then
      echo "Ensuring skhd-zig service is active..."
      sudo -H -u adamharris /Applications/skhd.app/Contents/MacOS/skhd --start-service || true
      /bin/launchctl kickstart -k "gui/$(/usr/bin/id -u adamharris)/com.jackielii.skhd" || true
    fi
  '';
}
