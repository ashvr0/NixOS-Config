{ username, pkgs, ... }:
{
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [ "networkmanager" "wheel" "libvirtd" ];
  };
}