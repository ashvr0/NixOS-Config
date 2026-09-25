{ config, pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules/core/default.nix
    inputs.serpantinum.nixosModules.default
  ];

   programs.serpantinum.enable = true;

  swapDevices = [
    { device = "/swapfile"; size = 4096; }
  ];
  
  nixpkgs.config.allowUnfree = true;

  environment.variables = {
    XCURSOR_THEME = "Nordic-cursors";
  };
}
