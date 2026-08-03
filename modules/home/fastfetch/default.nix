{ config, pkgs, lib, ... }:

{ 
  xdg.configFile."fastfetch".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/modules/home/fastfetch/";
}