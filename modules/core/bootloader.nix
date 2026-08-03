{ config, pkgs, ... }:
{
  boot = {
    loader = {
      timeout = 30;
      systemd-boot = {
        enable = true;
        configurationLimit = 3;
      };
      efi.canTouchEfiVariables = true;
      };
    kernelPackages = pkgs.linuxPackages_latest;
  };
}
