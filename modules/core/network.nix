{ config, pkgs, hostname, ... }:
{
  networking = {
    hostName = hostname;
    networkmanager.enable = true;
    wireguard.enable = true;

    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
    ];

    firewall = {
      enable = true;
    };
  };
}