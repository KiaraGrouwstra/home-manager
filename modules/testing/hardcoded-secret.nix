# Home-manager port of `nixos/modules/testing/hardcoded-secret.nix`.
#
# Hardcoded file secrets for tests. Materializes secret content via
# `home.activation` (the home-manager analog of NixOS
# `system.activationScripts`), so consumers see a real file at the
# requested path with the requested permissions. Should only be used in
# tests; secret content is stored in the nix store.
{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  cfg = config.testing.hardcoded-secret;

  inherit (lib) mkOption;
  inherit (lib.types) str submodule;
  inherit (pkgs) writeText;
  contract = "fileSecrets";
  inherit (lib.contracts.${contract}) mkProviderType;
in
{
  options.testing.hardcoded-secret = mkOption {
    description = ''
      Hardcoded file secrets. These should only be used in tests.

      Aims to replace ad-hoc `pkgs.writeText` usage in home-manager test
      setups: those leave files world-readable in the store, while this
      provider materializes the file at runtime with the contract's
      requested permissions, so consumers can be tested against the
      actual permission layout.
    '';
    type = submodule (hardcoded-secret: {
      options = {
        directory = mkOption {
          description = "The directory to store the secrets at.";
          type = str;
          default = "${config.home.homeDirectory}/.local/state/hardcoded-secrets";
          defaultText = lib.literalExpression
            "\"\${config.home.homeDirectory}/.local/state/hardcoded-secrets\"";
        };
        ${contract} = mkOption {
          description = ''
            Instances of the fileSecrets contract, including secret content
            and contract request/result.
          '';
          example = lib.literalExpression ''
            {
              my.secret = {
                request = {
                  owner = "me";
                  mode = "0400";
                };
                content = "My Secret";
              };
            }
          '';
          default = config.contracts.${contract}.requests;
          defaultText = lib.literalExpression "config.contracts.${contract}.requests";
          type = mkProviderType {
            overrides.request = {
              owner.default = config.home.username;
              group.default = config.home.username;
            };
            providerOptions.content = mkOption {
              type = str;
              description = ''
                Content of the secret as a string.

                This will be stored in the nix store and should only be
                used for testing or maybe in dev.
              '';
            };
            fulfill' = { name, ... }: {
              path = "${hardcoded-secret.config.directory}/${name}";
            };
          };
        };
      };
    });
  };

  config = {
    contracts.${contract}.providers.hardcoded-secret.module = options.testing.hardcoded-secret;

    home.activation = lib.concatMapNestedAttrs'
      (options.testing.hardcoded-secret.type.getSubOptions [ ]).${contract}.type
      (
        path: cfg':
        let
          name = lib.concatStringsSep "_" path;
          source = writeText "hardcodedsecret_${name}_content" cfg'.content;
          inherit (cfg') request result;
        in
        {
          ${"hardcodedsecret_${name}"} = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            run mkdir -p "$(dirname ${lib.escapeShellArg result.path})"
            run install -m ${request.mode} ${source} ${lib.escapeShellArg result.path}
          '';
        }
      )
      cfg.${contract};
  };
}
