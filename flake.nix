{
  description = "Adam's Mac";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # The org's CLIs are installed from the diaryx-org homebrew tap, not from
    # here — a flake input pins one revision and only moves when someone runs
    # `nix flake update`, which is how prov ended up three minor versions behind
    # what CI had published. The tap is written by CI on every release, so it is
    # the better stable pin, and `dx use` handles anything newer than stable.
    #
    # fig survives as an input for exactly one binary: the tap's formula does
    # `bin.install "fig"` and ships no fig-lsp, which Helix needs on PATH. See
    # home.packages in adamharris.nix.
    fig.url = "github:diaryx-org/fig";
    fig.inputs.nixpkgs.follows = "nixpkgs";

    # Upstream's flake, which fetches the per-platform release archive from
    # GitHub Releases (a bun-compiled executable, no source build). It pins
    # its own nixos-unstable only to reach stdenv/makeWrapper, so follow ours.
    bend.url = "github:bendlang/bend";
    bend.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, fig, ... }: {
    darwinConfigurations."adams-mac" = nix-darwin.lib.darwinSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = false;
          home-manager.useUserPackages = false;
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.adamharris = import ./adamharris.nix;
	        home-manager.backupFileExtension = "backup";
        }
      ];
    };
  };
}
