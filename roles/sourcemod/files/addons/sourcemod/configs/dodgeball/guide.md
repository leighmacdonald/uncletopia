# TF2 Dodgeball — Configuration Guide

Full reference for `general.cfg` plus ready-made rocket recipes and troubleshooting. Pair this with the comments in the shipped `general.cfg`.

---

## How configs work

The plugin loads `general.cfg` on every dodgeball-prefixed map. If a `tfdb_<mapname>.cfg` exists in this folder, that file is loaded **after** general.cfg and overrides any matching values for that map only.

So a typical setup:

- `general.cfg` — your default settings for every map
- `tfdb_stadium_b3.cfg` — only the values you want different on `tfdb_stadium_b3`
- `presets.cfg` — preset bundles players can vote for via `sm_voterocketpreset`

---

## The structure

```
"tf2_dodgeball"
{
    "general"   { ... global server-wide flags ... }
    "classes"   { ... rocket types, each one a sub-block ... }
    "spawners"  { ... per-team rocket spawn rules ... }
}
```

You can have any number of classes (common, nuke, sniper, boulder, anything). Spawners decide which classes spawn and how often.

---

## `general` block — server-wide flags

| Field | Type | Default | What it does |
|---|---|---|---|
| `max velocity` | float | `3500.0` | Engine speed cap override for `sv_maxvelocity`. `0` leaves TF2's default (3500). Raise to `5000`+ for high-deflect rallies that hit the cap. |
| `push prevention` | bool | `1` | Stops airblasts from pushing other players. `0` = vanilla TF2 behavior. |
| `push prevention toggle` | bool | `0` | If `1`, players can toggle the above with `!ab` for themselves. |
| `noblock` | bool | `1` | Players can pass through each other (no body collision). |
| `target lock` | bool | `0` | Once a rocket targets you, deflecting it can't switch its target to anyone else. |
| `target lock bot only` | bool | `0` | Same as above but only applies when the bot is the target. |
| `music` | bool | `0` | Enable per-round music (round start, round end, gameplay). Paths set below. |
| `round start` / `round end (win)` / `round end (lose)` / `gameplay` | string | `""` | Sound paths for the music feature. Same format as `EmitSoundToClient`. |
| `use web player` / `web player url` | bool / string | `0` / `""` | Streams music from a URL via web player. Most servers leave this off. |

### Experimental scaling modes (advanced, dormant by default)

| Field | Default | What it does |
|---|---|---|
| `orbit coefficient` | `0` | When set, tightens orbit radius based on rocket speed. Rough feature. |
| `target speed scaling` | `0` | Scales rocket speed by target's velocity. Untested at scale. |
| `smooth elevation` | `0` | Smooths elevation changes after deflect instead of snapping. |

---

## `classes` block — rocket type definitions

Each class is a named sub-block. The class name must match what you put in `spawners` (e.g. if you have a `"sniper"` class, spawners reference it as `"sniper%"`).

### Movement

| Field | Type | What it does |
|---|---|---|
| `speed` | float | Base speed in HU/s when rocket spawns |
| `speed increment` | float | Speed gained per deflection |
| `speed limit` | float | Max speed cap. `0` = no cap (uses `max velocity`) |
| `turn rate` | float | How fast the rocket can change direction. `0.0` (slow) to `1.0` (instant snap) |
| `turn rate increment` | float | Turn rate gained per deflection |
| `turn rate limit` | float | Max turn rate cap. `0` = no cap |

**Practical ranges:**
- Slow / chunky rocket: `turn rate 0.15`, `speed 750`
- Default homing rocket: `turn rate 0.28`, `speed 950`
- Twitchy / aggressive: `turn rate 0.45`, `speed 1100`

### Damage

| Field | Type | What it does |
|---|---|---|
| `damage` | float | Base damage on kill |
| `damage increment` | float | Damage added per deflection |
| `critical chance` | int 0-100 | % chance the rocket rolls crit (visual + 3× damage) |
| `crit glow stack` | int 1-10 | How many fake-crit glow particles stack on the rocket. `1` = default look, `5+` = thick "charged" glow |
| `crit glow particle red` | string | Override the crit glow particle for RED rockets. Empty = default `critical_rocket_red` |
| `crit glow particle blue` | string | Same for BLU. Empty = `critical_rocket_blue` |
| `crit glow particle neutral` | string | Same for FFA / neutral rockets. Empty = `eyeboss_projectile` |

> Custom particle names must exist in TF2's `ParticleEffectNames` string table or the rocket renders nothing. Stick to stock TF2 particle names unless you've precached your own `.pcf`.

### Drag and bounce feel

These four fields define how the rocket "feels" after a deflection or bounce.

| Field | Type | Default | What it does |
|---|---|---|---|
| `steering control` | seconds | `0.045` | Pre-read drag window. How long after airblast before the plugin samples the deflector's eye angles. Lower = snappier. Higher = wider drag window |
| `bounce control` | seconds | `0.045` | Post-bounce blind window. How long after a bounce before homing resumes |
| `control delay` | seconds | `0` | Extra blind period after the eye-angle read finishes |
| `max bounces` | int | `10000` | How many wall bounces before the rocket explodes. `0` = explodes on first contact (nuke-style) |
| `bounce ceiling` | float (HU) | `0` | Max vertical velocity after a bounce. `0` = no clamp. Try `300-500` for high-deflect rockets that bounce too violently |
| `think interval` | seconds | `0` | `0` = per-tick smooth homing (default). `0.05` = 20Hz Damizean-style. `0.1` = 10Hz chunky |

**Feel cheat sheet:**

| Feel | `steering control` | `bounce control` | `think interval` |
|---|---|---|---|
| Modern smooth (default) | `0.045` | `0.045` | `0` |
| Heavy / sticky | `0.106` | `0.106` | `0` |
| Snappy / instant | `0.015` | `0` | `0` |
| Damizean-authentic (YADP 1.4.2) | `0.045` | `0.045` | `0.05` |
| Chunky old-school legacy | `0.045` | `0.045` | `0.1` |

When `think interval > 0`, turn rate applies **raw** per fire (no per-frame compensation). So Damizean-era turn-rate values like `0.233` produce Damizean-era rotation. With `think interval 0`, turn rate is scaled per-frame so the same value behaves more smoothly.

### Targeting behavior

| Field | Type | What it does |
|---|---|---|
| `keep direction` | bool | After a deflect, keep the deflector's direction even if it doesn't point at the target (popular Redux feature) |
| `reset bounces` | bool | Reset bounce counter when the rocket gets deflected |
| `neutral rocket` | bool | Rocket has no team — can be deflected by either side |
| `teamless deflects` | bool | Deflections from any team count toward this rocket's progression |
| `can be stolen` | bool | Other players can deflect a rocket targeted at someone else |
| `steal team check` | bool | If `can be stolen` is on, only allow steals from the same team as the original target |
| `direction to target weight` | int 0-100 | How strongly the rocket leans toward its target each frame. `100` = full lean, `25` = slow drift |

### Elevation (advanced)

| Field | Type | What it does |
|---|---|---|
| `elevate on deflect` | bool | Rocket rises a bit each time it gets deflected |
| `elevation rate` | float | How fast it rises per deflect |
| `elevation limit` | float | Max elevation cap |

Most rocket classes leave these at `0`.

### Progression modifiers (rare)

| Field | What it does |
|---|---|
| `no. players modifier` | Speed/damage scales with player count (positive = harder with more players) |
| `no. rockets modifier` | Speed/damage scales with concurrent rocket count |

### Visual

| Field | Type | What it does |
|---|---|---|
| `model` | string | Custom model path. Empty = default rocket. Models must be precached |
| `is animated` | bool | If `1`, plays the model's idle animation |

### Sounds

| Field | Type | What it does |
|---|---|---|
| `play spawn sound` / `play beep sound` / `play alert sound` | bool | Toggle each sound type |
| `spawn sound` / `beep sound` / `alert sound` | string | Custom sound paths. Empty = default |
| `beep interval` | seconds | How often the beep plays. `0` = default cadence |

### Events

Event commands fire when the rocket does specific things. The full server-command pipeline is documented below.

| Event | When it fires |
|---|---|
| `on spawn` | Rocket created |
| `on deflect` | Player airblasted the rocket |
| `on kill` | Rocket killed someone after at least one deflection (`@deflections > 0`) |
| `on spawn kill` | Rocket killed someone with zero deflections (instant spawn-kill) |
| `on explode` | Rocket detonated without killing |
| `on no target` | Rocket couldn't find anyone to chase (e.g. no living enemies) |
| `on destroyed` | Rocket entity removed from world (requires the ExtraEvents subplugin) |

> **Important:** `on kill` and `on spawn kill` are mutually exclusive — exactly one fires per kill, never both. If you want the same message for both, copy the same string into both fields.

#### Event command placeholders

These get substituted in the command string before it runs:

| Placeholder | Means |
|---|---|
| `@rocket` | The rocket entity index |
| `@owner` | The player who last deflected the rocket |
| `@dead` | The player who died (only for kill events) |
| `@target` | The current target |
| `@speed` | Current speed in HU/s |
| `@capmphspeed` | Current speed in MPH (capped — for display) |
| `@deflections` | How many times the rocket was deflected |
| `##@owner##` | Owner's name with team color (used by `tf_dodgeball_print`) |
| `##@dead##` | Dead player's name with team color |

#### Color tags (for `tf_dodgeball_print` from the Print subplugin)

| Tag | Color |
|---|---|
| `{default}` | Reset to default |
| `{red}` / `{blue}` | Team colors |
| `{olive}` | Olive (TFDB brand color) |
| `{darkorange}` / `{yellow}` / `{lightblue}` / `{darkmagenta}` | Various accents |
| `{steelblue}` / `{community}` | More options |

Full list of supported tags: see the `multicolors` library docs or just experiment.

---

## `spawners` block — what spawns and how often

```
"spawners"
{
    "red" { "max rockets" "1"  "interval" "2.0"  "common%" "90"  "nuke%" "10" }
    "blu" { "max rockets" "1"  "interval" "2.0"  "common%" "90"  "nuke%" "10" }
}
```

| Field | What it does |
|---|---|
| `max rockets` | How many rockets can be alive at once for this team |
| `interval` | Seconds between rocket spawns |
| `<class name>%` | Spawn chance for each class. Should sum to 100 |

To add a class to spawning, just append `"<classname>%" "<chance>"`. To disable a class without deleting it, set its chance to `0`.

---

## Rocket recipes

Drop these into your `classes` block to add new rocket types. Then add them to `spawners` with whatever spawn % you want.

### Sniper — long-range, slow turning

```
"sniper"
{
    "name"                       "Sniper Rocket"
    "behaviour"                  "homing"
    "speed"                      "1400"
    "speed increment"            "100"
    "turn rate"                  "0.10"
    "turn rate increment"        "0.005"
    "damage"                     "60"
    "damage increment"           "30"
    "critical chance"            "100"
    "steering control"           "0.030"
    "bounce control"             "0.030"
    "max bounces"                "5"
    "keep direction"             "1"
    "direction to target weight" "60"
    "play spawn sound"           "1"
    "play beep sound"            "1"
    "play alert sound"           "1"
}
```

### Boulder — slow, heavy, lots of bounces

```
"boulder"
{
    "name"                       "Boulder"
    "behaviour"                  "homing"
    "speed"                      "650"
    "speed increment"            "50"
    "turn rate"                  "0.40"
    "turn rate increment"        "0.005"
    "damage"                     "30"
    "damage increment"           "15"
    "critical chance"            "30"
    "steering control"           "0.106"
    "bounce control"             "0.106"
    "max bounces"                "10000"
    "bounce ceiling"             "400"
    "keep direction"             "1"
    "direction to target weight" "80"
}
```

### Damizean-authentic — original 20Hz feel

```
"damizean"
{
    "name"                       "Classic Rocket"
    "behaviour"                  "homing"
    "speed"                      "1100"
    "speed increment"            "70"
    "turn rate"                  "0.233"
    "turn rate increment"        "0.0275"
    "damage"                     "100"
    "damage increment"           "50"
    "critical chance"            "10"
    "steering control"           "0.045"
    "bounce control"             "0.045"
    "max bounces"                "10000"
    "think interval"             "0.05"
    "keep direction"             "0"
    "can be stolen"              "1"
}
```

The shipped `general.cfg` already includes this as `damizean legacy` (dormant — set its spawn % > 0 to enable).

### Competitive default — what most servers actually want

The shipped `common` class is this. Smooth modern feel, balanced damage, generous bounces:

```
"common"
{
    "behaviour"                  "homing"
    "speed"                      "950"
    "speed increment"            "250"
    "turn rate"                  "0.28"
    "turn rate increment"        "0.022"
    "damage"                     "40"
    "damage increment"           "25"
    "critical chance"            "100"
    "crit glow stack"            "2"
    "steering control"           "0.074"
    "bounce control"             "0.074"
    "max bounces"                "10000"
    "keep direction"             "1"
    "play spawn sound"           "1"
    "play beep sound"            "1"
    "play alert sound"           "1"
}
```

### Nuke — one-shot, big damage, no bouncing

```
"nuke"
{
    "name"                       "Nuke!"
    "behaviour"                  "homing"
    "speed"                      "550"
    "speed increment"            "100"
    "turn rate"                  "0.233"
    "turn rate increment"        "0.0275"
    "damage"                     "200"
    "damage increment"           "200"
    "critical chance"            "0"
    "steering control"           "0.045"
    "bounce control"             "0.045"
    "max bounces"                "0"
    "keep direction"             "1"
    "can be stolen"              "1"
    "model"                      "models/custom/dodgeball/nuke/nuke.mdl"
    "is animated"                "1"
    "beep interval"              "0.2"
    "on explode"                 "tf_dodgeball_explosion @dead ; tf_dodgeball_shockwave @dead 200 1000 1000 600"
}
```

Already shipped in `general.cfg` at 10% spawn rate. Custom model needs `models/custom/dodgeball/nuke/nuke.mdl` precached or it shows as ERROR.

---

## Per-map overrides

Want a different setup on a specific map? Create `configs/dodgeball/tfdb_<mapname>.cfg` with the same structure as `general.cfg` but only the values you want changed.

Example — make `tfdb_stadium_b3` use slower rockets:

```
"tf2_dodgeball"
{
    "classes"
    {
        "common"
        {
            "speed"           "750"
            "turn rate"       "0.20"
        }
    }
}
```

Everything else inherits from `general.cfg`. The map-specific file is loaded **after** general so it always wins.

---

## Troubleshooting

**Rockets don't home.** Check `behaviour` is `"homing"` (not `"legacy homing"` unless you specifically want that). Check the rocket actually has a target — if everyone is dead the rocket flies straight.

**Rockets feel sluggish after deflect.** Lower `steering control`. Default is `0.045`. Try `0.015` for snappy or `0.003` for instant.

**Rockets feel jittery / snappy.** Raise `steering control` toward `0.10`. Try `think interval 0.05` for the chunkier 20Hz feel.

**Bounces fling rockets out of the map.** Set `bounce ceiling` to a value like `400` to clamp the post-bounce vertical kick.

**Custom model shows as ERROR / red cube.** The model path isn't precached or `sv_pure 1` is blocking it. Either set `sv_pure 0` / `-1`, add the path to `cfg/pure_server_whitelist.txt`, or remove the `model` field so the rocket falls back to the default.

**Spawn chance doesn't add to 100.** It still works — the plugin normalizes. But spawn chances are easier to read if they sum to 100.

**Per-map cfg doesn't load.** File must be named `tfdb_<exact_mapname>.cfg` matching the actual map filename without `.bsp`. Check spelling. Workshop maps include the workshop ID prefix in some servers — check what the map actually loads as.

**Event command doesn't fire.** Check the command exists. `tf_dodgeball_print` requires the Print subplugin. `tf_dodgeball_explosion` and `tf_dodgeball_shockwave` are core commands. Run `sm cmds` in console to see what's available.

**`on kill` doesn't fire on spawn-kills.** That's by design. Use `on spawn kill` for those. Or copy the same string into both fields.

---

## Where to go next

- Open `general.cfg` in this folder and look at the `common` and `nuke` classes — they exercise most fields
- For the AI bot's config, see `pvb.cfg`
- For Guardian boss class definitions, see `guardian.cfg`
- For the full release notes, see `CHANGELOG.md` in the project root
