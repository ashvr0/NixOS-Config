{ config, pkgs, lib, ... }:

{ 
  xdg.configFile."quickshell".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/modules/home/quickshell";
}