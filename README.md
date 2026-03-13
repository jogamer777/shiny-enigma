# shiny-enigma

A team-based Minecraft battle game mode (Bedwars-style) implemented in [Skript](https://github.com/SkriptLang/Skript).

## Gameplay Overview

Two teams (Red and Blue) compete in a phased battle:

1. **Setup Phase** — Players gather resources in their base and the neutral zone
2. **Phase 1** — Players are sent to their team spawns; building begins (5 min)
3. **Phase 2** — The neutral zone opens for both teams (5 min)
4. **Combat Phase** — All players teleport to the fight spawns; PvP is fully enabled
5. **End** — The team whose bed is still intact wins

Players have a limited number of respawns. When all respawns are used, the player becomes a spectator.

## Dependencies

| Plugin | Purpose |
|--------|---------|
| [Skript](https://github.com/SkriptLang/Skript) | Core scripting engine |
| [WorldGuard](https://enginehub.org/worldguard) | Region and flag management |
| [Citizens](https://citizensnpcs.co/) | NPC management |
| [LuckPerms](https://luckperms.net/) | Permission groups (`team-rot`, `team-blau`, `game-admin`) |

## Installation

1. Copy `game.sk` and `shop-items.sk` into your server's `plugins/Skript/scripts/` folder
2. Run the region setup commands from `setup-region.sk` once in-game (or via console)
3. Edit the coordinate variables at the top of `game.sk` to match your map
4. Reload scripts: `/sk reload all`

## Configuration

All coordinates and timers are defined as variables at the top of `game.sk`:

```
{spawn.red}          — Red team spawn location
{spawn.blue}         — Blue team spawn location
{fight.spawn.red}    — Red team combat spawn
{fight.spawn.blue}   — Blue team combat spawn
{timer.phase1}       — Duration of phase 1 in seconds (default: 300)
{timer.phase2}       — Duration of phase 2 in seconds (default: 300)
{golem.lifetime}     — Seconds before a summoned golem despawns (default: 20)
{game.respawns.default} — Starting respawn count per player (default: 3)
{game.max.health}    — Starting max health (default: 10)
{game.walk.speed}    — Starting walk speed (default: 0.2)
```

## Admin Commands

| Command | Description |
|---------|-------------|
| `/startgame` | Shortcut: reset + start phase 1 |
| `/setstartphase1` | Reset all players and flags to setup state |
| `/startphase1` | Teleport players to team spawns, begin phase 1 |
| `/startphase2` | Open neutral zone (auto-called after phase 1) |
| `/startphase3` | Begin combat phase (auto-called after phase 2) |
| `/endgame` | End the game and announce winner |
| `/resetgame` | Fully reset all player stats and variables |

## Shop / Give Commands

| Command | Description |
|---------|-------------|
| `/team <red/blue>` | Assign a player to a team |
| `/givegoldencarrot` | Give +2 max health item |
| `/givegoldencarrot-reset` | Reset player max health |
| `/giverabitsfoot` | Give +0.1 speed item |
| `/giverabitsfoot-reset` | Reset player walk speed |
| `/givegoldenapple` | Give +1 respawn item |
| `/givecompass` | Give Radar Compass (highlights enemies) |
| `/getgolemitem` | Give Golem Summoner (summons Iron Golem in combat phase) |

## Permission Groups (LuckPerms)

| Group | Purpose |
|-------|---------|
| `game-admin` | Can run all admin commands |
| `team-rot` | Red team member |
| `team-blau` | Blue team member |

## Version History

See [git log](../../commits) for full history. Current version: `0.0.3.0`
