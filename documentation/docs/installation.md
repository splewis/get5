# :material-folder-cog: Installation

## SourceMod & MetaMod

You must have [SourceMod](https://www.sourcemod.net/) installed on your server. Please note that Get5
requires **SourceMod version 1.10** or higher. SourceMod requires MetaMod, so you must install both plugins.
You can get the latest versions here:

[:material-download: Download MetaMod](https://www.sourcemm.net/downloads.php?branch=stable){ .md-button .md-button--primary } [:material-download: Download SourceMod](https://www.sourcemod.net/downloads.php?branch=stable){ .md-button .md-button--primary }

!!! info "OS is important"

    Remember to select the correct OS type (Windows/Linux/Mac) for **both** plugins. This should be the OS of the server.

## Get5

### Latest version {: #latest }

The latest version of Get5 can be found here. Older releases can be found in
the [Releases](https://github.com/splewis/get5/releases) section of the repository on GitHub.

[:material-download: Download Get5](https://github.com/splewis/get5/releases/latest){ .md-button .md-button--primary }

### Test and development {: #development }

If you would like to test new features, or be on the "bleeding edge", you can also download any of the releases found at
the link above that are marked in the title with **Nightly** or as **Pre-release**. Please note that these versions are
meant for testers and developers and should not be deployed to production servers unless you have a good reason to do
so or can live with the potential consequences.

!!! info

    Get5 itself is OS-agnostic, meaning the same file works on any OS.

## SteamWorks (Recommended) {: #steamworks }

SteamWorks is not required for Get5 to work on your game server, however it is required if you wish to [load match
configs remotely](../commands#get5_loadmatch_url) or if you want Get5 to [automatically
check for updates](../configuration#get5_print_update_notice).

[:material-steam: Download SteamWorks](https://github.com/KyleSanderson/SteamWorks/releases/){ .md-button .md-button--primary }

!!! tip "SteamWorks for Windows"

    Similarly to SourceMod and MetaMod, SteamWorks is OS-specific. If you run Windows, you can get a Windows-version of
    SteamWorks [here](https://github.com/hexa-core-eu/SteamWorks/releases).

## Putting it all together

Once you have downloaded the zip file(s), extract it/them into your `csgo/` directory in your game server. Once MetaMod,
SourceMod and Get5 (and optionally SteamWorks) have all been installed, the `csgo` folder on your server
should look like this. Not all files and folders are included in this example, as it would become way too long, so this
is just to indicate what the correct structure looks like.

!!! warning "Updating Get5 from an earlier version"

    If you already have Get5 installed and wish to upgrade to a newer version, simply copying the entire `get5.zip` folder
    structure will override your configuration files, so when updating, you should only add `get5.smx` (and
    optionally `get5_mysqlstats.smx`) to `addons/sourcemod/plugins` and merge the entire `translations` folder with
    `addons/sourcemod/translations`. In updated versions we might add or remove translation strings, and Get5 will error if
    it cannot find the strings it expects in these folders. The folder only contains Get5's translations, so it won't
    override translations for any other plugins.

???+ example "Server folder structure"

    ```yaml
    addons:
      - metamod.vdf
      - metamod_x64.vdf
      metamod: # (8)
      sourcemod:
        bin: # (9)
        configs:
          - admin_groups.cfg
          - admin_level.cfg
          - core.cfg
          - admin_simple.ini # (18)
          - ...
          get5:
            - example_match.cfg # (12)
            - example_match.json # (10) 
            - scrim_template.cfg # (11)
          geoip:
          sql-init-scripts:
        logs: # (1)
        plugins: # (17)
          - admin-flatfile.smx
          - adminhelp.smx
          - adminmenu.smx
          - antiflood.smx
          - basebans.smx
          - basechat.smx
          - basecommands.smx
          - basecomm.smx
          - basetriggers.smx
          - basevotes.smx
          - clientprefs.smx
          - funcommands.smx
          - funvotes.smx
          - get5.smx # (2) 
          disabled: # (15)
            - admin-sql-prefetch.smx
            - admin-sql-threaded.smx
            - get5_apistats.smx # (4)
            - get5_mysqlstats.smx # (3)
            - mapchooser.smx
            - nominations.smx
            - randomcycle.smx
            - rockthevote.smx
            - sql-admin-manager.smx
        translations: # (5)
          - adminhelp.phrases.txt
          - adminmenu.phrases.txt
          - get5.phrases.txt
          - ...
          da: # (6)
            - adminhelp.phrases.txt
            - adminmenu.phrases.txt
            - get5.phrases.txt
            - ...
        data: # (14)
        scripting: # (7)
          - adminhelp.sp
          - adminmenu.sp
          - swag.sp # (21)
          - get5.sp
          - get5_apistats.sp
          - get5_mysqlstats.sp
          - spcomp
          - spcomp64 # (22)
          - ...
          get5:
            - backups.sp
            - chatcommands.sp
            - ...
          include: # (20)
            - admin.inc
            - get5.inc
            - SteamWorks.inc
            - ...
        extensions: # (13)
          - bintools.ext.so
          - sdkhooks.ext.2.csgo.so
          - SteamWorks.ext.so # (19)
          - ...
        gamedata: # (16)
    cfg:
      sourcemod: # (24)
        - sm_warmode_off.cfg
        - sm_warmode_on.cfg
        - sourcemod.cfg
      get5: # (23)
        - warmup.cfg
        - live.cfg
        - knife.cfg
    bin: # (25)
    expressions:
    maps:
    materials:
    models:
    panorama:
    resource:
    scenes:
    scripts:
    ...
    ```
    
    1. SourceMod error logs can be found in here. This directory is empty by default.
    2. This is the core Get5 plugin.
    3. This is the MySQL extension for collecting stats. If you want to use this extension, please see
       the [guide](../stats_system/#mysql).
    4. This is proof-of-concept integration called [get5 web panel](https://github.com/splewis/get5-web) that can be used to
       manage matches. **This is not supported and is probably very buggy. You should not use it.**
    5. This folder contains all the language files and translations for all the plugins.
    6. Each language has its own folder with translation files.
    7. This is the source code for the plugins. These *cannot* be executed by the server, as they must be compiled first, so
       you cannot simply edit these to change plugin behavior.
    8. Don't change anything in here. There are no editable files in the `metamod` folder. It's here because SourceMod
       depends on it.
    9. SourceMod binaries.
    10. This a JSON-example of a [match configuration](match_schema.md). You should use this as a template for your own
        match configuration. All JSON match configurations **must** end with `.json`.
    11. The server's default scrim [match configuration](match_schema.md). This is loaded when using the
        [`get5_scrim`](../commands/#get5_scrim) command.
    12. Match configurations can be created in both JSON and
        SourceMod's [KeyValue](https://wiki.alliedmods.net/KeyValues_(SourceMod_Scripting)) format. We recommend JSON for
        all new users, but Get5 will continue to support reading `.cfg` files as well.
    13. Various SourceMod extension files.
    14. The `data` folder is empty by default.
    15. These plugins are disabled. If you want to enable them, you must move them up one folder (to the `plugins` folder).
    16. Various SourceMod game data.
    17. All plugins enabled on your server should be in this folder and end with `.smx`. SourceMod contains all the plugins
        listed on here by default.
    18. Allows you to configure [admin permissions](https://wiki.alliedmods.net/Adding_Admins_(SourceMod)) on your server.
    19. If you installed SteamWorks, you will have this extension in here.
    20. Various includes (such as SteamWorks) other plugins depend on for compilation.
    21. `swag.sp` is a part of SteamWorks.
    22. The `spcomp` files are used to compile `.sp` files.
    23. Contains the [phase configuration files](../configuration/#phase-configuration-files) for Get5.
    24. The default SourceMod config file and Warmode (included with SourceMod) configs. You can ignore these files.
    25. The rest of these folders are already in your `csgo` directory.

!!! success "So far, so good..."

    If you've made it this far, you should have Get5 available on your server. If you type `sm plugins refresh` in your
    server console - or if you restart your server - you should see Get5 (and all the other SourceMod defaults) in the
    list if you type in `sm plugins list`. If this doesn't work, go back and make sure you've followed all the steps to
    a tee.

## Adding administrators {: #administrators }

Server administrators can be set in the `admin_simple.ini` file inside `addons/sourcemod/configs`. Get5 considers
anyone with the `changemap` access level an administrator. For instructions on how to add admins, please see
the [SourceMod guide](https://wiki.alliedmods.net/Adding_Admins_(SourceMod)). Administrative privileges are required
to execute admin commands such as the [`!get5`](../commands/#get5) menu
command, [`get5_loadmatch`](../commands/#get5_loadmatch-filename), [`get5_endmatch`](../commands/#get5_endmatch),
[`get5_loadbackup`](../commands/#get5_loadbackup) and so on.
