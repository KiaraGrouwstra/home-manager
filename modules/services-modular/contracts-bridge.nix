# Contracts bridge for home-manager modular services.
#
# Mirrors `nixos/modules/system/service/contracts-bridge.nix` but walks the
# `home.services` tree. Auto-nests each service's `contracts.<type>.want`
# under the service path and lifts `contracts.<type>.providers` into the
# home-manager contract namespace.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  portable-lib = import (pkgs.path + "/lib/services/lib.nix") { inherit lib; };
in
{
  contracts = lib.mapAttrs (contractType: _: {
    want = lib.mkMerge (
      portable-lib.flattenMapServicesConfigToList (
        loc: service:
        let
          want = service.contracts.${contractType}.want or { };
          path = lib.filter (k: k != "services") loc;
        in
        if path == [ ] || want == { } then lib.toList want else [ (lib.setAttrByPath path want) ]
      ) [ ] { services = config.home.services; }
    );
    providers = lib.mkMerge (
      portable-lib.flattenMapServicesConfigToList (
        _: service:
        lib.mapAttrsToList (name: provider: { ${name} = provider; }) (
          service.contracts.${contractType}.providers or { }
        )
      ) [ ] { services = config.home.services; }
    );
  }) config.contractTypes;
}
