
## NixOS module for Photoprism

This module is a fork of [photoprism2nix](https://github.com/GTrunSec/photoprism2nix). 

Photoprism is now part of nixpkgs, this fork removes all of the
photoprism build and just includes the NixOS module.

*Some* of the photoprism configuration is controlled through environment
variables, and some of the configuration is controlled through a file:
`/var/lib/photoprism/storage/config/settings.yml`

My configuration uses containers and bind mounts and a nginx reverse proxy for
access control. 

```nix
  containers = {
    PhotoPrism0 = mkPhotoPrismContainer {
      inherit pkgs photoprism2nix;
      roOriginals = "/zpool/containers/PhotoPrism0";
      port = PhotoPrism0Port;
      site = "https://example.com/photos/PhotoPrism0/";
    };
```

```nix
{
  pkgs,
  photoprism2nix,
  port,
  roOriginals,
  site,
}: let
  settingsFile = pkgs.writeTextFile {
    name = "photoprism-settings.yml";
    text = ''
      UI:
        Scrollbar: true
        Zoom: false
        Theme: default
        Language: en
        TimeZone: ""
      Search:
        BatchSize: 0
      Maps:
        Animate: 0
        Style: ""
      Features:
        Account: false
        Advanced: false
        Albums: false
        Archive: false
        Delete: false
        Download: true
        Edit: false
        Estimates: true
        Favorites: true
        Files: false
        Folders: true
        Import: false
        Labels: false
        Library: true
        Logs: true
        Moments: false
        People: false
        Places: false
        Private: false
        Ratings: true
        Reactions: true
        Review: true
        Search: false
        Services: false
        Settings: false
        Share: false
        Upload: false
        Videos: false
      Import:
        Path: /
        Move: false
      Index:
        Path: /
        Convert: true
        Rescan: false
        SkipArchived: false
      Stack:
        UUID: true
        Meta: true
        Name: false
      Share:
        Title: ""
      Download:
        Name: file
        Disabled: false
        Originals: true
        MediaRaw: false
        MediaSidecar: false
      Templates:
        Default: index.gohtml
    '';
  };
in {
  autoStart = true;

  bindMounts = {
    "/var/lib/photoprism/originals" = {
      hostPath = roOriginals;
      isReadOnly = true;
    };
  };

  config = {
    config,
    pkgs,
    photoprism2nin,
    ...
  }: {
    imports = [photoprism2nix.nixosModules.photoprism];

    environment.etc."resolv.conf".text = "nameserver 8.8.8.8";

    system.activationScripts.copyInConfig = {
      text = ''
        mkdir -p /var/lib/photoprism/storage/config/
        rm /var/lib/photoprism/storage/config/settings.yml
        cp ${settingsFile} /var/lib/photoprism/storage/config/settings.yml
      '';
      deps = [];
    };

    services.photoprism = {
      enable = true;
      originalsDir = "/var/lib/photoprism/originals";
      adminPassword = "xxxxxxxxxxxxxxxxx";
      settings = {
        HTTP_PORT = port;
        HTTP_HOST = "127.0.0.1";
        AUTH_MODE = "public";
        DISABE_WEBDAV = "true";
        READONLY = "true";
        DISABLE_WEBDAV = "true";
        DISABLE_SETTINGS = "true";
        DISABLE_PLACES = "true";
        SITE_URL = site;
      };
    };
  };
}
```


```nix
    nginx = { 
      enable = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      adminAddr = "jcumming-webmaster@eample.com";
  
      virtualHosts = {
        "example.com" = {
	  ...

          locations."/photos/PhotoPrism0/" = {
            basicAuth = {change = "me";};
            extraConfig = ''
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header Host $host;
    
              proxy_pass http://localhost:${toString PhotoPrism0Port};
    
              proxy_buffering off;
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";
    
              client_max_body_size 500M;
            '';
          };
     ...
     };
```
