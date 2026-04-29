# home-manager wrapper around the nixpkgs contracts system.
#
# Imports the generic contracts module (`lib.contract.module`) and seeds
# nixpkgs-shipped contract types so they appear in `config.contractTypes`
# alongside any user-defined types. Mirrors `nixos/modules/contracts/default.nix`.
{ lib, ... }:
{
  imports = [ lib.contract.module ];
  config.contractTypes = lib.contracts;
}
