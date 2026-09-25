  { username, pkgs, ... }:
{
  users.groups.i2c = {};

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "i2c" ];
  };
}