-- PapaGreet.lua

-- API Abstraction Layer (future-proof for Midnight)
local PapaGreetAPI = {}

-- Safe error handler wrapper
local function SafeCall(func, ...)
    local success, result = xpcall(func, geterrorhandler(), ...)
    if not success then
        print("|cffff0000PapaGreet Error:|r " .. tostring(result))
    end
    return success, result
end

-- Initialize API layer with version detection
function PapaGreetAPI:Initialize()
    local apiVersion = select(4, GetBuildInfo())
    self.isMidnight = apiVersion >= 120000
    self.isModern = apiVersion >= 100000
    self.isForever = apiVersion >= 16000 and apiVersion < 17000

    -- Chat API
    self.SendChatMessage = function(msg, channel)
        return SafeCall(SendChatMessage, msg, channel)
    end

    -- Emote API (ready for C_Emote in Midnight)
    if C_Emote and C_Emote.DoEmote then
        self.DoEmote = function(emote)
            SafeCall(C_Emote.DoEmote, emote)
        end
    else
        self.DoEmote = function(emote)
            SafeCall(DoEmote, emote)
        end
    end

    -- Party API
    if C_PartyInfo and C_PartyInfo.LeaveParty then
        self.LeaveParty = function()
            SafeCall(C_PartyInfo.LeaveParty)
        end
    else
        self.LeaveParty = function()
            SafeCall(LeaveGroup)
        end
    end

    -- Timer API (abstracted for Midnight compatibility)
    self.After = function(delay, func)
        local success, result = SafeCall(C_Timer.After, delay, func)
        return success and result
    end

    self.NewTimer = function(delay, func)
        local success, result = SafeCall(C_Timer.NewTimer, delay, func)
        return success and result
    end

    self.NewTicker = function(interval, func, numTicks)
        local success, result = SafeCall(C_Timer.NewTicker, interval, func, numTicks)
        return success and result
    end

end

PapaGreetAPI:Initialize()

-- Localize globals for performance
local CreateFrame = CreateFrame
local UIParent = UIParent
local math_random = math.random
local IsInGroup = IsInGroup
local IsInInstance = IsInInstance
local InCombatLockdown = InCombatLockdown
local GetInstanceInfo = GetInstanceInfo
local ToggleLFDParentFrame = ToggleLFDParentFrame
local TogglePVPUI = TogglePVPUI
local PVEFrame_ToggleFrame = PVEFrame_ToggleFrame
local IsShiftKeyDown = IsShiftKeyDown
local IsControlKeyDown = IsControlKeyDown
local print = print

-- Constants
local DEFAULT_PROFILE = "Default"
local BUTTON_ICON = "Interface\\AddOns\\PapaGreet\\Media\\Greeting.tga"
local BUTTON_SIZE = 40
local BUTTON_STRATA = "HIGH"
local BUTTON_ALPHA = 1
local SLASH_COMMAND = '/papa'

-- Initialize saved variables
local function Initialize()
    if not PapaGreetSavedVariables then
        PapaGreetSavedVariables = {
            profiles = {
                [DEFAULT_PROFILE] = {
                    greetings = {
                        "Hail, champions!",
                        "Greetings, heroes!",
                        "Greetings!",
                        "Salutations, adventurers!",
                        "Well met!",
                        "Good evening!"
                    },
                    goodbyes = {
                        "Farewell, champions. May your blade be sharp and your armor strong.",
                        "Until we meet again, heroes.",
                        "Safe travels, adventurers.",
                        "Until next time champions!",
                        "It was good traveling with you. Farewell!",
                    },
                    soloGoodbyes = {
                        "Until next time!",
                        "Time to hit the road. Safe travels!",
                        "Farewell for now!",
                        "The road calls. See you around!",
                        "Take care out there!",
                    },
                    greetingEmotes = {
                        "wave", "crack", "cheer", "charge", "brandish",
                        "bow", "hi", "hail", "nod", "grin"
                    },
                    goodbyeEmotes = {
                        "drink", "wave", "cheer", "dance", "hug",
                        "bow", "bye", "nod", "victory", "yay"
                    },
                    delayEmote = 3,
                    delayLeave = 8,
                    cooldown = 3,
                    autoLeave = not (select(4, GetBuildInfo()) >= 16000 and select(4, GetBuildInfo()) < 17000),
                    nearbyGreetings = {
                        "Well met, traveler!", "Safe travels!",
                        "Heading somewhere interesting?", "Need a hand out here?",
                        "Good to see a friendly face.",
                    },
                    campGreetings = {
                        "Mind if I join you by the fire?", "A fine place to rest. Well met!",
                        "There's room by the fire if you'd like to sit.",
                        "That fire is a welcome sight.",
                        "Rest well before the road calls again.",
                    },
                    campGoodbyes = {
                        "Thanks for the warmth. Safe travels!",
                        "The fire was welcome. Until next time!",
                        "I should be on my way. Farewell!",
                        "May your fire burn bright. Goodbye!",
                        "The road awaits. Thank you for the company!",
                    },
                    thanksMessages = {
                        "Much appreciated. I owe you one.",
                        "Thank you for the help.",
                        "That was kind of you. Thank you.",
                        "I won't forget that. Thanks.",
                        "Your help made a difference. Thank you.",
                    },
                    starterPoolsVersion = 1,
                    actionPoolsVersion = 1,
                }
            },
            currentProfile = DEFAULT_PROFILE,
            buttonPosition = { point = "CENTER", x = 0, y = 0 }
        }
    end
    PapaGreetSavedVariables.profiles = PapaGreetSavedVariables.profiles or {}
    -- Retire only the untouched preset from the previous local build. A modified
    -- Roleplay profile is user data and remains available as a custom profile.
    local oldRoleplay = PapaGreetSavedVariables.profiles.Roleplay
    local function SameMessages(actual, expected)
        if type(actual) ~= "table" or #actual ~= #expected then return false end
        for i, message in ipairs(expected) do
            if actual[i] ~= message then return false end
        end
        return true
    end
    if oldRoleplay
        and SameMessages(oldRoleplay.greetings, {
            "Well met, travelers.", "Good to have company on the road.", "The road is kinder with friends."})
        and SameMessages(oldRoleplay.goodbyes, {
            "Safe travels. Keep your eyes on the road.", "Until our paths cross again.", "May your journey be a gentle one."})
        and SameMessages(oldRoleplay.nearbyGreetings, {
            "Well met. Heading this way too?", "Care to share the road a while?"})
        and SameMessages(oldRoleplay.campGreetings, {
            "Mind if I warm myself by the fire?", "A welcome sight after a long road."})
        and SameMessages(oldRoleplay.greetingEmotes, {"wave", "bow", "nod"})
        and SameMessages(oldRoleplay.goodbyeEmotes, {"wave", "bow"})
        and oldRoleplay.delayEmote == 2 and oldRoleplay.delayLeave == 8
        and oldRoleplay.cooldown == 3 and oldRoleplay.autoLeave == false then
        PapaGreetSavedVariables.profiles.Roleplay = nil
        if PapaGreetSavedVariables.currentProfile == "Roleplay" then
            PapaGreetSavedVariables.currentProfile = DEFAULT_PROFILE
        end
    end
    -- Ensure buttonPosition exists for existing saves
    if not PapaGreetSavedVariables.buttonPosition then
        PapaGreetSavedVariables.buttonPosition = { point = "CENTER", x = 0, y = 0 }
    end
    -- Migrate existing profiles without replacing their messages or settings.
    for _, profile in pairs(PapaGreetSavedVariables.profiles) do
        if profile.cooldown == nil then profile.cooldown = 3 end
        if profile.autoLeave == nil then profile.autoLeave = not PapaGreetAPI.isForever end
        if profile.soloGoodbyes == nil then
            profile.soloGoodbyes = {
                "Until next time!", "Time to hit the road. Safe travels!",
                "Farewell for now!", "The road calls. See you around!",
                "Take care out there!",
            }
        end
        if profile.nearbyGreetings == nil then
            profile.nearbyGreetings = {"Well met, traveler!", "Safe travels!"}
        end
        if profile.campGreetings == nil then
            profile.campGreetings = {"Mind if I join you by the fire?", "A fine place to rest. Well met!"}
        end
        if profile.campGoodbyes == nil then
            profile.campGoodbyes = {
                "Thanks for the warmth. Safe travels!", "The fire was welcome. Until next time!",
                "I should be on my way. Farewell!", "May your fire burn bright. Goodbye!",
                "The road awaits. Thank you for the company!",
            }
        end
        if profile.thanksMessages == nil then
            profile.thanksMessages = {
                "Much appreciated. I owe you one.", "Thank you for the help.",
                "That was kind of you. Thank you.", "I won't forget that. Thanks.",
                "Your help made a difference. Thank you.",
            }
        end
    end
    -- Upgrade Default and profiles copied from its old two-line starter pools.
    -- The marker prevents deleted lines from returning on later reloads.
    local oldNearby = {"Well met, traveler!", "Safe travels!"}
    local oldCamp = {"Mind if I join you by the fire?", "A fine place to rest. Well met!"}
    local newNearby = {
        "Heading somewhere interesting?", "Need a hand out here?",
        "Good to see a friendly face.",
    }
    local newCamp = {
        "There's room by the fire if you'd like to sit.",
        "That fire is a welcome sight.",
        "Rest well before the road calls again.",
    }
    local function AddMissing(pool, message)
        for _, existing in ipairs(pool) do
            if existing == message then return end
        end
        pool[#pool + 1] = message
    end
    for name, profile in pairs(PapaGreetSavedVariables.profiles) do
        if not profile.starterPoolsVersion then
            if name == DEFAULT_PROFILE or SameMessages(profile.nearbyGreetings, oldNearby) then
                for _, message in ipairs(newNearby) do AddMissing(profile.nearbyGreetings, message) end
            end
            if name == DEFAULT_PROFILE or SameMessages(profile.campGreetings, oldCamp) then
                for _, message in ipairs(newCamp) do AddMissing(profile.campGreetings, message) end
            end
            profile.starterPoolsVersion = 1
        end
        -- Add a fifth line only to unchanged starter pools. The marker keeps
        -- a later user deletion from being undone on the next reload.
        if not profile.actionPoolsVersion then
            if SameMessages(profile.goodbyes, {
                "Farewell, champions. May your blade be sharp and your armor strong.",
                "Until we meet again, heroes.", "Safe travels, adventurers.",
                "Until next time champions!"}) then
                AddMissing(profile.goodbyes, "It was good traveling with you. Farewell!")
            end
            if SameMessages(profile.soloGoodbyes, {
                "Until next time!", "Time to hit the road. Safe travels!",
                "Farewell for now!", "The road calls. See you around!"}) then
                AddMissing(profile.soloGoodbyes, "Take care out there!")
            end
            if SameMessages(profile.campGoodbyes, {
                "Thanks for the warmth. Safe travels!", "The fire was welcome. Until next time!",
                "I should be on my way. Farewell!", "May your fire burn bright. Goodbye!"}) then
                AddMissing(profile.campGoodbyes, "The road awaits. Thank you for the company!")
            end
            if SameMessages(profile.thanksMessages, {
                "Much appreciated. I owe you one.", "Thank you for the help.",
                "That was kind of you. Thank you.", "I won't forget that. Thanks."}) then
                AddMissing(profile.thanksMessages, "Your help made a difference. Thank you.")
            end
            profile.actionPoolsVersion = 1
        end
    end
    return PapaGreetSavedVariables.currentProfile
end

Initialize()

-- Helper functions
local function GetProfile()
    local name = PapaGreetSavedVariables.currentProfile
    local profile = PapaGreetSavedVariables.profiles[name]
    if not profile then
        PapaGreetSavedVariables.currentProfile = DEFAULT_PROFILE
        profile = PapaGreetSavedVariables.profiles[DEFAULT_PROFILE]
    end
    return profile
end

local function DetermineChatChannel()
    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return "SAY"
end

-- A group signature prevents a delayed farewell from leaving a different group.
local function GroupSignature()
    if not IsInGroup() then return nil end
    local members = {}
    local count = GetNumGroupMembers and GetNumGroupMembers() or 0
    members[#members + 1] = UnitGUID("player") or "player"
    local prefix = IsInRaid and IsInRaid() and "raid" or "party"
    for i = 1, count do
        local guid = UnitGUID(prefix .. i)
        if guid then members[#members + 1] = guid end
    end
    table.sort(members)
    return DetermineChatChannel() .. ":" .. count .. ":" .. table.concat(members, ",")
end

local greetingQueue = {}
local pendingFarewell
local leaveTimer
local leaveCountdownTicker
local leaveDeadline
local papaGreetButton

local function Notice(message, r, g, b)
    if UIErrorsFrame then UIErrorsFrame:AddMessage(message, r or 1, g or 1, b or 1) end
end

local function StopLeaveCountdown()
    if leaveCountdownTicker then leaveCountdownTicker:Cancel(); leaveCountdownTicker = nil end
    leaveDeadline = nil
    if papaGreetButton and papaGreetButton.countdownText then
        papaGreetButton.countdownText:Hide()
    end
end

local function UpdateLeaveCountdown()
    if not leaveDeadline or not papaGreetButton then return end
    local remaining = math.max(0, math.ceil(leaveDeadline - GetTime()))
    papaGreetButton.countdownText:SetText(remaining)
    papaGreetButton.countdownText:SetShown(remaining > 0)
end

local function CancelLeave(silent)
    local hadPending = pendingFarewell ~= nil
    if pendingFarewell then pendingFarewell.cancelled = true; pendingFarewell = nil end
    if leaveTimer then leaveTimer:Cancel(); leaveTimer = nil end
    StopLeaveCountdown()
    if not silent then
        Notice(hadPending and "Pending farewell/leave canceled." or "No pending farewell/leave action.", 1, 1, 0)
    end
end

local function StartLeaveTimer(action)
    if pendingFarewell ~= action or action.cancelled then return end
    if not action.group or GroupSignature() ~= action.group then
        CancelLeave(true)
        Notice("Group changed; automatic leave canceled.", 1, 0.5, 0)
        return
    end
    local delay = math.max(0, tonumber(action.delayLeave) or 0)
    leaveDeadline = GetTime() + delay
    if delay > 0 then
        UpdateLeaveCountdown()
        leaveCountdownTicker = PapaGreetAPI.NewTicker(0.2, UpdateLeaveCountdown)
    end
    leaveTimer = PapaGreetAPI.NewTimer(delay, function()
        if pendingFarewell ~= action or action.cancelled then return end
        if GroupSignature() == action.group then
            PapaGreetAPI.LeaveParty()
        else
            Notice("Group changed; automatic leave canceled.", 1, 0.5, 0)
        end
        pendingFarewell = nil
        leaveTimer = nil
        StopLeaveCountdown()
    end)
    if not leaveTimer then CancelLeave(true) end
end

local function SendAction(action)
    if action.cancelled then return end
    if action.group and GroupSignature() ~= action.group then
        if pendingFarewell == action then CancelLeave(true) end
        Notice("Group changed; queued message canceled.", 1, 0.5, 0)
        return
    end
    local channel = action.channel or DetermineChatChannel()
    if not PapaGreetAPI.SendChatMessage(action.message, channel) then
        if pendingFarewell == action then CancelLeave(true) end
        return
    end
    if action.emote then
        PapaGreetAPI.After(action.delayEmote, function()
            if not action.cancelled then PapaGreetAPI.DoEmote(action.emote) end
        end)
    end
    if action.leave then
        PapaGreetAPI.After(action.delayEmote + 0.5, function()
            StartLeaveTimer(action)
        end)
    elseif pendingFarewell == action then
        pendingFarewell = nil
    end
end

local function QueueOrSend(action)
    if InCombatLockdown() then
        greetingQueue[#greetingQueue + 1] = action
        Notice("Message queued until combat ends.", 1, 1, 0)
    else
        SendAction(action)
    end
end

local combatEventFrame = CreateFrame("Frame")
combatEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatEventFrame:SetScript("OnEvent", function()
    local queued = greetingQueue
    greetingQueue = {}
    for _, action in ipairs(queued) do SendAction(action) end
end)

local lastSelection = {}
local function PickMessage(pool, key)
    if not pool or #pool == 0 then return nil end
    local previous = lastSelection[key]
    local choices = {}
    for _, message in ipairs(pool) do
        if message ~= previous then choices[#choices + 1] = message end
    end
    if #choices == 0 then choices = pool end
    local selected = choices[math_random(#choices)]
    lastSelection[key] = selected
    return selected
end

local function MakeAction(message, emote, delay, channel, leave)
    return {
        message = message,
        emote = emote,
        delayEmote = math.max(0, tonumber(delay) or 0),
        channel = channel,
        leave = leave,
        group = channel == "SAY" and nil or GroupSignature(),
    }
end

-- Cooldown system
local lastGreetingTime = -math.huge
local lastGoodbyeTime = -math.huge

local function IsOnCooldown(lastTime, cooldown)
    return (GetTime() - lastTime) < cooldown
end

local function GetCooldownRemaining(lastTime, cooldown)
    local remaining = cooldown - (GetTime() - lastTime)
    return remaining > 0 and remaining or 0
end

local function UpdateCooldownDisplay()
    if not papaGreetButton or not papaGreetButton.cooldown then return end

    local profile = GetProfile()
    local cooldown = profile.cooldown or 0

    if cooldown == 0 then
        papaGreetButton.cooldown:Hide()
        return
    end

    -- Check both greeting and goodbye cooldowns
    local greetCd = GetCooldownRemaining(lastGreetingTime, cooldown)
    local goodbyeCd = GetCooldownRemaining(lastGoodbyeTime, cooldown)
    local maxCd = math.max(greetCd, goodbyeCd)

    if maxCd > 0 then
        papaGreetButton.cooldown:SetCooldown(GetTime() - (cooldown - maxCd), cooldown)
        papaGreetButton.cooldown:Show()
    else
        papaGreetButton.cooldown:Hide()
    end
end

local function HandleGreeting(kind)
    local profile = GetProfile()
    local poolKey = kind == "camp" and "campGreetings" or kind == "nearby" and "nearbyGreetings" or "greetings"
    local pool = profile[poolKey]
    local cooldown = profile.cooldown or 0
    if cooldown > 0 and IsOnCooldown(lastGreetingTime, cooldown) then
        Notice(string.format("Greeting on cooldown (%.1fs remaining)", GetCooldownRemaining(lastGreetingTime, cooldown)), 1, 0.5, 0)
        return
    end
    local greeting = PickMessage(pool, PapaGreetSavedVariables.currentProfile .. ":" .. poolKey)
    if not greeting then
        Notice("No greetings configured for this action. Use /papa menu.", 1, 0, 0)
        return
    end
    local emote = PickMessage(profile.greetingEmotes, PapaGreetSavedVariables.currentProfile .. ":greetingEmotes")
    local channel = kind and "SAY" or DetermineChatChannel()
    QueueOrSend(MakeAction(greeting, emote, profile.delayEmote, channel, false))
    lastGreetingTime = GetTime()
    UpdateCooldownDisplay()
end

-- Manual RP lines always use SAY, even while grouped. They never trigger leave.
local function HandleRoleplayAction(poolKey)
    local profile = GetProfile()
    local cooldown = profile.cooldown or 0
    if cooldown > 0 and IsOnCooldown(lastGreetingTime, cooldown) then
        Notice(string.format("Action on cooldown (%.1fs remaining)", GetCooldownRemaining(lastGreetingTime, cooldown)), 1, 0.5, 0)
        return
    end
    local message = PickMessage(profile[poolKey], PapaGreetSavedVariables.currentProfile .. ":" .. poolKey)
    if not message then
        Notice("No messages configured for this action. Use /papa menu.", 1, 0, 0)
        return
    end
    QueueOrSend(MakeAction(message, nil, 0, "SAY", false))
    lastGreetingTime = GetTime()
    UpdateCooldownDisplay()
end

local function HandleGoodbye(forceLeave)
    local profile = GetProfile()
    local cooldown = profile.cooldown or 0
    if cooldown > 0 and IsOnCooldown(lastGoodbyeTime, cooldown) then
        Notice(string.format("Goodbye on cooldown (%.1fs remaining)", GetCooldownRemaining(lastGoodbyeTime, cooldown)), 1, 0.5, 0)
        return
    end
    local channel = DetermineChatChannel()
    local poolKey = channel == "SAY" and "soloGoodbyes" or "goodbyes"
    local goodbye = PickMessage(profile[poolKey], PapaGreetSavedVariables.currentProfile .. ":" .. poolKey)
    if not goodbye then
        Notice("No " .. (channel == "SAY" and "solo " or "group ") .. "goodbyes configured. Use /papa menu.", 1, 0, 0)
        return
    end
    local leave = forceLeave
    if leave == nil then leave = profile.autoLeave end
    CancelLeave(true)
    local emote = PickMessage(profile.goodbyeEmotes, PapaGreetSavedVariables.currentProfile .. ":goodbyeEmotes")
    local action = MakeAction(goodbye, emote, profile.delayEmote, channel, leave and channel ~= "SAY")
    action.delayLeave = profile.delayLeave
    if leave and action.group then pendingFarewell = action end
    QueueOrSend(action)
    lastGoodbyeTime = GetTime()
    UpdateCooldownDisplay()
end

local function OnButtonClick(self, button)
    if button == "LeftButton" then
        if IsShiftKeyDown() then
            if ToggleLFDParentFrame then ToggleLFDParentFrame() end
        elseif IsControlKeyDown() then
            TogglePapaGreetMenu()
        elseif IsAltKeyDown and IsAltKeyDown() then
            HandleGreeting("nearby")
        else
            HandleGreeting()
        end
    elseif button == "RightButton" then
        if IsShiftKeyDown() then
            if TogglePVPUI then TogglePVPUI() end
        elseif IsControlKeyDown() then
            -- Cancel leave if Control + Right Click
            CancelLeave()
        elseif IsAltKeyDown and IsAltKeyDown() then
            HandleGreeting("camp")
        else
            HandleGoodbye()
        end
    end
end

-- Create the main button
local function CreatePapaGreetButton()
    local button = CreateFrame("Button", "PapaGreetButton", UIParent, "UIPanelButtonTemplate")
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)

    button:SetNormalTexture(BUTTON_ICON)
    button:SetPushedTexture(BUTTON_ICON)
    button:SetDisabledTexture(BUTTON_ICON)

    -- Restore saved position
    local pos = PapaGreetSavedVariables.buttonPosition
    button:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:SetFrameStrata(BUTTON_STRATA)
    button:SetAlpha(BUTTON_ALPHA)
    button:EnableMouse(true)
    button:RegisterForClicks("AnyUp")
    button:Show()

    -- Add tooltips
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("PapaGreet", 1, 1, 1)
        GameTooltip:AddLine("Left Click: Greet", 0.5, 1, 0.5)
        GameTooltip:AddLine(GetProfile().autoLeave and "Right Click: Goodbye & Leave" or "Right Click: Goodbye", 1, 0.5, 0.5)
        GameTooltip:AddLine("Alt+Left: Nearby Greeting", 0.5, 1, 0.5)
        GameTooltip:AddLine("Alt+Right: Campsite Greeting", 1, 0.8, 0.5)
        GameTooltip:AddLine("Ctrl+Left: Settings", 0.5, 0.5, 1)
        GameTooltip:AddLine("Ctrl+Right: Cancel Pending Leave", 1, 1, 0)
        GameTooltip:AddLine("Shift+Left: LFD", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Shift+Right: PVP", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Middle Drag: Move", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Create countdown text overlay
    button.countdownText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    button.countdownText:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.countdownText:SetTextColor(1, 0, 0, 1)
    button.countdownText:Hide()

    -- Create cooldown frame overlay
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button)
    button.cooldown:SetDrawEdge(true)
    button.cooldown:SetDrawSwipe(true)
    button.cooldown:SetReverse(false)
    button.cooldown:Hide()

    button:SetScript("OnMouseDown", function(self, button)
        if button == "MiddleButton" then
            self:StartMoving()
        end
    end)

    button:SetScript("OnMouseUp", function(self, button)
        if button == "MiddleButton" then
            self:StopMovingOrSizing()
            -- Save position
            local point, _, _, x, y = self:GetPoint()
            PapaGreetSavedVariables.buttonPosition = { point = point, x = x, y = y }
            return
        end
        OnButtonClick(self, button)
    end)

    return button
end

papaGreetButton = CreatePapaGreetButton()

-- Keybindings
BINDING_HEADER_PAPAGREET = "PapaGreet"
BINDING_NAME_PAPAGREET_GREET = "Send Greeting"
BINDING_NAME_PAPAGREET_GOODBYE = "Send Goodbye"
BINDING_NAME_PAPAGREET_LEAVE = "Send Goodbye & Leave"
BINDING_NAME_PAPAGREET_NEARBY = "Nearby Greeting"
BINDING_NAME_PAPAGREET_CAMP = "Campsite Greeting"
BINDING_NAME_PAPAGREET_CAMPBYE = "Leave Campsite"
BINDING_NAME_PAPAGREET_THANKS = "Thank Someone"
BINDING_NAME_PAPAGREET_CANCEL = "Cancel Leave"
BINDING_NAME_PAPAGREET_MENU = "Toggle Menu"

function PapaGreet_SendGreeting()
    HandleGreeting()
end

function PapaGreet_SendGoodbye()
    HandleGoodbye()
end

function PapaGreet_SendGoodbyeAndLeave()
    HandleGoodbye(true)
end

function PapaGreet_SendNearbyGreeting()
    HandleGreeting("nearby")
end

function PapaGreet_SendCampGreeting()
    HandleGreeting("camp")
end

function PapaGreet_LeaveCamp()
    HandleRoleplayAction("campGoodbyes")
end

function PapaGreet_SendThanks()
    HandleRoleplayAction("thanksMessages")
end

function PapaGreet_CancelLeave()
    CancelLeave()
end

function PapaGreet_ToggleMenu()
    TogglePapaGreetMenu()
end

-- Slash command handling
SLASH_PAPA1 = SLASH_PAPA1 or '/papa'

SlashCmdList["PAPA"] = function(cmd)
    local command, arg = cmd:match("^(%S*)%s*(.-)$")

    if not command or command == "" then
        print("|cff00ff00PapaGreet Commands:|r")
        print("  |cffffd700/papa greet|r - Send greeting")
        print("  |cffffd700/papa bye|r - Send goodbye (uses profile leave setting)")
        print("  |cffffd700/papa byeonly|r - Send goodbye without leaving")
        print("  |cffffd700/papa leave|r - Send goodbye and leave")
        print("  |cffffd700/papa nearby|r - Greet nearby players in SAY")
        print("  |cffffd700/papa camp|r - Campsite greeting in SAY")
        print("  |cffffd700/papa campbye|r - Leave a campsite in SAY")
        print("  |cffffd700/papa thanks|r - Thank someone in SAY")
        print("  |cffffd700/papa cancel|r - Cancel leave timer")
        print("  |cffffd700/papa menu|r - Toggle settings menu")
        print("  |cffffd700/papa hide|r - Hide button")
        print("  |cffffd700/papa show|r - Show button")
        print("  |cffffd700/papa reset|r - Reset button position")
        print("  |cffffd700/papa cd [seconds]|r - Set cooldown (0=off)")
        print("  |cffffd700/papa version|r - Show version")
        return
    end

    if command == "greet" then
        HandleGreeting()
    elseif command == "bye" or command == "goodbye" then
        HandleGoodbye()
    elseif command == "byeonly" then
        HandleGoodbye(false)
    elseif command == "leave" then
        HandleGoodbye(true)
    elseif command == "nearby" then
        HandleGreeting("nearby")
    elseif command == "camp" then
        HandleGreeting("camp")
    elseif command == "campbye" then
        HandleRoleplayAction("campGoodbyes")
    elseif command == "thanks" then
        HandleRoleplayAction("thanksMessages")
    elseif command == "cancel" then
        CancelLeave()
    elseif command == "menu" then
        TogglePapaGreetMenu()
    elseif command == "hide" then
        papaGreetButton:Hide()
        print("PapaGreet button hidden. Use |cffffd700/papa show|r to show it.")
    elseif command == "show" then
        papaGreetButton:Show()
        print("PapaGreet button shown.")
    elseif command == "reset" then
        PapaGreetSavedVariables.buttonPosition = { point = "CENTER", x = 0, y = 0 }
        papaGreetButton:ClearAllPoints()
        papaGreetButton:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        print("PapaGreet button position reset to center.")
    elseif command == "cd" or command == "cooldown" then
        local value = tonumber(arg)
        if value and value >= 0 then
            local profile = GetProfile()
            profile.cooldown = math.floor(value)
            if value == 0 then
                print("Cooldown disabled.")
            else
                print(string.format("Cooldown set to %d seconds.", value))
            end
        else
            print("Usage: /papa cd [seconds] (0 to disable)")
        end
    elseif command == "version" or command == "v" then
        print("|cff00ff00PapaGreet|r version |cffffd7001.4.1|r")
    else
        print("|cffff0000Unknown command:|r " .. command)
        print("Type |cffffd700/papa|r for help.")
    end
end
