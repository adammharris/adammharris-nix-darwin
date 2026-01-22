{
  description = "Adam's Mac";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    diaryx.url = "github:diaryx-org/diaryx";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, diaryx, ... }: {
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
