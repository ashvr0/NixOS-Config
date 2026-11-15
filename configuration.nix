{ config, pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules/core/default.nix
  ];

  swapDevices = [
    { device = "/swapfile"; size = 4096; }
  ];
  
  nixpkgs.config.allowUnfree = true;

  environment.variables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
  };
}
