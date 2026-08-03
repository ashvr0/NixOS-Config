{ config, pkgs, lib, ... }:
{ 
  xdg.configFile."hypr".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/modules/home/hypr/";
}