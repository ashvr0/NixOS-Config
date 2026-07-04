{ config, pkgs, hostname, ... }:
{
  networking = {
    hostName = hostname;
    networkmanager.enable = true;
    wireguard.enable = true;
    nameservers = [
      "1.1.1.1"
    ];
  };
}