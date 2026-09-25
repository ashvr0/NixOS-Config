{ username, ... }:
{
  imports = [
    ../../modules/core/default.nix
    ./hardware-configuration.nix
  ];
  users.users.${username}.isNormalUser = true;
}