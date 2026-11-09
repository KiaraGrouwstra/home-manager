{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.aria2;

  # Import by path, because the documentation build replaces all packages.
  aria2ConfigFiles = pkgs.configFiles (
    import (pkgs.path + "/pkgs/by-name/ar/aria2/config-files.nix")
  );

  homeManagerModule = {
    imports = [
      (lib.mkRemovedOptionModule [
        "extraConfig"
      ] "This option has been removed. Please use 'programs.aria2.settings' instead.")
    ];

    options = {
      # The module above sets this. The configuration of the home reads it.
      assertions = lib.mkOption {
        type = lib.types.listOf lib.types.unspecified;
        default = [ ];
        internal = true;
      };

      enable = lib.mkEnableOption "aria2";

      package = lib.mkPackageOption pkgs "aria2" { nullable = true; };

      settings = lib.mkOption {
        example = {
          listen-port = 60000;
          dht-listen-port = 60000;
          seed-ratio = 1.0;
          max-upload-limit = "50K";
          ftp-pasv = true;
        };
      };

      systemd.enable = lib.mkEnableOption "Aria2 systemd integration";
    };
  };
in
{
  meta.maintainers = [ lib.maintainers.justinlovinger ];

  options.programs.aria2 = lib.mkOption {
    default = { };
    description = "Configuration of aria2.";
    type = lib.types.submoduleWith {
      modules = [
        aria2ConfigFiles.module
        homeManagerModule
      ];
    };
  };

  config = lib.mkMerge [
    { inherit (cfg) assertions; }

    (lib.mkIf cfg.enable {
      home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];

      xdg.configFile."aria2/aria2.conf" = lib.mkIf cfg.portable.files."aria2.conf".enable {
        inherit (cfg.portable.files."aria2.conf") source;
      };

      systemd.user.services.aria2 = lib.mkIf cfg.systemd.enable {
        Unit = {
          Description = "Aria2c daemon";
          Documentation = "man:aria2c(1)";
          X-Restart-Triggers = lib.mkIf (cfg.settings != { }) [
            "${config.xdg.configFile."aria2/aria2.conf".source}"
          ];
        };

        Service = {
          ExecStart = "${lib.getExe cfg.package} --enable-rpc";
          Restart = "on-failure";
        };

        Install.WantedBy = [ "default.target" ];
      };
    })
  ];
}
