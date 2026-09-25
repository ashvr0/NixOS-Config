{ config, pkgs, lib, ... }:

{ 
  xdg.configFile."alacritty".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/modules/home/alacritty/";
}