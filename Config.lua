BuffBuddy = BuffBuddy or {}

BuffBuddyDB_Defaults = {
    framePos    = { x = 300, y = 0 },
    enabledBuffs = {},   -- [spellId] = false to disable; absent/true means enabled
    whisperText  = "[BuffBuddy] Could you please buff me with %s?",
    groupOnly    = true,
    maxButtons   = 5,
}

-- Deep-copy default values into db without overwriting keys already set by the user.
local function ApplyDefaults(db, defaults)
    for k, v in pairs(defaults) do
        if db[k] == nil then
            if type(v) == "table" then
                db[k] = {}
                ApplyDefaults(db[k], v)
            else
                db[k] = v
            end
        end
    end
end

-- ── Addon-loaded handler ──────────────────────────────────────────────────────

local configFrame = CreateFrame("Frame")
configFrame:RegisterEvent("ADDON_LOADED")

configFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= "BuffBuddy" then return end
    self:UnregisterEvent("ADDON_LOADED")

    -- Initialise or upgrade the SavedVariables table
    if type(BuffBuddyDB) ~= "table" then
        BuffBuddyDB = {}
    end
    ApplyDefaults(BuffBuddyDB, BuffBuddyDB_Defaults)

    -- Build the UI now that we have valid settings
    if BuffBuddy.UI and BuffBuddy.UI.Initialize then
        BuffBuddy.UI:Initialize()
    end
end)

-- ── Slash commands ────────────────────────────────────────────────────────────

SLASH_BUFFBUDDY1 = "/buffbuddy"
SLASH_BUFFBUDDY2 = "/bb"

SlashCmdList["BUFFBUDDY"] = function(msg)
    local cmd = string.lower(string.match(msg, "^%s*(%S*)") or "")

    if cmd == "" then
        -- Toggle the main frame
        if BuffBuddy.UI and BuffBuddy.UI.Toggle then
            BuffBuddy.UI:Toggle()
        end

    elseif cmd == "reset" then
        if BuffBuddy.UI and BuffBuddy.UI.ResetPosition then
            BuffBuddy.UI:ResetPosition()
            print("|cffffcc00BuffBuddy:|r Frame position reset.")
        end

    elseif cmd == "debug" then
        print("|cffffcc00BuffBuddy Debug:|r Scanning group buff status...")
        local units = BuffBuddy.Core:GetGroupUnits()
        if #units == 1 then
            print("  Not in a group (showing local player only).")
        end
        for _, unit in ipairs(units) do
            if UnitIsConnected(unit) then
                local name = UnitName(unit) or unit
                local _, classFile = UnitClass(unit)
                print(string.format("|cffa0a0ff%s|r [%s]", name, classFile or "?"))
                for _, buffDef in ipairs(BuffBuddy.BUFF_DEFINITIONS) do
                    local hasBuff, remaining = BuffBuddy.Core:UnitHasBuff(unit, buffDef)
                    local status
                    if hasBuff then
                        if buffDef.maxDuration == 0 then
                            status = "|cff00ff00Active (permanent)|r"
                        else
                            status = string.format("|cff00ff00Active (%.0fs)|r", remaining)
                        end
                    else
                        status = "|cffff4040Missing|r"
                    end
                    print(string.format("    %-30s %s", buffDef.label, status))
                end
            end
        end

    else
        print("|cffffcc00BuffBuddy|r commands:")
        print("  |cffffff00/buffbuddy|r (or |cffffff00/bb|r) — toggle window")
        print("  |cffffff00/buffbuddy reset|r              — reset frame position")
        print("  |cffffff00/buffbuddy debug|r              — print group buff status")
    end
end
