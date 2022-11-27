{
  inputs = {
    nixpkgs.url = "github:jcumming/nixpkgs/jcumming-local";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachSystem ["x86_64-linux"]
    (
      system: let
        nixos = inputs.nixos.legacyPackages.${system};
        pkgs =
          import nixpkgs {inherit system;};
      in
        with pkgs; rec {
          packages = flake-utils.lib.flattenTree {
            inherit (pkgs) photoprism;
            default = pkgs.photoprism;
          };

          checks.build = packages.photoprism;
          formatter = pkgs.alejandra;
        }
    )
    // {
      nixosModules.photoprism = {
        lib,
        pkgs,
        config,
        ...
      }: let
        cfg = config.services.photoprism;
      in {
        options = with lib; {
          services.photoprism = {
            enable = mkOption {
              type = types.bool;
              default = false;
            };

            mysql = mkOption {
              type = types.bool;
              default = false;
            };

            port = mkOption {
              type = types.int;
              default = 2342;
            };

            host = mkOption {
              type = types.str;
              default = "127.0.0.1";
            };

            keyFile = mkOption {
              type = types.bool;
              default = false;
              description = ''
                for sops path
                 sops.secrets.photoprism-password = {
                   owner = "photoprism";
                   sopsFile = ../../secrets/secrets.yaml;
                   path = "/var/lib/photoprism/keyFile";
                 };
                 #PHOTOPRISM_ADMIN_PASSWORD=<yourpassword>
              '';
            };

            dataDir = mkOption {
              type = types.path;
              default = "/var/lib/photoprism";
              description = ''
                Data directory for photoprism
              '';
            };

            package = mkOption {
              type = types.package;
              default = self.outputs.packages."${pkgs.system}".photoprism;
              description = "The photoprism package.";
            };
          };
        };

        config = with lib;
          mkIf cfg.enable {
            users.users.photoprism = {
              isSystemUser = true;
              group = "photoprism";
            };

            users.groups.photoprism = {};

            services.mysql = mkIf cfg.mysql {
              enable = true;
              package = mkDefault pkgs.mysql;
              ensureDatabases = ["photoprism"];
              ensureUsers = [
                {
                  name = "photoprism";
                  ensurePermissions = {"photoprism.*" = "ALL PRIVILEGES";};
                }
              ];
            };

            systemd.services.photoprism = {
              enable = true;
              after =
                [
                  "network-online.target"
                ]
                ++ lib.optional cfg.mysql "mysql.service";

              wantedBy = ["multi-user.target"];

              confinement = {
                enable = true;
                binSh = null;
                packages = [
                  pkgs.darktable
                  pkgs.ffmpeg
                  pkgs.exiftool
                  cfg.package
                  pkgs.cacert
                ];
              };

              path = [
                pkgs.darktable
                pkgs.ffmpeg
                pkgs.exiftool
              ];

              script = ''
                exec ${cfg.package}/bin/photoprism start
              '';

              serviceConfig = {
                User = "photoprism";
                BindPaths =
                  [
                    cfg.dataDir
                  ]
                  ++ lib.optionals cfg.mysql [
                    "-/run/mysqld"
                    "-/var/run/mysqld"
                  ];
                RuntimeDirectory = "photoprism";
                CacheDirectory = "photoprism";
                StateDirectory = "photoprism";
                SyslogIdentifier = "photoprism";
                # Sops secrets PHOTOPRISM_ADMIN_PASSWORD= /****/
                PrivateTmp = true;
                PrivateUsers = true;
                PrivateDevices = true;
                ProtectClock = true;
                ProtectKernelLogs = true;
                SystemCallArchitectures = "native";
                RestrictNamespaces = true;
                MemoryDenyWriteExecute = false;
                RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6";
                RestrictSUIDSGID = true;
                NoNewPrivileges = true;
                RemoveIPC = true;
                LockPersonality = true;
                ProtectHome = true;
                ProtectHostname = true;
                RestrictRealtime = true;
                SystemCallFilter = ["@system-service" "~@privileged" "~@resources"];
                SystemCallErrorNumber = "EPERM";
                EnvironmentFile = mkIf cfg.keyFile "${cfg.dataDir}/keyFile";
              };

              environment = (
                lib.mapAttrs' (n: v: lib.nameValuePair "PHOTOPRISM_${n}" (toString v))
                {
                  #HOME = "${cfg.dataDir}";
                  SSL_CERT_DIR = "${pkgs.cacert}/etc/ssl/certs";

                  DARKTABLE_PRESETS = "false";

                  DATABASE_DRIVER =
                    if !cfg.mysql
                    then "sqlite"
                    else "mysql";
                  DATABASE_DSN =
                    if !cfg.mysql
                    then "${cfg.dataDir}/photoprism.sqlite"
                    else "photoprism@unix(/run/mysqld/mysqld.sock)/photoprism?charset=utf8mb4,utf8&parseTime=true";
                  DEBUG = "true";
                  DETECT_NSFW = "true";
                  EXPERIMENTAL = "true";
                  WORKERS = "8";
                  ORIGINALS_LIMIT = "1000000";
                  HTTP_HOST = "${cfg.host}";
                  HTTP_PORT = "${toString cfg.port}";
                  HTTP_MODE = "release";
                  JPEG_QUALITY = "92";
                  JPEG_SIZE = "7680";
                  PUBLIC = "false";
                  READONLY = "false";
                  TENSORFLOW_OFF = "true";
                  SIDECAR_JSON = "true";
                  SIDECAR_YAML = "true";
                  SIDECAR_PATH = "${cfg.dataDir}/sidecar";
                  SETTINGS_HIDDEN = "false";
                  SITE_CAPTION = "Browse Your Life";
                  SITE_TITLE = "PhotoPrism";
                  SITE_URL = "http://127.0.0.1:2342/";
                  STORAGE_PATH = "${cfg.dataDir}/storage";
                  ASSETS_PATH = "${cfg.package.assets}";
                  ORIGINALS_PATH = "${cfg.dataDir}/originals";
                  IMPORT_PATH = "${cfg.dataDir}/import";
                  THUMB_FILTER = "linear";
                  THUMB_SIZE = "2048";
                  THUMB_SIZE_UNCACHED = "7680";
                  THUMB_UNCACHED = "true";
                  UPLOAD_NSFW = "true";
                }
                // (
                  if !cfg.keyFile
                  then {PHOTOPRISM_ADMIN_PASSWORD = "photoprism";}
                  else {}
                )
              );
            };
          };
      };
    };
}
