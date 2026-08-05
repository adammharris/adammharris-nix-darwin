{ config, lib, pkgs, inputs, osConfig, ... }:
{  
  home.username = "adamharris";
  home.homeDirectory = "/Users/adamharris";

  # Do not change this unless you know what you are doing. 
  # It's used for state versioning.
  home.stateVersion = "23.11";

  home.sessionVariables = {
    EDITOR = "hx";
    JOURNAL = "${config.home.homeDirectory}/Desktop/Adam's Archive";
    CARGO_HOME = "${config.home.homeDirectory}/.local/share/cargo";
  };

  # Declared here so zsh/bash/fish share one PATH definition rather than fish's
  # unmanaged `fish_user_paths`. nushell can't read this at runtime, but its
  # extraEnv below is generated from this same list, so it stays in sync.
  home.sessionPath = [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.local/share/cargo/bin"
  ];

  # Belt-and-braces since the ssh-agent fix below (cargo's native transport
  # works again now that a real agent holds the key). Still worth keeping:
  # shelling out to git makes cargo honour ~/.ssh/config and the global
  # url.insteadOf rewrite, which its built-in transport ignores outright.
  # Written to both paths so it applies even when CARGO_HOME isn't set.
  home.file =
    let
      cargoConfig = {
        text = ''
          [net]
          git-fetch-with-cli = true
        '';
      };
    in
    {
      ".local/share/cargo/config.toml" = cargoConfig;
      ".cargo/config.toml" = cargoConfig;
    };

  # Fish auto-generates completions from man pages, which force-enables
  # programs.man.generateCaches (the slow "building man-cache" mandb step
  # on every rebuild). We don't need the apropos/man -k index, so turn it
  # off while keeping fish's completions.
  programs.man.generateCaches = false;

  # Karabiner is set up to make caps lock a super modifer
  xdg.configFile."skhd/skhdrc".text = ''
    shift + ctrl + alt + cmd - s : ^open /Applications/Synctrain.app
    shift + ctrl + alt + cmd - t : ^open /Applications/Tailscale.app
    shift + ctrl + alt + cmd - a : ^open /Applications/Claude.app
    shift + ctrl + alt + cmd - g : ^open /Applications/Ghostty.app
    shift + ctrl + alt + cmd - b : ^open /Applications/Safari.app
    shift + ctrl + alt + cmd - d : ^open /Applications/Diaryx.app
    shift + ctrl + alt + cmd - m : ^open /System/Applications/Mail.app
    shift + ctrl + alt + cmd - p : ^open "/Applications/Prism Launcher.app"
    shift + ctrl + alt + cmd - z : ^open /Applications/Zed.app
    shift + ctrl + alt + cmd - f : ^open ~
  '';

  xdg.configFile."karabiner/karabiner.json" = {
    text = ''
      {
        "profiles": [
          {
            "name": "Default profile",
            "selected": true,
            "complex_modifications": {
              "parameters": {
                "basic.to_if_alone_timeout_milliseconds": 1000,
                "basic.to_if_held_down_threshold_milliseconds": 500,
                "basic.to_delayed_action_delay_milliseconds": 500,
                "basic.simultaneous_threshold_milliseconds": 50,
                "mouse_motion_to_scroll.speed": 100
              },
              "rules": [
                {
                  "description": "Caps Lock to Hyper (if held) / Escape (if alone)",
                  "manipulators": [
                    {
                      "type": "basic",
                      "from": {
                        "key_code": "caps_lock",
                        "modifiers": { "optional": ["any"] }
                      },
                      "to": [
                        {
                          "key_code": "left_shift",
                          "modifiers": ["left_command", "left_control", "left_option"]
                        }
                      ],
                      "to_if_alone": [
                        { "key_code": "escape" }
                      ]
                    }
                  ]
                }
              ]
            },
            "devices": [],
            "fn_function_keys": [],
            "simple_modifications": [],
            "virtual_hid_keyboard": {
              "country_code": 0,
              "keyboard_type": "ansi",
              "keyboard_type_v2": "ansi",
              "mouse_key_milliseconds_interval": 10
            }
          }
        ]
      }
    '';
    force = true;
  };
  # The Fish configuration
  programs.fish = {
    enable = true;
    shellAbbrs = {
      rebuild = "sudo darwin-rebuild switch --flake ~/.config/nix-darwin#adams-mac";
      e = "hx";
      config = "cd /Users/adamharris/.config/nix-darwin && $EDITOR adamharris.nix";
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      lsa = "ls -a";
      gs = "git status";
      "ga." = "git add .";
      dx = "diaryx";
      zigstall = "zig build -Doptimize=ReleaseFast --prefix ~/.local";
      timestamp = "date +%Y-%m-%dT%H:%M:%S%:z";
      today = ''set -l y (date +%Y) && set -l m (date +%m) && set -l d (date +%d) && prov edit $JOURNAL/$(prov -C "$JOURNAL" new "$y-$m-$d" --in "@Daily/$y/$m" -p --as "Daily/$y/$m/$y-$m-$d.md")'';
    };
    shellAliases = {
      ls = "eza -lh --group-directories-first --icons=auto";
      lt = "eza --tree --level=2 --long --icons --git";
      lta = "lt -a";
      timeout = "uutils-timeout";
      date = "uutils-date";
    };
    functions = {
      fish_greeting = {
        description = "Greeting message on shell startup";
        body = ''
          set hour (date +%H)

          if test $hour -lt 12
              set time_msg "Good morning"
          else if test $hour -lt 18
              set time_msg "Good afternoon"
          else
              set time_msg "Good evening"
          end

          set_color cyan
          echo "$time_msg, $USER."

          set_color blue
          echo "Today's tasks:"
          set year (date +%Y)
          set month (date +%m)
          fig get "$JOURNAL/Daily/$year/$month/$year-$month-$(date +%d).md" todo 2> /dev/null || echo "None for today!"
        '';
      };
    };
  };

  programs.bash = {
    enable = true;
  };

  programs.zsh = {
    enable = true;
  };

  programs.nushell = {
    enable = true;

    # nushell is our login shell but sources neither /etc/zshenv (where
    # nix-darwin's set-environment defines PATH) nor home.sessionPath, so both
    # are reconstructed here. Derived from the same two options the other
    # shells get, rather than hand-copied, so this can't drift again — and in
    # the same order zsh ends up with (sessionPath prepended onto systemPath).
    extraEnv =
      let
        # environment.systemPath is a ":"-joined string containing a literal
        # $HOME for zsh to expand; nushell has no such expansion, so do it here.
        systemPath = lib.splitString ":" (
          builtins.replaceStrings [ "$HOME" ] [ config.home.homeDirectory ]
            osConfig.environment.systemPath
        );
        paths = config.home.sessionPath ++ systemPath;
      in
      ''
        $env.PATH = ($env.PATH
          | split row (char esep)
          | prepend [
              ${lib.concatMapStringsSep "\n      " (p: ''"${p}"'') paths}
            ]
          | uniq)
      '';

    environmentVariables = {
      JOURNAL = "${config.home.homeDirectory}/Desktop/Adam's Archive";
      # Repeated from home.sessionVariables, which nushell doesn't read.
      CARGO_HOME = "${config.home.homeDirectory}/.local/share/cargo";
    };

    shellAliases = {
      timeout = "uutils-timeout";
      udate = "uutils-date";
    };

    settings = {
      show_banner = false;
      abbreviations = {
        rebuild = "sudo darwin-rebuild switch --flake ~/.config/nix-darwin#adams-mac";
        e = "hx";
        config = "cd /Users/adamharris/.config/nix-darwin; hx adamharris.nix";
        gs = "git status";
        "ga." = "git add .";
        dx = "diaryx";
        zigstall = "zig build -Doptimize=ReleaseFast --prefix ~/.local";
        timestamp = "uutils-date +%Y-%m-%dT%H:%M:%S%:z";
        today = "today";
      };
    };

    extraConfig = ''
      # Re-implementation of the GPG_TTY half of home-manager's gpg-agent
      # nushell integration (services.gpg-agent.enableNushellIntegration),
      # guarded so it doesn't abort non-interactive `nu -c` invocations when
      # there's no tty. (There's no SSH_AUTH_SOCK half any more - ssh support
      # is off, so nothing overrides launchd's macOS ssh-agent socket.)
      try {
        $env.GPG_TTY = (tty)
        ^${pkgs.gnupg}/bin/gpg-connect-agent --quiet updatestartuptty /bye | ignore
      }

      def today [] {
        let y = (date now | format date "%Y")
        let m = (date now | format date "%m")
        let d = (date now | format date "%d")
        let entry = (prov -C $env.JOURNAL new $"($y)-($m)-($d)" --in $"@Daily/($y)/($m)" -p --as $"Daily/($y)/($m)/($y)-($m)-($d).md")
        prov edit $"($env.JOURNAL)/($entry)"
      }
      def greet [] {
        let hour = (date now | format date "%H" | into int)
        let time_msg = if $hour < 12 { "Good morning" } else if $hour < 18 { "Good afternoon" } else { "Good evening" }
        print $"(ansi cyan)($time_msg), ($env.USER).(ansi reset)"
        print $"(ansi blue)Today's tasks:(ansi reset)"
        let year = (date now | format date "%Y")
        let month = (date now | format date "%m")
        let day = (date now | format date "%d")
        let today_file = $"($env.JOURNAL)/Daily/($year)/($month)/($year)-($month)-($day).md"
        try { fig get $today_file todo err> /dev/null } catch { print "None for today!" }
      }
      if $nu.is-login { greet }
    '';
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Adam Harris";
        email = "adam@diaryx.org";
      };
      url = {
        "git@github.com:" = {
          insteadOf = "https://github.com/";
        };
      };
      push.autoSetupRemote = true;
    };
    signing = {
      key = "6D8BDF997ED474FD";
      signByDefault = true;
    };
  };

  programs.ghostty = {
    enable = true;
    package = null;
    settings = {
      theme = "light:Gruvbox Light Hard,dark:Gruvbox Dark Hard";
      font-size = 13;
      unfocused-split-opacity = 1.0;
    };
  };

  # Helix (25.07) has no OS appearance detection, so it can't do what ghostty's
  # `light:…,dark:…` theme does above. Instead the theme is a fixed name, "auto",
  # backed by a one-line mutable file (~/.config/helix/themes/auto.toml) that
  # only `inherits` the real gruvbox variant. The launchd agent below rewrites
  # that file when macOS flips appearance; helix re-reads theme files on
  # SIGUSR1, so running editors switch in place. Deliberately not managed by
  # home-manager: nix-managed files are read-only symlinks into the store.
  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      theme = "auto";
      # Word count of the selection.
      keys.normal.space."A-w" = "@<A-|>tee /tmp/helix-wc.file<ret>:sh cat /tmp/helix-wc.file | wc -w<ret>";
    };
    languages = {
      language-server.rust-analyzer = {
        command = "rust-analyzer";
        environment = {
          CARGO_TARGET_DIR = "target/rust-analyzer";
        };
        config = {
          cargo = {
            targetDir = true;
          };
          check = {
            workspace = false;
            allTargets = false;
          };
        };
      };
    };
  };

  # dark-mode-notify runs its argument once at load, on every appearance change,
  # and on wake, with DARKMODE=1/0 in the environment.
  launchd.agents.helix-theme-sync = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.dark-mode-notify}/bin/dark-mode-notify"
        (toString (pkgs.writeShellScript "helix-theme-sync" ''
          set -eu
          themes="$HOME/.config/helix/themes"
          mkdir -p "$themes"

          case "''${DARKMODE:-}" in
            1) base=gruvbox_dark_hard ;;
            0) base=gruvbox_light_hard ;;
            # Fallback for running the script by hand, outside the agent.
            *) if [ "$(/usr/bin/defaults read -g AppleInterfaceStyle 2>/dev/null || true)" = "Dark" ]
               then base=gruvbox_dark_hard
               else base=gruvbox_light_hard
               fi ;;
          esac

          # Unique temp name: the agent fires this on load, on appearance change
          # and on wake, and those can overlap.
          tmp="$themes/.auto.toml.$$"
          trap 'rm -f "$tmp"' EXIT
          printf 'inherits = "%s"\n' "$base" > "$tmp"
          mv "$tmp" "$themes/auto.toml"

          # Tell any running helix to re-read its config and theme.
          /usr/bin/pkill -USR1 -x hx || true
        ''))
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/helix-theme-sync.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/helix-theme-sync.log";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableFishIntegration = true;
    enableNushellIntegration = true;
  };

  programs.tmux = {
    enable = true;
    mouse = true;
    prefix = "C-Space";
    keyMode = "vi";
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 50000;
    terminal = "tmux-256color";
    resizeAmount = 5;

    extraConfig = ''
      # Prefix
      set -g prefix2 C-b
      bind C-Space send-prefix

      # Reload config
      bind q source-file ~/.config/tmux/tmux.conf

      # General
      set -g default-terminal "tmux-256color"
      set -ga terminal-overrides ",xterm-256color:Tc"
      setw -g pane-base-index 1
      set -g renumber-windows on
      set -g focus-events on
      set -g set-clipboard on
      set -g allow-passthrough on
      setw -g aggressive-resize on
      set -g detach-on-destroy off
    '';
  };
  
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    enableNushellIntegration = true;
    
    settings = {
      add_newline = true;
      command_timeout = 200;
      format = "[$directory$git_branch$git_status]($style)$character";

      character = {
        error_symbol = "[×](bold_cyan)";
        success_symbol = "[❯](bold_cyan)";
      };

      directory = {
        truncation_length = 2;
        truncation_symbol = "…/";
        repo_root_style = "bold cyan";
        repo_root_format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) ";
      };

      git_status = {
        format = "[$all_status]($style)";
        style = "cyan";
        ahead = "⇡\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        behind = "⇣\${count}";
        conflicted = " ";
        up_to_date = "✓ ";
        untracked = "? ";
        modified = "● ";
        stashed = "";
        staged = "";
        renamed = "";
        deleted = "";
      };
    };
  };

  # Packages specific to your user
  home.packages = [
    pkgs.ripgrep
    pkgs.bat
    pkgs.eza
    pkgs.gnupg
    pkgs.pinentry_mac
    pkgs.gh
    pkgs.fzf
    pkgs.nodejs_24
    pkgs.bun
    pkgs.nushell
    pkgs.fd
    pkgs.ffmpeg
    pkgs.uv
    pkgs.nil
    pkgs.nixd
    pkgs.rustup
    pkgs.openssl_oqs
    pkgs.presenterm
    pkgs.zig
    pkgs.tree
    pkgs.wasmtime
    pkgs.uutils-coreutils

    # Real `timeout` binary on PATH (~/.nix-profile/bin), independent of any
    # shell rc file — unlike the zsh/bash aliases above, this also resolves
    # in non-interactive/no-rc shells (e.g. Claude Code's sandboxed Bash tool).
    (pkgs.writeShellScriptBin "timeout" ''exec ${pkgs.uutils-coreutils}/bin/uutils-timeout "$@"'')

    inputs.fig.packages.${pkgs.system}.default
    inputs.twig.packages.${pkgs.system}.default
    inputs.prov.packages.${pkgs.system}.default
    inputs.moid.packages.${pkgs.system}.default
  ];

  # Replaces the hand-maintained ~/.ssh/config (whose showbrain/vps/vps-t/byu
  # hosts are all retired). AddKeysToAgent + UseKeychain (an Apple-ssh option;
  # /usr/bin/ssh is what's on PATH) unlock the key once and persist the
  # passphrase in the login Keychain, which is what gives us a working agent.
  programs.ssh = {
    enable = true;
    # Opting out of home-manager's legacy implicit defaults (deprecated, and
    # they emit a build warning); nothing below relies on them.
    enableDefaultConfig = false;

    settings = {
      nas = {
        HostName = "harris-nas.tail581ab2.ts.net";
        # Quoted because the account name contains a space - ssh_config splits
        # unquoted values on whitespace and would read the user as "Adam".
        User = ''"Adam Harris"'';
        IdentityFile = "~/.ssh/id_ed25519";
      };

      # Last so the specific blocks above win any overlapping directive.
      "*" = lib.hm.dag.entryAfter [ "nas" ] {
        AddKeysToAgent = "yes";
        UseKeychain = "yes";
      };
    };
  };

  programs.gpg = {
    enable = true;
    # Ported from the previously hand-maintained ~/.gnupg/gpg.conf so
    # home-manager can manage the file without losing these settings.
    settings = {
      cert-digest-algo = "SHA512";
      default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
      display-charset = "utf-8";
      keyid-format = "0xlong";
      list-options = "show-uid-validity";
      no-comments = true;
      no-emit-version = true;
      no-symkey-cache = true;
      personal-cipher-preferences = "AES256 AES192 AES";
      personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
      personal-digest-preferences = "SHA512 SHA384 SHA256";
      require-cross-certification = true;
      s2k-cipher-algo = "AES256";
      s2k-digest-algo = "SHA512";
      verify-options = "show-uid-validity";
      with-fingerprint = true;
      default-key = "C55D3FA0A249A3D87C9608BE6D8BDF997ED474FD";
    };
  };

  services.gpg-agent = {
    # Ported from the previously hand-maintained ~/.gnupg/gpg-agent.conf.
    enable = true;
    # SSH is handled by macOS's ssh-agent (see programs.ssh). This was true,
    # but sshcontrol is empty and the GPG key has no authentication subkey,
    # so it claimed SSH_AUTH_SOCK for an agent that could never serve a key -
    # which is what broke `cargo fetch` over ssh://. gpg-agent still signs
    # git commits. The *Ssh cache TTLs went with it; they did nothing here.
    enableSshSupport = false;
    defaultCacheTtl = 600;
    maxCacheTtl = 7200;
    # `grab` is already emitted by home-manager's grabKeyboardAndMouse (default true).
    enableFishIntegration = true;
    # enableNushellIntegration explicitly false (home-manager's global
    # home.shell.enableNushellIntegration now defaults to true since nushell
    # is the system shell, so merely omitting this isn't enough to disable
    # it). The generated snippet does `$env.GPG_TTY = (tty)` unconditionally,
    # and the `tty` external command exits non-zero when there's no
    # controlling terminal. That aborts *any* non-interactive `nu -c ...`
    # invocation (e.g. skhd-zig's login-shell PATH capture, run as part of
    # every keypress dispatch), which is why skhd keybinds silently stopped
    # firing after the login shell became nushell. We reimplement the same
    # behavior guarded with try/catch below instead.
    enableNushellIntegration = false;
  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;
}
