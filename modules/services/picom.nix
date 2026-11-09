{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.picom;

  # Import by path, because the documentation build replaces all packages.
  picomConfigFiles = pkgs.configFiles (
    import (pkgs.path + "/pkgs/by-name/pi/picom/config-files.nix")
  );

  homeManagerModule = {
    imports = [
      (lib.mkRemovedOptionModule [ "opacityRule" ] "Use `services.picom.opacityRules` instead.")
      (lib.mkRemovedOptionModule [
        "refreshRate"
      ] "The option `refresh-rate` has been deprecated by upstream.")
      (lib.mkRemovedOptionModule [
        "experimentalBackends"
      ] "The option `--experimental-backends` has been removed by upstream.")
      (lib.mkRemovedOptionModule [
        "extraOptions"
      ] "This option has been replaced by `services.picom.settings`.")
    ];

    options = {
      # The modules above set this. The configuration of the home reads it.
      assertions = lib.mkOption {
        type = lib.types.listOf lib.types.unspecified;
        default = [ ];
        internal = true;
      };

      enable = lib.mkEnableOption "Picom X11 compositor";

      package = lib.mkPackageOption pkgs "picom" { };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "--legacy-backends" ];
        description = ''
          Extra arguments to be passed to the picom executable.
        '';
      };
    };
  };
in
{
  meta.maintainers = with lib.maintainers; [ thiagokokada ];

  options.services.picom = lib.mkOption {
    default = { };
    description = "Configuration of the Picom X11 compositor.";
    type = lib.types.submoduleWith {
      modules = [
        picomConfigFiles.module
        homeManagerModule
      ];
    };
  };

  config = lib.mkMerge [
    { inherit (cfg) assertions; }

    (lib.mkIf cfg.enable {
      assertions = [
        (lib.hm.assertions.assertPlatform "services.picom" pkgs lib.platforms.linux)
      ];

      home.packages = [ cfg.package ];

      xdg.configFile."picom/picom.conf".text = cfg.portable.files."picom.conf".text;

      systemd.user.services.picom = {
        Unit = {
          Description = "Picom X11 compositor";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };

        Install = {
          WantedBy = [ "graphical-session.target" ];
        };

        Service = {
          ExecStart = lib.concatStringsSep " " (
            [
              "${lib.getExe cfg.package}"
              "--config ${config.xdg.configFile."picom/picom.conf".source}"
            ]
            ++ cfg.extraArgs
          );
          Restart = "always";
          RestartSec = 3;
        };
      };
    })
  ];
}
