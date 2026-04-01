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
    interactiveShellInit = ''
      if status is-interactive
          and not set -q TMUX
          set -x COLORTERM truecolor
      end
    '';
    shellAbbrs = {
      rebuild = "sudo darwin-rebuild switch --flake ~/.config/nix-darwin#adams-mac";
      e = "hx";
      config = "cd /Users/adamharris/.config/nix-darwin && $EDITOR adamharris.nix";
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      lsa = "ls -a";
      z = "zoxide";
      gs = "git status";
      "ga." = "git add .";
      dx = "diaryx";
    };
    shellAliases = {
      ls = "eza -lh --group-directories-first --icons=auto";
      lt = "eza --tree --level=2 --long --icons --git";
      lta = "lt -a";
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
          # Note: We check if diaryx exists to avoid errors on new setups
          if command -v diaryx > /dev/null
              diaryx property get today todo 2> /dev/null || echo "No todos for today!"
          else
              echo "diaryx not found. Install it with 'cargo install diaryx'"
          end
        '';
      };
    };
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

  # The Ghostty configuration
  programs.ghostty = {
    enable = true;
    package = null;
    settings = {
      theme = "Gruvbox Dark Hard";
      font-size = 13;
      unfocused-split-opacity = 1.0;
    };
  };

  programs.helix = {
    enable = true;
    defaultEditor = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableFishIntegration = true; 
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

      # Vi copy mode
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi y send -X copy-selection-and-cancel

      # Pane controls
      bind h split-window -h -c "#{pane_current_path}"
      bind v split-window -v -c "#{pane_current_path}"
      bind -n C-M-PageUp split-window -h -c "#{pane_current_path}"
      bind -n C-M-PageDown split-window -v -c "#{pane_current_path}"
      bind -n C-M-Home split-window -h -c "#{pane_current_path}"
      bind -n C-M-End kill-pane
      bind -n C-M-Left select-pane -L
      bind -n C-M-Right select-pane -R
      bind -n C-M-Up select-pane -U
      bind -n C-M-Down select-pane -D
      bind -n C-M-S-Left resize-pane -L 5
      bind -n C-M-S-Down resize-pane -D 5
      bind -n C-M-S-Up resize-pane -U 5
      bind -n C-M-S-Right resize-pane -R 5

      # Window navigation
      bind r command-prompt -I "#W" "rename-window -- '%%'"
      bind c new-window -c "#{pane_current_path}"
      bind x kill-window
      bind -n C-S-Home new-window -c "#{pane_current_path}"
      bind -n C-S-End kill-window
      bind -n C-S-PageUp next-window
      bind -n C-S-PageDown previous-window
      bind -n M-1 select-window -t 1
      bind -n M-2 select-window -t 2
      bind -n M-3 select-window -t 3
      bind -n M-4 select-window -t 4
      bind -n M-5 select-window -t 5
      bind -n M-6 select-window -t 6
      bind -n M-7 select-window -t 7
      bind -n M-8 select-window -t 8
      bind -n M-9 select-window -t 9

      # Session controls
      bind R command-prompt -I "#S" "rename-session -- '%%'"
      bind C new-session
      bind X kill-session
      bind -n C-M-S-Home new-session -c "#{pane_current_path}"
      bind -n C-M-S-End kill-session
      bind -n C-M-S-PageUp switch-client -p
      bind -n C-M-S-PageDown switch-client -n

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

      # Status bar
      set -g status-position top
      set -g status-interval 5
      set -g status-left-length 30
      set -g status-right-length 50
      set -g window-status-separator ""

      # Theme
      set -g status-style "bg=default,fg=default"
      set -g status-left "#[fg=black,bg=blue,bold] #S #[bg=default] "
      set -g status-right "#[fg=blue]#{?client_prefix,PREFIX ,}#[fg=brightblack]#h "
      set -g window-status-format "#[fg=brightblack] #I:#W "
      set -g window-status-current-format "#[fg=blue,bold] #I:#W "
      set -g pane-border-style "fg=brightblack"
      set -g pane-active-border-style "fg=blue"
      set -g message-style "bg=default,fg=blue"
      set -g message-command-style "bg=default,fg=blue"
      set -g mode-style "bg=blue,fg=black"
      setw -g clock-mode-colour blue
    '';
  };
  programs.starship = {
    enable = true;
    enableFishIntegration = true; 
    
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
    pkgs.zoxide
    pkgs.gnupg
    pkgs.pinentry_mac
    inputs.diaryx.packages.${pkgs.system}.default
    pkgs.gh
    pkgs.glow
    pkgs.fzf
    pkgs.nodejs_24
    pkgs.nushell
    pkgs.fd
    pkgs.yazi
    pkgs.ffmpeg
    pkgs.uv
    pkgs.nil
    pkgs.nixd
    pkgs.rustup
    pkgs.openssl_oqs
    pkgs.fortune-kind
    pkgs.presenterm

  ];

  programs.lazygit = {
    enable = true;
    settings = {
      gui.theme = {
        lightTheme = false;
        activeBorderColor = [ "green" "bold" ];
        inactiveBorderColor = [ "white" ];
      };
    };
  };

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
