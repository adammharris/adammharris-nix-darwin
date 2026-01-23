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
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      lsa = "ls -a";
      z = "zoxide";
      gs = "git status";
      "ga." = "git add .";
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
          # 1. Get the current hour
          set hour (date +%H)

          # 2. Determine the time of day
          if test $hour -lt 12
              set time_msg "Good morning"
          else if test $hour -lt 18
              set time_msg "Good afternoon"
          else
              set time_msg "Good evening"
          end

          # 3. Print the message
          set_color cyan
          echo "$time_msg, $USER."

          # 4. Print current tasks (using diaryx)
          set_color blue
          echo "Today's tasks:"
          # Note: We check if diaryx exists to avoid errors on new setups
          if command -v diaryx > /dev/null
              diaryx property get today todo || echo "No todos for today!"
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

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableFishIntegration = true; 
  };

  programs.tmux = {
    enable = true;
    mouse = true;
    extraConfig = ''
      set -g status-bg blue
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

  programs.bun = {
    enable = true;
  }

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
