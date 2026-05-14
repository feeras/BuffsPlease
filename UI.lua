BuffBuddy = BuffBuddy or {}
BuffBuddy.UI = {}

-- ── Layout constants ──────────────────────────────────────────────────────────
local FRAME_WIDTH   = 220
local TITLE_AREA    = 24   -- px from top consumed by the title + gap
local SMART_HEIGHT  = 36   -- smart-buff row height
local SEP_Y         = 62   -- y-offset (from frame top) of the separator line
local ROW_Y         = 66   -- y-offset where request rows begin
local ROW_HEIGHT    = 26
local ROW_GAP       = 2
local PADDING       = 8    -- left / right inset for all rows
local BOTTOM_PAD    = 6

local MAX_BUTTONS    = 5
local MAX_LIST_ITEMS = 10

local mainFrame
local buttonPool         = {}
local moreLabel
local smartBuffButton
local smartBuffList
local smartBuffListItems = {}

-- ── Main frame ────────────────────────────────────────────────────────────────

local function CreateMainFrame()
    local f = CreateFrame("Frame", "BuffBuddyFrame", UIParent, "BackdropTemplate")
    f:SetWidth(FRAME_WIDTH)
    f:SetHeight(TITLE_AREA + SMART_HEIGHT + BOTTOM_PAD)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.08, 0.08, 0.08, 0.92)

    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local uiScale = UIParent:GetEffectiveScale()
        x = x * uiScale - GetScreenWidth()  * uiScale / 2
        y = y * uiScale - GetScreenHeight() * uiScale / 2
        if BuffBuddyDB then
            BuffBuddyDB.framePos = { x = x, y = y }
        end
    end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", f, "TOP", 0, -5)
    title:SetText("|cffffcc00BuffBuddy|r")
    f.titleText = title

    -- Horizontal rule shown only when request rows are present
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  PADDING,  -SEP_Y)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, -SEP_Y)
    sep:SetColorTexture(0.4, 0.4, 0.4, 0.55)
    sep:Hide()
    f.separator = sep

    return f
end

-- ── Request-row button pool ───────────────────────────────────────────────────

local function CreatePoolButton(index)
    local btn = CreateFrame("Button", "BuffBuddyButton" .. index, mainFrame,
                            "SecureActionButtonTemplate")
    btn:SetWidth(FRAME_WIDTH - PADDING * 2)
    btn:SetHeight(ROW_HEIGHT)
    btn:SetAttribute("type", "empty")

    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    -- Gold left strip → whisper / request
    local strip = btn:CreateTexture(nil, "BORDER")
    strip:SetWidth(3)
    strip:SetPoint("TOPLEFT",    btn, "TOPLEFT",    0, 0)
    strip:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    strip:SetColorTexture(1, 0.78, 0, 1)
    btn.strip = strip

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", btn, "LEFT", 7, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn.icon = icon

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT",  icon,  "RIGHT", 6, 0)
    label:SetPoint("RIGHT", btn,   "RIGHT", -4, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    btn.label = label

    btn:SetScript("OnEnter", function(self)
        if self.actionData then
            local ad = self.actionData
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(GetSpellInfo(ad.buffDef.spellId) or ad.buffDef.label)
            GameTooltip:AddLine("Player: " .. (ad.targetName or "Unknown"), 1, 1, 1)
            local remaining = ad.remainingDuration or 0
            if remaining > 0 then
                GameTooltip:AddLine(string.format("Remaining: %.0fs", remaining), 0.8, 0.8, 0.8)
            else
                GameTooltip:AddLine("Remaining: None", 0.8, 0.8, 0.8)
            end
            GameTooltip:AddLine("|cffffcc00Click to whisper for buff|r")
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetScript("OnClick", function(self)
        if self.actionData and self.actionData.type == "request" then
            BuffBuddy.UI:HandleRequest(self.actionData)
        end
    end)

    btn:Hide()
    return btn
end

-- ── Smart-buff row (full-width, inside the frame) ─────────────────────────────

local function CreateSmartBuffButton()
    local btn = CreateFrame("Button", "BuffBuddySmartBuff", mainFrame,
                            "SecureActionButtonTemplate")
    btn:SetHeight(SMART_HEIGHT)
    btn:SetAttribute("type", "empty")

    -- Subtle green background tint
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0.5, 0.12, 0.13)
    btn.bg = bg

    -- Green left strip → cast
    local strip = btn:CreateTexture(nil, "BORDER")
    strip:SetWidth(3)
    strip:SetPoint("TOPLEFT",    btn, "TOPLEFT",    0, 0)
    strip:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    strip:SetColorTexture(0.15, 1, 0.3, 1)
    btn.strip = strip

    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(26, 26)
    icon:SetPoint("LEFT", btn, "LEFT", 7, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    btn.icon = icon

    -- Target name shown when a cast target exists
    local nameLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameLabel:SetPoint("LEFT",  icon, "RIGHT", 8, 0)
    nameLabel:SetPoint("RIGHT", btn,  "RIGHT", -4, 0)
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetWordWrap(false)
    btn.nameLabel = nameLabel

    -- Placeholder shown when nothing to cast
    local emptyLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyLabel:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    emptyLabel:SetText("—")
    emptyLabel:Hide()
    btn.emptyLabel = emptyLabel

    -- Dim overlay for inactive state
    local dim = btn:CreateTexture(nil, "OVERLAY")
    dim:SetAllPoints()
    dim:SetColorTexture(0, 0, 0, 0.45)
    btn.dim = dim

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.topAction then
            local ad = self.topAction
            GameTooltip:AddLine("|cff00ff00Smart Buff|r")
            GameTooltip:AddLine(GetSpellInfo(ad.buffDef.spellId) or ad.buffDef.label, 1, 1, 1)
            GameTooltip:AddLine("\226\134\146 " .. (ad.targetName or "?"), 0.8, 0.8, 0.8)
            GameTooltip:AddLine("|cffa0a0a0Right-click to choose target|r")
        else
            GameTooltip:AddLine("|cff888888Smart Buff|r")
            GameTooltip:AddLine("No targets need a buff", 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            BuffBuddy.UI:ToggleSmartBuffList()
        end
    end)

    return btn
end

-- ── Dropdown list ─────────────────────────────────────────────────────────────

local function CreateListItem(index)
    local item = CreateFrame("Button", "BuffBuddyListItem" .. index, smartBuffList,
                             "SecureActionButtonTemplate")
    item:SetHeight(26)
    item:SetAttribute("type",  "empty")
    item:SetAttribute("type2", "empty")

    item:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    local icon = item:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", item, "LEFT", 5, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    item.icon = icon

    local lbl = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("LEFT",  icon, "RIGHT", 5, 0)
    lbl:SetPoint("RIGHT", item, "RIGHT", -4, 0)
    lbl:SetJustifyH("LEFT")
    lbl:SetWordWrap(false)
    item.label = lbl

    item:SetScript("OnClick", function() smartBuffList:Hide() end)

    item:SetScript("OnEnter", function(self)
        if self.action then
            local ad = self.action
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(GetSpellInfo(ad.buffDef.spellId) or ad.buffDef.label)
            GameTooltip:AddLine(ad.targetName or "?", 1, 1, 1)
            local r = ad.remainingDuration or 0
            GameTooltip:AddLine(r > 0 and string.format("Expires in %.0fs", r) or "Not buffed",
                                0.8, 0.8, 0.8)
            GameTooltip:Show()
        end
    end)
    item:SetScript("OnLeave", function() GameTooltip:Hide() end)

    item:Hide()
    return item
end

local function CreateSmartBuffList()
    local list = CreateFrame("Frame", "BuffBuddySmartBuffList", UIParent, "BackdropTemplate")
    list:SetWidth(FRAME_WIDTH)
    list:SetFrameStrata("HIGH")
    list:EnableMouse(true)
    list:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    list:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    list:Hide()
    return list
end

-- ── Click handlers ────────────────────────────────────────────────────────────

function BuffBuddy.UI:HandleRequest(actionData)
    local spellId    = actionData.buffDef.spellId
    local targetName = actionData.targetName

    local template = (BuffBuddyDB and BuffBuddyDB.whisperText)
        or "[BuffBuddy] Could you please buff me with %s?"

    local spellName = GetSpellInfo(spellId) or actionData.buffDef.label
    local link = "[" .. spellName .. "]"

    local msg = string.format(template, link)
    SendChatMessage(msg, "WHISPER", nil, targetName)

    BuffBuddy.Core:SetRequestCooldown(targetName, spellId)
    self:Update()
end

local function BuildCastMacro(action, spellName)
    local u = action.targetUnit or ""
    if u:match("^party") or u:match("^raid") then
        return string.format("/cast [@%s,help,nodead] %s", u, spellName)
    else
        return string.format("/target %s\n/cast %s", action.targetName or "", spellName)
    end
end

function BuffBuddy.UI:ToggleSmartBuffList()
    if not smartBuffList then return end
    if smartBuffList:IsShown() then
        smartBuffList:Hide()
    else
        smartBuffList:ClearAllPoints()
        smartBuffList:SetPoint("TOPLEFT", mainFrame, "BOTTOMLEFT", 0, -4)
        smartBuffList:Show()
    end
end

-- ── Update / render ───────────────────────────────────────────────────────────

function BuffBuddy.UI:Update()
    if not mainFrame or not mainFrame:IsShown() then return end

    local allActions  = BuffBuddy.Core:GetPendingActions()
    local actions     = {}
    local castActions = {}
    for _, a in ipairs(allActions) do
        if a.type == "request" then
            table.insert(actions, a)
        else
            table.insert(castActions, a)
        end
    end

    local maxShow   = (BuffBuddyDB and BuffBuddyDB.maxButtons) or MAX_BUTTONS
    local showCount = math.min(#actions, maxShow)

    -- Frame height: fixed top section + optional rows area + bottom padding
    -- rows area = 6px (sep + gap) + N * (ROW_HEIGHT + ROW_GAP)
    local rowsArea    = showCount > 0 and (6 + showCount * (ROW_HEIGHT + ROW_GAP)) or 0
    local totalHeight = TITLE_AREA + SMART_HEIGHT + rowsArea + BOTTOM_PAD
    mainFrame:SetHeight(totalHeight)
    mainFrame.separator:SetShown(showCount > 0)

    -- ── Request rows ──────────────────────────────────────────────────────────
    for i = 1, MAX_BUTTONS do
        local btn = buttonPool[i]
        if not btn then
            btn = CreatePoolButton(i)
            buttonPool[i] = btn
        end

        local action = actions[i]
        if action and i <= showCount then
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", mainFrame, "TOPLEFT",
                PADDING, -(ROW_Y + (i - 1) * (ROW_HEIGHT + ROW_GAP)))

            local tex = GetSpellTexture(action.buffDef.spellId)
            btn.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
            btn.label:SetText(action.targetName or "Unknown")
            btn.actionData = action

            if not InCombatLockdown() then
                btn:SetAttribute("type",  "empty")
                btn:SetAttribute("spell", "")
                btn:SetAttribute("unit",  "")
            end

            btn:Show()
        else
            btn.actionData = nil
            btn:Hide()
        end
    end

    -- Overflow label
    local overflow = #actions - showCount
    if overflow > 0 then
        if not moreLabel then
            moreLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        end
        moreLabel:ClearAllPoints()
        moreLabel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT",
            PADDING, -(ROW_Y + showCount * (ROW_HEIGHT + ROW_GAP) + 2))
        moreLabel:SetText(string.format("|cffa0a0a0(+%d more)|r", overflow))
        moreLabel:Show()
    else
        if moreLabel then moreLabel:Hide() end
    end

    -- ── Smart-buff row ────────────────────────────────────────────────────────
    if not smartBuffButton then return end

    local topAction = castActions[1]
    smartBuffButton.topAction = topAction

    if topAction then
        smartBuffButton.icon:SetTexture(
            GetSpellTexture(topAction.buffDef.spellId) or "Interface\\Icons\\INV_Misc_QuestionMark")
        smartBuffButton.nameLabel:SetText(topAction.targetName or "")
        smartBuffButton.nameLabel:Show()
        smartBuffButton.emptyLabel:Hide()
        smartBuffButton.bg:SetColorTexture(0, 0.5, 0.12, 0.13)
        smartBuffButton.strip:SetColorTexture(0.15, 1, 0.3, 1)
        smartBuffButton.dim:Hide()
        if not InCombatLockdown() then
            local bestId = BuffBuddy.Core:GetBestKnownSpellId(topAction.buffDef)
            local sn = GetSpellInfo(bestId)
            if sn then
                smartBuffButton:SetAttribute("type",      "macro")
                smartBuffButton:SetAttribute("macrotext", BuildCastMacro(topAction, sn))
            else
                smartBuffButton:SetAttribute("type",      "empty")
                smartBuffButton:SetAttribute("macrotext", "")
            end
        end
    else
        smartBuffButton.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        smartBuffButton.nameLabel:Hide()
        smartBuffButton.emptyLabel:Show()
        smartBuffButton.bg:SetColorTexture(0.05, 0.05, 0.05, 0.1)
        smartBuffButton.strip:SetColorTexture(0.35, 0.35, 0.35, 1)
        smartBuffButton.dim:Show()
        if not InCombatLockdown() then
            smartBuffButton:SetAttribute("type",      "empty")
            smartBuffButton:SetAttribute("macrotext", "")
        end
    end

    -- ── Dropdown list items ───────────────────────────────────────────────────
    if not InCombatLockdown() then
        local listHeight = 8
        for i = 1, MAX_LIST_ITEMS do
            if not smartBuffListItems[i] then
                smartBuffListItems[i] = CreateListItem(i)
            end
            local item   = smartBuffListItems[i]
            local action = castActions[i]
            if action then
                local bestId = BuffBuddy.Core:GetBestKnownSpellId(action.buffDef)
                local sn = GetSpellInfo(bestId)
                if sn then
                    item:SetAttribute("type",      "macro")
                    item:SetAttribute("macrotext", BuildCastMacro(action, sn))
                else
                    item:SetAttribute("type",      "empty")
                    item:SetAttribute("macrotext", "")
                end
                item.action = action
                item.icon:SetTexture(
                    GetSpellTexture(action.buffDef.spellId) or "Interface\\Icons\\INV_Misc_QuestionMark")
                item.label:SetText(action.targetName or "Unknown")
                item:ClearAllPoints()
                item:SetWidth(smartBuffList:GetWidth() - 8)
                item:SetPoint("TOPLEFT", smartBuffList, "TOPLEFT", 4, -(4 + (i - 1) * 26))
                item:Show()
                listHeight = listHeight + 26
            else
                item.action = nil
                item:Hide()
            end
        end
        if #castActions > 0 then
            smartBuffList:SetHeight(listHeight)
        end
        if smartBuffList:IsShown() and #castActions == 0 then
            smartBuffList:Hide()
        end
    end
end

-- ── Public helpers ────────────────────────────────────────────────────────────

function BuffBuddy.UI:Toggle()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        self:Update()
    end
end

function BuffBuddy.UI:ResetPosition()
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    if BuffBuddyDB then
        BuffBuddyDB.framePos = { x = 300, y = 0 }
    end
end

function BuffBuddy.UI:Initialize()
    mainFrame = CreateMainFrame()

    if BuffBuddyDB and BuffBuddyDB.framePos then
        local pos = BuffBuddyDB.framePos
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)
    else
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    end

    -- Smart-buff button lives inside the frame, just below the title
    smartBuffButton = CreateSmartBuffButton()
    smartBuffButton:SetWidth(FRAME_WIDTH - PADDING * 2)
    smartBuffButton:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", PADDING, -TITLE_AREA)

    -- Dropdown anchors to the bottom of the main frame
    smartBuffList = CreateSmartBuffList()

    mainFrame:Show()
    self:Update()
end
