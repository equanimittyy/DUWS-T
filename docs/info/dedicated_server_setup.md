# Running DUWS_T on a dedicated server

A local dedicated server, at no cost beyond owning the game. This exists because some of the
mission cannot be tested any other way: a hosted session runs the server and a client in one
process, so `player` is never `objNull` and a locality fault that would break a real server passes
silently. Anything touching persistence, JIP or remote execution needs this setup to be believed.

## The server binary is already on disk

`arma3server_x64.exe` sits in the Arma 3 install folder beside `arma3_x64.exe`. Nothing to
download, nothing to buy, and it runs against the same install — so the game version and any loaded
mods already match what the client will connect with.

SteamCMD app `233780` installs the server as a separate package. That is the right answer when the
server lives on a different machine from the game, and unnecessary overhead when it does not. For
testing on your own box, use the executable you already have.

## Lay out the files

| What | Where |
|---|---|
| Mission | `<Arma 3>\MPMissions\DUWS_T.altis.pbo` |
| Server config | anywhere; passed with `-config=` |
| Profile directory | anywhere; passed with `-profiles=` |

The `<name>.<world>.pbo` filename is load-bearing — Arma reads the terrain out of it — so
`repack.cmd` output goes across unrenamed.

**Choose the profile directory deliberately.** It is where the server writes its own
`.vars.Arma3Profile`, which is where campaign saves will live once
[`campaign_persistence_plan.md`](../campaign_persistence_plan.md) lands. It is the directory you
back up and the directory you copy a save out of.

**Then keep `-profiles=` and `-name=` identical on every restart.** The profile namespace is read
back for the profile that wrote it, so a server whose profile identity moves between starts files
each session's save under a different one and finds nothing on the next boot. The symptom is a
campaign that vanishes on restart while the writes were succeeding all along, which reads as an
engine fault rather than as a launch line that changed.

## server.cfg

```cpp
hostname       = "DUWS_T test";
passwordAdmin  = "changeme";       // needed for #login, which the debug console requires
maxPlayers     = 8;
persistent     = 1;                // keep the mission running when the last player leaves
verifySignatures = 0;              // local testing only

class Missions
{
    class DUWS_T
    {
        template   = "DUWS_T.altis";   // no .pbo extension
        difficulty = "custom";

        class Params
        {
            DUWS_LogLevel = 4;
        };
    };
};
```

`class Params` overrides the mission's own parameter defaults without repacking the PBO — the
class names come from `src/duws/shared/includes/params_modern.hpp`. This is the only way to
configure a running server, and it is why anything a host might want to tune belongs there rather
than in `server_var_init.sqf`.

**`persistent = 1` changes what the mission has to cope with.** Without it the mission ends the
moment the last player disconnects and everything in memory goes with it. With it the mission keeps
running with nobody connected. Both cases are covered in
[`campaign_persistence_plan.md`](../campaign_persistence_plan.md#when-the-save-is-written-and-what-happens-with-nobody-on).

## Launch

```text
arma3server_x64.exe -server -config=server.cfg -profiles=serverprofile -name=server -port=2302 -autoInit
```

| Switch | Why |
|---|---|
| `-config=` | The file above |
| `-profiles=` | The directory named above; the save lands under it |
| `-name=` | Profile name inside that directory |
| `-port=2302` | Default; must differ from anything else listening |
| `-autoInit` | Starts the first mission at boot with no player. Requires `persistent = 1` |

Without `-autoInit`, someone has to connect and pick the mission from the lobby on the first run —
which is fine for a test and useless for an unattended restart.

## Connect and take admin

Server and client run happily on the same machine. In the multiplayer browser, Direct Connect to
`127.0.0.1:2302`; no port forwarding is involved. Playing across a LAN or the internet needs UDP
`2302-2306` open.

Then `#login changeme` in chat. This matters more than it looks: the mission sets
`enableDebugConsole = 1` (`src/description.ext`), which grants the console in singleplayer and to
**hosts or logged-in admins** in multiplayer. On a dedicated server nobody is the host, so without
`#login` there is no console and no way to run anything against the server.

## Restarting

The distinction decides whether a persistence test means anything:

| Action | What survives |
|---|---|
| `#restart` / `#missions` | The server process, and everything in its memory |
| Stopping and starting the executable | Nothing — this is the only real restart |

A namespace variable is still in RAM across `#restart`, so a save/reload check that uses it reads
its own leftovers and passes whether or not anything was ever written to disk.
