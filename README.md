# BuffBuddy

A lightweight World of Warcraft Classic Era addon that shows you which buffs are
missing and lets you request or cast them with a single click — works for both
group/raid members and any stranger you target or mouse over.

No external libraries are required — only native Blizzard Lua API.

---

## What it does

* Scans your group/raid every 5 seconds (and on roster/aura changes).
* Also detects your current **target** and **mouseover** unit — works on any
  player, including strangers in cities or the open world.
* Shows up to 5 action buttons in a small draggable HUD:
  * **Yellow border — Request**: you are missing a buff; click to whisper the
    player (group member or stranger) asking for it.
  * **Green border — Cast**: another player is missing a buff you can provide;
    click to target them and cast it instantly.
* Spell links in whispers are localised automatically — the addon works on any
  game client language.
* Spam protection: whisper requests are throttled to once per 60 seconds per
  (player + spell) combination.

---

## Installation

1. Download or clone this repository.
2. Copy the `BuffBuddy` folder into your addons directory:

   ```
   World of Warcraft\_classic_era_\Interface\AddOns\BuffBuddy\
   ```

3. Launch the game (or `/reload` if already logged in).
4. Enable **BuffBuddy** on the character-select AddOns screen.

---

## Slash commands

| Command | Description |
|---|---|
| `/buffbuddy` or `/bb` | Toggle the BuffBuddy window |
| `/buffbuddy reset` | Reset the window to its default position |
| `/buffbuddy debug` | Print the full buff status of all group members to chat |

---

## Known limitations

### Strangers require target or mouseover

The Classic Era client API does not expose a list of all players in the vicinity.
BuffBuddy detects strangers by checking your current **target** (`UnitBuff("target")`)
and **mouseover** unit (`UnitBuff("mouseover")`). A stranger's buffs are only visible
while they are your active target or mouseover — the addon cannot scan players you
are not interacting with.

Practical use: point your cursor at someone in a city to instantly see whether you
can buff them or ask them for a buff.

### Cross-realm players

`UnitName(unit)` returns `"Name-Realm"` for cross-realm group members. BuffBuddy
uses this full string as the whisper target, which is required for the message
to be delivered correctly.

### Spell texture cache

Buff matching relies on `GetSpellTexture(spellId)`. If the client has not yet
cached a spell (e.g. a spell your character has never seen), the texture may
return `nil` and the buff will not be detected until the cache is warm. This
resolves itself after a few seconds or on the first encounter with the spell.

---

## Adding custom buffs

Edit `Buffs.lua` and append an entry to `BuffBuddy.BUFF_DEFINITIONS`:

```lua
{ label = "My Buff Name", spellId = 12345, class = "SHAMAN", maxDuration = 1800 },
```

* `label`       — displayed in the UI only; never used for any game API call.
* `spellId`     — the numeric spell ID (look it up on wowhead.com).
* `class`       — the English class token in ALL CAPS (e.g. `"SHAMAN"`, `"ROGUE"`).
* `maxDuration` — buff duration in seconds; use `0` for permanent auras (presence
                  check only, no expiry warning).

---

## Configuration (SavedVariables)

`BuffBuddyDB` is saved per account in `WTF/Account/<name>/SavedVariables/BuffBuddy.lua`.

| Key | Default | Description |
|---|---|---|
| `framePos` | `{x=300, y=0}` | HUD position (set automatically on drag) |
| `enabledBuffs` | `{}` | Set `[spellId] = false` to disable a specific buff |
| `whisperText` | see below | Whisper template; `%s` is replaced with the spell link |
| `groupOnly` | `true` | Reserved for future use |
| `maxButtons` | `5` | Maximum buttons shown in the HUD |

Default whisper template:
```
[BuffBuddy] Could you please buff me with %s?
```
