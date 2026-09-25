{ config, pkgs, lib, ... }:

{ 
  xdg.configFile."fish".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/modules/home/fish";
}