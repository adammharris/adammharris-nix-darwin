{
  description = "Adam's Mac";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    fig.url = "github:diaryx-org/fig";
    fig.inputs.nixpkgs.follows = "nixpkgs";
    twig.url = "github:diaryx-org/twig";
    twig.inputs.nixpkgs.follows = "nixpkgs";
    prov.url = "github:diaryx-org/prov";
    prov.inputs.nixpkgs.follows = "nixpkgs";
    moid.url = "github:diaryx-org/moid";
    moid.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, fig, twig, prov, moid, ... }: {
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
