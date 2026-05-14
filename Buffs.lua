BuffBuddy = BuffBuddy or {}

-- Buffs without `priority` are suggested independently.
-- Buffs that share the same `class` AND carry a `priority` field compete per target:
-- only the lowest-priority missing spell the caster has learned is shown.
--
-- `ranks` lists every spell ID for the spell from highest rank to lowest.
-- Core:GetBestKnownSpellId() walks this list to find the highest rank the player knows.
BuffBuddy.BUFF_DEFINITIONS = {
    {
        label   = "Power Word: Fortitude",
        spellId = 21562,
        ranks   = { 21562, 10938, 10937, 2791, 1245, 1244, 1243 },
        class   = "PRIEST",
        maxDuration = 3600,
    },
    {
        label   = "Arcane Intellect",
        spellId = 10157,
        ranks   = { 10157, 10156, 1461, 1460, 1459 },
        class   = "MAGE",
        maxDuration = 3600,
    },
    {
        label   = "Mark of the Wild",
        spellId = 9885,
        ranks   = { 9885, 9884, 8907, 5234, 6756, 5232, 1126 },
        class   = "DRUID",
        maxDuration = 3600,
    },

    -- Paladin blessings use priority-based deduplication per target.
    -- Kings:    prio 1 – always offered, no class restriction.
    -- Might:    prio 2 – melee / physical-damage classes.
    -- Wisdom:   prio 2 – caster / ranged classes (disjoint from Might, so no prio clash).
    -- Sanctuary prio 3 – Paladins only, Protection talent.
    {
        label       = "Blessing of Kings",
        spellId     = 20217,
        ranks       = { 20217 },
        class       = "PALADIN",
        maxDuration = 3600,
        priority    = 1,
    },
    {
        label         = "Blessing of Might",
        spellId       = 25291,
        ranks         = { 25291, 19838, 19837, 19836, 19835, 19834, 19740 },
        class         = "PALADIN",
        maxDuration   = 3600,
        priority      = 2,
        targetClasses = { ROGUE=true, WARRIOR=true, SHAMAN=true, DRUID=true },
    },
    {
        label         = "Blessing of Wisdom",
        spellId       = 25290,
        ranks         = { 25290, 19854, 19853, 19852, 19850, 19742 },
        class         = "PALADIN",
        maxDuration   = 3600,
        priority      = 2,
        targetClasses = { PRIEST=true, MAGE=true, PALADIN=true, HUNTER=true, WARLOCK=true },
    },
    {
        label         = "Blessing of Sanctuary",
        spellId       = 25899,
        ranks         = { 25899, 20914, 20913, 20912, 20911 },
        class         = "PALADIN",
        maxDuration   = 3600,
        priority      = 3,
        targetClasses = { PALADIN=true },
    },
}