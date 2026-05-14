BuffBuddy = BuffBuddy or {}
BuffBuddy.Core = {}

-- [playerName .. tostring(spellId)] = GetTime() of last whisper
local requestCooldowns = {}
local REQUEST_COOLDOWN = 60

local coreFrame = CreateFrame("Frame")
coreFrame:RegisterEvent("PLAYER_LOGIN")
coreFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
coreFrame:RegisterEvent("UNIT_AURA")
coreFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
coreFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
coreFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

coreFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        BuffBuddy.playerClass = select(2, UnitClass("player"))
        BuffBuddy.Core:Initialize()
    else
        BuffBuddy.Core:Refresh()
    end
end)

function BuffBuddy.Core:Initialize()
    C_Timer.NewTicker(5, function()
        BuffBuddy.Core:Refresh()
    end)
    self:Refresh()
end

function BuffBuddy.Core:Refresh()
    if BuffBuddy.UI and BuffBuddy.UI.Update then
        BuffBuddy.UI:Update()
    end
end

-- Returns a flat list of unit IDs in the current group, always including "player".
function BuffBuddy.Core:GetGroupUnits()
    local units = { "player" }

    local inRaid  = IsInRaid  and IsInRaid()  or false
    local inGroup = IsInGroup and IsInGroup() or false

    if inRaid then
        for i = 1, 40 do
            local unit = "raid" .. i
            -- UnitIsUnit avoids duplicating the local player (who appears in raidX slots too)
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                table.insert(units, unit)
            end
        end
    elseif inGroup then
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                table.insert(units, unit)
            end
        end
    end

    return units
end

-- Returns non-group friendly player unit IDs visible on nearby nameplates.
-- Requires friendly nameplates to be enabled in the WoW interface options.
function BuffBuddy.Core:GetNearbyUnits(groupUnits)
    local nearby = {}
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then
        return nearby
    end
    for _, np in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = np.namePlateUnitToken
        if unit and UnitExists(unit) and UnitIsPlayer(unit)
        and UnitIsFriend("player", unit) then
            local dup = false
            for _, g in ipairs(groupUnits) do
                if UnitIsUnit(unit, g) then dup = true; break end
            end
            if not dup then
                for _, n in ipairs(nearby) do
                    if UnitIsUnit(unit, n) then dup = true; break end
                end
            end
            if not dup then table.insert(nearby, unit) end
        end
    end
    return nearby
end

-- Returns hasBuff (bool), remainingSeconds (number), activeSpellId (number|nil), duration (number).
-- duration is the total buff duration as reported by the server (0 when unknown/permanent).
function BuffBuddy.Core:UnitHasBuff(unit, buffDef)
    local targetTexture = GetSpellTexture(buffDef.spellId)
    if not targetTexture then
        return false, 0, nil, 0
    end

    local i = 1
    while true do
        local _, icon, _, _, duration, expirationTime, _, _, _, buffSpellId = UnitBuff(unit, i)
        if not icon then break end

        if icon == targetTexture then
            local remaining = 0
            if expirationTime and expirationTime > 0 then
                remaining = expirationTime - GetTime()
                if remaining < 0 then remaining = 0 end
            end
            return true, remaining, buffSpellId, duration or 0
        end
        i = i + 1
    end

    return false, 0, nil, 0
end

-- Returns true when the unit is online, not AFK, and not DND.
local function UnitIsAvailable(unit)
    return UnitIsConnected(unit)
       and not UnitIsAFK(unit)
       and not UnitIsDND(unit)
end

-- Returns true when a buff should be (re)applied.
-- Uses the actual duration reported by UnitBuff so we never depend on hardcoded maxDuration values.
-- Only triggers when both remaining and duration are known (> 0).
local function NeedsBuff(hasBuff, remaining, duration, buffDef)
    if not hasBuff then return true end
    if buffDef.maxDuration == 0 then return false end         -- permanent / self-managed aura
    if remaining <= 0 or duration <= 0 then return false end  -- duration unknown, leave it alone
    return (duration - remaining) > 600                       -- more than 10 min have elapsed
end

-- Returns true when the player's best known rank is higher than the rank
-- currently on the unit (i.e., an upgrade is available).
local function HasHigherRank(buffDef, playerBestId, unitActiveId)
    if not (buffDef.ranks and playerBestId and unitActiveId) then return false end
    if playerBestId == unitActiveId then return false end
    for _, id in ipairs(buffDef.ranks) do
        if id == playerBestId then return true end   -- player rank found first → higher
        if id == unitActiveId  then return false end -- target rank found first → lower/equal
    end
    return false
end

-- Returns true when buffDef is relevant for the given class token.
-- Buffs without targetClasses apply to every class.
local function BuffAppliesToClass(buffDef, classToken)
    if not buffDef.targetClasses then return true end
    return buffDef.targetClasses[classToken or ""] == true
end

-- Returns true when the local player knows any rank of buffDef's spell.
local function PlayerKnowsBuff(buffDef)
    if not IsSpellKnown then return false end
    if buffDef.ranks then
        for _, id in ipairs(buffDef.ranks) do
            if IsSpellKnown(id) then return true end
        end
        return false
    end
    return IsSpellKnown(buffDef.spellId)
end

-- For buff definitions that carry a `priority` field, collapse candidates down to
-- the single best (lowest priority number) missing spell per target and per request.
-- Non-priority buffs pass through untouched.
local function DeduplicatePriorityBuffs(actions)
    local normal         = {}
    local bestCastByUnit = {}  -- [targetUnit] = action with the lowest priority so far
    local bestRequest    = nil -- single lowest-priority request action

    for _, action in ipairs(actions) do
        if action.buffDef.priority then
            if action.type == "cast" then
                local cur = bestCastByUnit[action.targetUnit]
                if not cur or action.buffDef.priority < cur.buffDef.priority then
                    bestCastByUnit[action.targetUnit] = action
                end
            else  -- "request"
                if not bestRequest or action.buffDef.priority < bestRequest.buffDef.priority then
                    bestRequest = action
                end
            end
        else
            table.insert(normal, action)
        end
    end

    for _, action in pairs(bestCastByUnit) do
        table.insert(normal, action)
    end
    if bestRequest then
        table.insert(normal, bestRequest)
    end

    return normal
end

-- Returns the highest rank of buffDef that the local player knows, or buffDef.spellId as fallback.
function BuffBuddy.Core:GetBestKnownSpellId(buffDef)
    if buffDef.ranks and IsSpellKnown then
        for _, id in ipairs(buffDef.ranks) do
            if IsSpellKnown(id) then return id end
        end
    end
    return buffDef.spellId
end

function BuffBuddy.Core:IsBuffEnabled(spellId)
    if BuffBuddyDB and BuffBuddyDB.enabledBuffs then
        if BuffBuddyDB.enabledBuffs[spellId] == false then
            return false
        end
    end
    return true
end

function BuffBuddy.Core:IsRequestOnCooldown(targetName, spellId)
    local key = (targetName or "") .. tostring(spellId)
    local last = requestCooldowns[key]
    return last and (GetTime() - last) < REQUEST_COOLDOWN
end

function BuffBuddy.Core:SetRequestCooldown(targetName, spellId)
    local key = (targetName or "") .. tostring(spellId)
    requestCooldowns[key] = GetTime()
end

-- Builds and returns the list of pending buff actions to display.
-- Each entry: { type, buffDef, targetUnit, targetName, remainingDuration }
--   type = "request"  → local player needs this buff from targetName
--   type = "cast"     → local player can give this buff to targetUnit/targetName
function BuffBuddy.Core:GetPendingActions()
    local actions        = {}
    local requestedBuffs = {}   -- tracks spellIds already covered by a "request" entry
    local units          = self:GetGroupUnits()

    -- Pre-cache each unit's class so we don't call UnitClass repeatedly.
    local unitClass = {}
    for _, unit in ipairs(units) do
        if UnitIsAvailable(unit) then
            unitClass[unit] = select(2, UnitClass(unit))
        end
    end

    for _, buffDef in ipairs(BuffBuddy.BUFF_DEFINITIONS) do
        if self:IsBuffEnabled(buffDef.spellId) then

            -- 1. Does the local player need this buff?
            local playerHas, playerRemaining, _, playerDuration = self:UnitHasBuff("player", buffDef)
            if NeedsBuff(playerHas, playerRemaining, playerDuration, buffDef)
            and BuffAppliesToClass(buffDef, BuffBuddy.playerClass) then
                -- Find the first available group member who can provide it.
                for _, unit in ipairs(units) do
                    if unit ~= "player"
                    and UnitIsAvailable(unit)
                    and unitClass[unit] == buffDef.class then
                        local targetName = UnitName(unit)  -- may be "Name-Realm" cross-realm
                        if not self:IsRequestOnCooldown(targetName, buffDef.spellId) then
                            table.insert(actions, {
                                type             = "request",
                                buffDef          = buffDef,
                                targetUnit       = unit,
                                targetName       = targetName,
                                remainingDuration = playerRemaining,
                            })
                            requestedBuffs[buffDef.spellId] = true
                        end
                        break  -- one request entry per buff type
                    end
                end
            end

            -- 2. Can the local player cast this buff for others?
            if BuffBuddy.playerClass == buffDef.class then
                local playerBestId = self:GetBestKnownSpellId(buffDef)
                for _, unit in ipairs(units) do
                    if unit ~= "player" and UnitIsAvailable(unit) then
                        local unitHas, unitRemaining, unitActiveId, unitDuration = self:UnitHasBuff(unit, buffDef)
                        if (NeedsBuff(unitHas, unitRemaining, unitDuration, buffDef)
                            or HasHigherRank(buffDef, playerBestId, unitActiveId))
                        and BuffAppliesToClass(buffDef, unitClass[unit])
                        and (not buffDef.priority or PlayerKnowsBuff(buffDef)) then
                            table.insert(actions, {
                                type             = "cast",
                                buffDef          = buffDef,
                                targetUnit       = unit,
                                targetName       = UnitName(unit),
                                remainingDuration = unitRemaining,
                            })
                        end
                    end
                end
            end

        end
    end

    -- Also scan any non-group players currently targeted or moused over.
    local nearbyUnits = self:GetNearbyUnits(units)
    for _, unit in ipairs(nearbyUnits) do
        local _, strangerClass = UnitClass(unit)
        local strangerName = UnitName(unit)

        for _, buffDef in ipairs(BuffBuddy.BUFF_DEFINITIONS) do
            if self:IsBuffEnabled(buffDef.spellId) then

                -- Can this stranger provide a buff I need?
                if strangerClass == buffDef.class
                and not requestedBuffs[buffDef.spellId] then
                    local playerHas, playerRemaining, _, playerDuration = self:UnitHasBuff("player", buffDef)
                    if NeedsBuff(playerHas, playerRemaining, playerDuration, buffDef)
                    and BuffAppliesToClass(buffDef, BuffBuddy.playerClass)
                    and not self:IsRequestOnCooldown(strangerName, buffDef.spellId) then
                        table.insert(actions, {
                            type             = "request",
                            buffDef          = buffDef,
                            targetUnit       = unit,
                            targetName       = strangerName,
                            remainingDuration = playerRemaining,
                        })
                        requestedBuffs[buffDef.spellId] = true
                    end
                end

                -- Can I provide a buff this stranger needs?
                if BuffBuddy.playerClass == buffDef.class then
                    local playerBestId = self:GetBestKnownSpellId(buffDef)
                    local unitHas, unitRemaining, unitActiveId, unitDuration = self:UnitHasBuff(unit, buffDef)
                    if (NeedsBuff(unitHas, unitRemaining, unitDuration, buffDef)
                        or HasHigherRank(buffDef, playerBestId, unitActiveId))
                    and BuffAppliesToClass(buffDef, strangerClass or "")
                    and (not buffDef.priority or PlayerKnowsBuff(buffDef)) then
                        table.insert(actions, {
                            type             = "cast",
                            buffDef          = buffDef,
                            targetUnit       = unit,
                            targetName       = strangerName,
                            remainingDuration = unitRemaining,
                        })
                    end
                end

            end
        end
    end

    return DeduplicatePriorityBuffs(actions)
end
