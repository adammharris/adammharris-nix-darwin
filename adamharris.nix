{ config, lib, pkgs, inputs, osConfig, ... }:
let
  # $EDITOR is one command, so "a different editor per filetype" has to be a
  # dispatcher: this reads the first filename it is handed, picks an editor from
  # the extension and execs it with the original arguments untouched. Anything
  # unrecognised — and anything with no filename at all, like the COMMIT_EDITMSG
  # git hands its editor — falls through to helix, which stays the general case.
  editor = pkgs.writeShellScriptBin "edit" ''
    hx="${config.programs.helix.package}/bin/hx"
    # First argument that is neither a flag (`-w`) nor a line jump (`+42`).
    file=""
    for arg in "$@"; do
      case "$arg" in
        -* | +*) ;;
        *)
          file="$arg"
          break
          ;;
      esac
    done

    # Extension of the basename, lowercased. The `?*.*` guard means a leading
    # dot doesn't count, so `.gitignore` is extensionless and `.config.toml`
    # is still toml.
    base="''${file##*/}"
    ext=""
    case "$base" in
      ?*.*) ext=$(printf '%s' "''${base##*.}" | tr '[:upper:]' '[:lower:]') ;;
    esac

    case "$ext" in
      md | markdown | dj | djot) chosen="leaf" ;;
      json | toml | figl | yaml | yml) chosen="flower" ;;
      *) chosen="$hx" ;;
    esac

    command -v "$chosen" >/dev/null 2>&1 || chosen="$hx"
    exec "$chosen" "$@"
  '';

  # dx, diaryx-org's tool, is a nushell module in the org checkout. Both the
  # config that imports it and the activation that writes that import need to
  # agree on where the two files are, so the paths are named once here.
  dxModule = "${config.home.homeDirectory}/diaryx/devtools/dx.nu";
  dxImportDir = "${config.home.homeDirectory}/.local/state/nushell";
  dxImport = "${dxImportDir}/dx.nu";

  # The public half of ~/.ssh/id_ed25519, which also signs commits. Named once
  # because git needs it twice: as the signing key and in allowed_signers.
  sshSigningKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMlwTKC6z7VudgXylpTy1yEmup4TjOJKHeVRH/EygwcW";
in
{
  home.username = "adamharris";
  home.homeDirectory = "/Users/adamharris";

  # Do not change this unless you know what you are doing. 
  # It's used for state versioning.
  home.stateVersion = "23.11";

  home.sessionVariables = {
    # Not `hx`: see the dispatcher in the `let` block above. VISUAL is set too
    # because programs.helix.defaultEditor used to set both, and tools that
    # prefer VISUAL would otherwise still go straight to helix.
    EDITOR = lib.getExe editor;
    VISUAL = lib.getExe editor;
    JOURNAL = "${config.home.homeDirectory}/Desktop/adams-archive";
    CARGO_HOME = "${config.home.homeDirectory}/.local/share/cargo";
  };

  # Declared here so zsh/bash/fish share one PATH definition rather than fish's
  # unmanaged `fish_user_paths`. nushell can't read this at runtime, but its
  # extraEnv below is generated from this same list, so it stays in sync.
  #
  # ~/.local/bin comes first, and that ordering is load-bearing: it is where
  # `dx use` links whichever build of an org CLI should answer right now, and
  # the whole point is that it wins over the brew formula underneath. It used to
  # sit after /opt/homebrew/bin, which made `dx use` a silent no-op — the link
  # was made, the tool reported the channel, and brew's binary still ran.
  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "${config.home.homeDirectory}/.local/share/cargo/bin"
  ];

  home.file =
    let
      cargoConfig = {
        text = ''
          [net]
          git-fetch-with-cli = true

          [profile.dev]
          debug = "line-tables-only"

          [profile.dev.package."*"]
          debug = false
        '';
      };
    in
    {
      # Belt-and-braces since the ssh-agent fix below (cargo's native transport
      # works again now that a real agent holds the key). Still worth keeping:
      # shelling out to git makes cargo honour ~/.ssh/config and the global
      # url.insteadOf rewrite, which its built-in transport ignores outright.
      # Written to both paths so it applies even when CARGO_HOME isn't set.
      #
      # The dev profile halves a debug `target/` (diaryx_ffi: 4.7 GB -> 2.5 GB,
      # same build time): dependencies carry no debuginfo, our own crates keep
      # file:line for backtraces. It lives here rather than in each repo so that
      # every cargo — the terminal's, and the one a GUI-launched Xcode spawns
      # without CARGO_HOME — reads the same profile and keeps the same
      # fingerprints. For locals in lldb: CARGO_PROFILE_DEV_DEBUG=true.
      ".local/share/cargo/config.toml" = cargoConfig;
      ".cargo/config.toml" = cargoConfig;

      # `dx` is diaryx-org's tool and it lives in the org checkout, so this is
      # a link to the working tree and not a copy of it: editing devtools/dx.nu
      # takes effect on the next invocation with no rebuild. It is also allowed
      # to dangle - on a machine where ~/diaryx has not been cloned yet,
      # activation still succeeds and the link starts working the moment it is.
      # dx's shell entry point walks this symlink to find the org directory it
      # operates on, so the link on PATH and the manifest a command reads are
      # never two different checkouts. This replaces the `ln -s` that the org
      # README tells you to run by hand.
      #
      # This is how every shell but nushell gets `dx`, and how anything that
      # shells out to it does. In nushell the module below wins, which is the
      # point: an external command can only print its table, and the module
      # returns it.
      ".local/bin/dx".source =
        config.lib.file.mkOutOfStoreSymlink
          "${config.home.homeDirectory}/diaryx/devtools/dx";

      # The global Claude Code instructions, versioned in ./claude. An
      # out-of-store link rather than a store path so the file stays
      # writable: Claude Code's `#` memory shortcut appends to it, and a
      # read-only symlink would make that fail. The rest of ~/.claude is
      # runtime state (credentials, sessions, history) and stays unmanaged.
      ".claude/CLAUDE.md".source =
        config.lib.file.mkOutOfStoreSymlink
          "${config.home.homeDirectory}/.config/nix-darwin/claude/CLAUDE.md";
    };

  # Nix cannot fetch the org directory: it is private, the clone is over SSH,
  # and an activation that needs the network and a live agent is one that fails
  # during a rebuild for reasons that have nothing to do with the rebuild.
  # `dx clone` is the tool for that. This only notices, says so, and does not
  # fail the switch. Everything dx shells out to - git, gh, git-cliff, nushell,
  # minisign - is in home.packages below, so a fresh machine needs the two
  # commands here and nothing else.
  home.activation.diaryxOrg = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "${config.home.homeDirectory}/diaryx/.git" ]; then
      echo "diaryx: ~/diaryx is not a checkout yet -"
      echo "  git clone git@github.com:diaryx-org/org.git ~/diaryx && dx clone"
    fi

    # The two lines of nushell that import dx as a module, written here rather
    # than into config.nu because `use` resolves at parse time: importing a
    # module that isn't there is a parse error, and a parse error in config.nu
    # takes the whole config down with it - no PATH, no aliases, no prompt.
    # Written on every switch, empty when there is no checkout to import, so
    # ~/diaryx stays as optional as the dangling symlink above says it is.
    #
    # The second line is what keeps `dx use` spelled that way inside nushell.
    # `use` is the import keyword, so nushell refuses it as the name of anything
    # a module exports - the module calls that command `link`, and dx's own
    # dispatch table plays the same trick for the wrapper on PATH. A quoted
    # multi-word alias name is a different word to the parser, and is allowed.
    # It goes beside the import rather than into config.nu for the reason the
    # import does: it names a command that exists only once the module is there.
    mkdir -p "${dxImportDir}"
    if [ -f "${dxModule}" ]; then
      {
        echo "use ${dxModule}"
        echo 'alias "dx use" = dx link'
      } > "${dxImport}"
    else
      : > "${dxImport}"
    fi
  '';

  # Fish auto-generates completions from man pages, which force-enables
  # programs.man.generateCaches (the slow "building man-cache" mandb step
  # on every rebuild). We don't need the apropos/man -k index, so turn it
  # off while keeping fish's completions.
  programs.man.generateCaches = false;

  # Karabiner is set up to make caps lock a super modifer
  xdg.configFile."skhd/skhdrc".text = ''
    shift + ctrl + alt + cmd - t : ^open /Applications/Tailscale.app
    shift + ctrl + alt + cmd - a : ^open "/Applications/T3 Code (Alpha).app"
    shift + ctrl + alt + cmd - g : ^open /Applications/Ghostty.app
    shift + ctrl + alt + cmd - b : ^open /Applications/Helium.app
    shift + ctrl + alt + cmd - d : ^open /Applications/Diaryx.app
    shift + ctrl + alt + cmd - m : ^open /System/Applications/Mail.app
    shift + ctrl + alt + cmd - p : ^open "/Applications/Prism Launcher.app"
    shift + ctrl + alt + cmd - z : ^open /Applications/Zed.app
    shift + ctrl + alt + cmd - f : ^open ~
    shift + ctrl + alt + cmd - x : ^open /Applications/Xcode.app
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
            "fn_function_keys": [
              { "from": { "key_code": "f1" }, "to": [{ "consumer_key_code": "display_brightness_decrement" }] },
              { "from": { "key_code": "f2" }, "to": [{ "consumer_key_code": "display_brightness_increment" }] },
              { "from": { "key_code": "f3" }, "to": [{ "key_code": "f3" }] },
              { "from": { "key_code": "f4" }, "to": [{ "key_code": "f4" }] },
              { "from": { "key_code": "f5" }, "to": [{ "key_code": "f5" }] },
              { "from": { "key_code": "f6" }, "to": [{ "key_code": "f6" }] },
              { "from": { "key_code": "f7" }, "to": [{ "key_code": "f7" }] },
              { "from": { "key_code": "f8" }, "to": [{ "key_code": "f8" }] },
              { "from": { "key_code": "f9" }, "to": [{ "key_code": "f9" }] },
              { "from": { "key_code": "f10" }, "to": [{ "consumer_key_code": "mute" }] },
              { "from": { "key_code": "f11" }, "to": [{ "consumer_key_code": "volume_decrement" }] },
              { "from": { "key_code": "f12" }, "to": [{ "consumer_key_code": "volume_increment" }] }
            ],
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
      e = "edit";
      config = "cd /Users/adamharris/.config/nix-darwin && $EDITOR adamharris.nix";
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      lsa = "ls -a";
      gs = "git status";
      ga = "git add";
      zigstall = "zig build -Doptimize=ReleaseFast --prefix ~/.local";
      timestamp = "date +%Y-%m-%dT%H:%M:%S%:z";
      today = ''set -l y (date +%Y) && set -l m (date +%m) && set -l d (date +%d) && prov -C $JOURNAL edit $(prov -C "$JOURNAL" new "$y-$m-$d" --in "@Daily/$y/$m" -p --as "Daily/$y/$m/$y-$m-$d.md")'';
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
      EDITOR = lib.getExe editor;
      VISUAL = lib.getExe editor;
    };

    shellAliases = {
      timeout = "uutils-timeout";
      udate = "uutils-date";
    };

    settings = {
      show_banner = false;
      abbreviations = {
        rebuild = "sudo darwin-rebuild switch --flake ~/.config/nix-darwin#adams-mac";
        e = "edit";
        config = "cd /Users/adamharris/.config/nix-darwin; hx adamharris.nix";
        gs = "git status";
        ga = "git add";
        zigstall = "zig build -Doptimize=ReleaseFast --prefix ~/.local";
        timestamp = "uutils-date +%Y-%m-%dT%H:%M:%S%:z";
        today = "today";
      };
    };

    extraConfig = ''
      # `dx` here is the module in the org checkout rather than the wrapper on
      # PATH, so its commands hand back the table they built instead of the
      # text an external command can only print: `dx tasks fig | select file`
      # is a pipeline, not a parse error. The `use` itself is one line in the
      # file below, which the diaryxOrg activation writes - and leaves empty
      # when ~/diaryx isn't there, because a `use` of a missing module is a
      # parse error and a parse error here costs the whole config.
      source ${dxImport}

      def today [] {
        let y = (date now | format date "%Y")
        let m = (date now | format date "%m")
        let d = (date now | format date "%d")
        let entry = (prov -C $env.JOURNAL new $"($y)-($m)-($d)" --in $"@Daily/($y)/($m)" -p --as $"Daily/($y)/($m)/($y)-($m)-($d).md")
        print $"TODAY: Opening ($entry)"
        prov -C $env.JOURNAL edit ($entry)
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
      gpg.ssh.allowedSignersFile = "${config.xdg.configHome}/git/allowed_signers";
    };
    # Signed with the SSH key that already authenticates to GitHub, so the
    # Keychain-backed macOS ssh-agent (programs.ssh below) unlocks both.
    # `key::` hands git the key itself rather than a path, which it would
    # not tilde-expand. Format is explicit: home.stateVersion 23.11 still
    # defaults it to openpgp.
    signing = {
      format = "ssh";
      key = "key::${sshSigningKey}";
      signByDefault = true;
    };
  };

  # Without this, `git log --show-signature` can't verify SSH signatures -
  # GitHub's "Verified" badge works either way.
  xdg.configFile."git/allowed_signers".text = "adam@diaryx.org ${sshSigningKey}\n";

  programs.gh = {
    enable = true;
    settings = {
      # ssh, not https: programs.git rewrites every https://github.com/ URL
      # to git@github.com: anyway, so a https clone from gh would only be
      # rewritten after the fact. One protocol, stated in one place.
      git_protocol = "ssh";
      aliases.co = "pr checkout";
    };
    # Off because it would write a credential helper for github.com into
    # ~/.config/git/config, and with ssh everywhere there is nothing for it
    # to serve.
    gitCredentialHelper.enable = false;
  };

  programs.ghostty = {
    enable = true;
    package = null;
    settings = {
      theme = "light:Gruvbox Light Hard,dark:Gruvbox Dark Hard";
      font-size = 13;
      unfocused-split-opacity = 1.0;
      # Spotlight's cmd+space is disabled in System Settings, freeing it here.
      keybind = "global:cmd+space=toggle_quick_terminal";
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

      # fig's authoring dialect (.figl; .fig is accepted for back-compat).
      # `fig-lsp` comes from the fig flake input in home.packages, so by default
      # it tracks flake.lock and NOT the ~/diaryx/fig working tree. Testing an
      # unreleased server no longer means editing this line: `dx use fig local`
      # builds the checkout and links both `fig` and `fig-lsp` into
      # ~/.local/bin, which is ahead of the nix profile on PATH, and
      # `dx use fig off` puts it back.
      #
      # Today the server publishes the Zig parser's teaching diagnostics and
      # nothing else — no formatting, no hover — so there is no format-on-save
      # entry here on purpose.
      language-server.fig-lsp.command = "fig-lsp";

      # Helix has no bundled fig grammar, so it is built from the checkout.
      # This entry only DECLARES it; `hx --grammar build` compiles it into
      # ~/.config/helix/runtime/grammars/fig.so, and must be re-run whenever
      # editors/tree-sitter-fig/src/parser.c changes. Deliberately not a nix
      # derivation: the point is to iterate on the grammar in place.
      grammar = [
        {
          name = "fig";
          source.path = "${config.home.homeDirectory}/diaryx/fig/editors/tree-sitter-fig";
        }
      ];

      language = [
        {
          name = "fig";
          scope = "source.fig";
          file-types = [ "figl" "fig" ];
          comment-token = "#";
          # fig ignores indentation for meaning (depth is the `>` count), but
          # 2 spaces is the printer's output, so match it.
          indent = {
            tab-width = 2;
            unit = "  ";
          };
          language-servers = [ "fig-lsp" ];
        }
      ];
    };
  };

  # Helix looks in the user runtime dir before its own, per file. An
  # out-of-store symlink means editing the query in the fig checkout takes
  # effect on the next `:config-reload` with no rebuild. The Zed extension
  # ships the sibling highlights.scm; the two use different capture
  # vocabularies, which is why there are two files.
  xdg.configFile."helix/runtime/queries/fig/highlights.scm".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/diaryx/fig/editors/tree-sitter-fig/queries/highlights-helix.scm";

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
      add_newline = false;
      line_break.disabled = true;
      command_timeout = 200;
      format = "[$directory$git_branch$git_status]($style) $character";

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
    editor
    pkgs.ripgrep
    pkgs.bat
    pkgs.eza
    pkgs.fzf
    pkgs.nodejs_24
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
    pkgs.git-cliff
    pkgs.pijul
    pkgs.minisign
    pkgs.marimo
    pkgs.mas
    pkgs.pandoc
    pkgs.fastfetch
    pkgs.yazi
    pkgs.resvg
    pkgs.qemu
    pkgs.aseprite

    # Formerly `cargo install`ed. uniffi-bindgen-cs is not in nixpkgs and is
    # still a cargo install; nu_plugin_fig is a local build of ~/diaryx/fig
    # registered by hand with `plugin add`, and stays that way until it is
    # published.
    pkgs.cargo-llvm-cov
    pkgs.cargo-semver-checks
    pkgs.twiggy
    pkgs.wasm-bindgen-cli
    pkgs.wasm-pack
    pkgs.worker-build

    # Real `timeout` binary on PATH (~/.nix-profile/bin), independent of any
    # shell rc file — unlike the zsh/bash aliases above, this also resolves
    # in non-interactive/no-rc shells (e.g. Claude Code's sandboxed Bash tool).
    (pkgs.writeShellScriptBin "timeout" ''exec ${pkgs.uutils-coreutils}/bin/uutils-timeout "$@"'')

    # Bend 2 from upstream's flake (inputs.bend in flake.nix), which replaced
    # the curl|sh installer's self-updating launcher in ~/.bend. The binary
    # itself still does a once-a-day version check against bend-lang.com
    # (bend2/main.ts `check`, honouring BEND_NO_TELEMETRY), which the store
    # path can't act on anyway, so switch it off. `bend x.bend -o x` wants
    # Apple's clang (the wrapper sets CC=/usr/bin/clang), so the Xcode CLT
    # must be installed, which it already is for brew.
    #
    # The 2.0.26 darwin-arm64 release archive ships bin/bend with a broken
    # linker signature (`codesign -v`: "code or signature have been
    # modified"), which the kernel answers with SIGKILL on exec. Re-sign it
    # ad hoc; drop this once an upstream release verifies clean.
    (inputs.bend.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.darwin.sigtool ];
      installPhase = old.installPhase + "\n" + ''
        codesign -f -s - $out/libexec/bend/bin/bend
        wrapProgram $out/bin/bend --set BEND_NO_TELEMETRY 1
      '';
    }))

    # The org's CLIs come from the diaryx-org tap now (see homebrew.brews in
    # configuration.nix), which tracks what CI publishes instead of whatever
    # revision flake.lock was last bumped to — the lock had drifted three minor
    # versions behind on prov. `dx use <repo> <channel>` links a newer build
    # into ~/.local/bin when one is wanted, so nothing here needs to move for
    # that; this is only the floor everything falls back to.
    #
    # fig is the exception, and only for one binary: the tap's formula does
    # `bin.install "fig"` and ships no fig-lsp, which the Helix language-server
    # entry below needs on PATH. brew's `fig` is ahead of the nix profile, so
    # the CLI from this package is shadowed and unused — it is here to carry
    # fig-lsp. If the formula ever installs both, this input goes.
    inputs.fig.packages.${pkgs.system}.default
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

  # Home Manager builds its own nixpkgs here (useGlobalPkgs = false in
  # flake.nix), so configuration.nix's allowUnfree doesn't reach
  # home.packages. Aseprite is the one unfree package installed this way.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "aseprite" ];

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;
}
