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

  programs.gnupg.agent = {
    enable = true;
    # System-level twin of services.gpg-agent.enableSshSupport in
    # adamharris.nix, and the one that actually bit: it exports SSH_AUTH_SOCK
    # from nix-darwin's set-environment, which every POSIX-ish shell sources
    # (fish via /etc/fish/nixos-env-preinit.fish), pointing them at a gpg-agent
    # holding no keys. nushell never sources it, which is why the two shells
    # disagreed. SSH is macOS ssh-agent's job now - see programs.ssh.
    enableSSHSupport = false;
  };

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
