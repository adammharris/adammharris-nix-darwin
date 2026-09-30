{ pkgs, ... }:
{
  networking.hostName = "adams-mac";
  networking.computerName = "Adams MacBook";

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.primaryUser = "adamharris";
  time.timeZone = "America/Denver";

  # Everything here was read back from `defaults read` on 2026-09-14, so the
  # first switch is a no-op; the point is that a fresh machine ends up the
  # same. Values left at the macOS default are not listed.
  system.defaults = {
    dock = {
      autohide = true;
      tilesize = 50;
      # Don't reorder Spaces by most recent use - cmd-N (aerospace habit)
      # should land on the same workspace every time.
      mru-spaces = false;
      # 1 = no action. The bottom-right corner is where the cursor ends up
      # when reaching for the trackpad's edge, so it must do nothing.
      wvous-br-corner = 1;
    };

    finder = {
      ShowPathbar = true;
      FXPreferredViewStyle = "Nlsv"; # list view
      NewWindowTarget = "Recents";
      ShowExternalHardDrivesOnDesktop = true;
    };

    NSGlobalDomain = {
      # Leave the global "use F1-F12 as standard function keys" toggle OFF.
      # Karabiner's fn_function_keys (adamharris.nix) does the per-key work:
      # F3-F9 become plain function keys, F1/F2 stay brightness and
      # F10/F11/F12 stay mute/volume. Flipping this to true would invert all
      # twelve at once and fight that mapping.
      "com.apple.keyboard.fnState" = false;

      # Fastest repeat System Settings offers; 25/2 are the slider's ends.
      InitialKeyRepeat = 25;
      KeyRepeat = 2;

      # Smart quotes/dashes turn `--flag` and "quoted" into typographic
      # garbage in every text field that isn't a code editor.
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;

      AppleShowScrollBars = "Always";
      # Light/dark follows the time of day; ghostty's `light:…,dark:…` theme
      # and the helix-theme-sync agent (adamharris.nix) both key off this.
      AppleInterfaceStyleSwitchesAutomatically = true;
      "com.apple.trackpad.scaling" = 0.6875;
    };

    trackpad = {
      Clicking = false;           # no tap-to-click
      TrackpadRightClick = true;  # two-finger secondary click
    };

    menuExtraClock = {
      ShowSeconds = true;
      ShowDate = 0; # only when space allows
    };

    # The window manager is skhd + Karabiner, so every macOS tiling gesture
    # is off: they fight the keyboard-driven layout.
    WindowManager = {
      EnableStandardClickToShowDesktop = true;
      EnableTilingByEdgeDrag = false;
      EnableTopTilingByEdgeDrag = false;
      EnableTilingOptionAccelerator = false;
      EnableTiledWindowMargins = false;
    };

    universalaccess.reduceMotion = false;
    ActivityMonitor.ShowCategory = 100; # all processes

    CustomUserPreferences = {
      "com.apple.AdLib".allowApplePersonalizedAdvertising = false;
    };
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
    # Everything below is what `brew list` reported on 2026-09-14, minus what
    # moved to home.packages (pandoc, fastfetch, yazi, resvg, qemu). No
    # onActivation.cleanup: brew bundle's cleanup now runs `mas uninstall`
    # for any App Store app not in masApps, and Xcode is deliberately not
    # declared there (the beta comes from developer.apple.com, and a 10 GB
    # download is not something a rebuild should be allowed to trigger).
    brews = [
      "bun"
      # The iOS toolchain. Kept in brew rather than nixpkgs on purpose - it
      # is a working flow and xcodegen/cocoapods/ios-deploy/libimobiledevice
      # expect each other at brew paths.
      "asc"
      "cocoapods"
      "ios-deploy"
      "libimobiledevice"
      "mint"
      "xcodegen"
      "container"
      "vite-plus"
    ];
    casks = [
      "skhd-zig"
      "karabiner-elements"
      "ghostty"
      "google-chrome"
      "helium-browser"
      "claude"
      "codex"
      "fuse-t"
      "grandperspective"
      "homebrew-app"
      "imazing"
      "obs"
      "obsidian"
      "prismlauncher"
      # The stable cask is 4.x; the 5.x that was installed by hand is what
      # the beta cask tracks.
      "utm@beta"
      "vorssaint"
      "zed"
      "zoom"
    ];
    # `mas` itself is in home.packages so `mas list` works from a shell;
    # nix-darwin already puts pkgs.mas on PATH for brew bundle regardless.
    # Xcode is not here - see the note above brews.
    #
    # Diaryx (6794781527) is not here either: /Applications/Diaryx.app is the
    # TestFlight build, which runs ahead of the store. mas finds installed
    # apps through Spotlight's App Store metadata, which a TestFlight build
    # has none of, so it decides Diaryx is missing, fetches the store
    # version, and `installer` refuses to downgrade over the newer one - a
    # failed brew bundle, and with `set -e` in the activation script, a
    # rebuild that stops before home-manager. Declare it again only once the
    # store copy is the one that should be on disk.
    masApps = {
      "Obsidian Web Clipper" = 6720708363;
      "Reeder" = 6475002485;
      "Slack" = 803453959;
      "Strongbox" = 897283731;
      "Tailscale" = 1475387142;
      "TestFlight" = 899247664;
      "uBlock Origin Lite" = 6745342698;
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

  nix.settings.experimental-features = "nix-command flakes";

  # linux-builder delegates aarch64-linux derivations to a managed NixOS VM,
  # so aarch64-darwin can build Linux closures (e.g. the nixos-apple-silicon
  # installer ISO). @admin is required: without it the daemon refuses to use
  # the builder ("cannot build on ssh-ng://builder@linux-builder ... not
  # trusted") and falls back to failing the build outright.
  nix.settings.trusted-users = [ "root" "@admin" ];

  # Requires nixpkgs >= 2026-06-29 (PR #536526, "qemu: depend on apple-sdk_15").
  # Older nixpkgs builds qemu against apple-sdk 14.4, and its HVF backend then
  # aborts at vcpu init on macOS >= 15.2:
  #   hvf_arch_init_vcpu: assertion failed:
  #   (HV_SYS_REG_SMCR_EL1 == KVMID_TO_HVF(KVMID_AA64_SYS_REG64(3, 0, 1, 2, 6)))
  nix.linux-builder = {
    enable = true;
    ephemeral = true;
    maxJobs = 4;
    config = {
      virtualisation = {
        cores = 8;
        darwin-builder = {
          diskSize = 60 * 1024;   # MB - the Asahi kernel build needs room
          memorySize = 8 * 1024;  # MB
        };
      };
    };
  };

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
