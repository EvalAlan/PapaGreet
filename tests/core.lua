-- Focused WoW API simulation for chat routing and delayed leave safety.
local now, combat, group, channelMessages, leaves = 0, false, nil, {}, 0
local timers, frames = {}, {}
local function timer(delay, callback, interval)
    local item = {at = now + delay, callback = callback, interval = interval}
    function item:Cancel() self.cancelled = true end
    timers[#timers + 1] = item
    return item
end
local function advance(seconds)
    local target = now + seconds
    while true do
        local nextItem
        for _, item in ipairs(timers) do
            if not item.cancelled and item.at <= target and (not nextItem or item.at < nextItem.at) then nextItem = item end
        end
        if not nextItem then break end
        now = nextItem.at
        if nextItem.interval then nextItem.at = nextItem.at + nextItem.interval else nextItem.cancelled = true end
        nextItem.callback()
    end
    now = target
end
local function frame(name)
    local obj = {name = name}
    setmetatable(obj, {__index = function(_, key)
        if key == "GetPoint" then return function() return "CENTER", nil, nil, 0, 0 end end
        if key == "SetNormalTexture" then return function(self, texture) self.normalTexture = texture end end
        if key == "GetName" then return function() return name end end
        if key == "CreateFontString" then return function() return frame(nil) end end
        return function(self, ...)
            if key == "SetScript" then
                local scripts = rawget(self, "scripts") or {}
                rawset(self, "scripts", scripts)
                scripts[(...)] = select(2, ...)
            elseif key == "SetSize" then
                self.width, self.height = ...
            elseif key == "SetText" then
                self.text = ...
            elseif key == "SetShown" then
                self.shown = ...
            elseif key == "Show" then
                self.shown = true
            elseif key == "Hide" then
                self.shown = false
            elseif key == "IsShown" then
                return self.shown
            end
        end
    end})
    frames[#frames + 1] = obj
    return obj
end
_G.UIParent = frame("UIParent")
_G.UIErrorsFrame = frame("UIErrorsFrame")
_G.GameTooltip = frame("GameTooltip")
_G.SlashCmdList = {}
_G.CreateFrame = function(kind, name)
    local obj = frame(name)
    if name then
        _G[name] = obj
        if kind == "CheckButton" then _G[name .. "Text"] = frame(name .. "Text") end
    end
    return obj
end
_G.GetBuildInfo = function() return "1.60.1", "70862", "", 16001 end
_G.GetTime = function() return now end
_G.GetSpellTexture = function() return 123 end
_G.geterrorhandler = function() return error end
_G.InCombatLockdown = function() return combat end
_G.IsInGroup = function(category) return group and (not category or group.instance) or false end
_G.IsInRaid = function() return group and group.raid or false end
_G.GetNumGroupMembers = function() return group and #group.members or 0 end
_G.UnitGUID = function(unit)
    if not group then return unit == "player" and "self" or nil end
    if unit == "player" then return "self" end
    local index = tonumber(unit:match("%d+"))
    return index and group.members[index]
end
_G.LE_PARTY_CATEGORY_INSTANCE = 2
_G.SendChatMessage = function(message, channel) channelMessages[#channelMessages + 1] = {message, channel} end
_G.DoEmote = function() end
_G.LeaveGroup = function() leaves = leaves + 1 end
_G.C_Timer = {After = function(d, f) timer(d, f) end, NewTimer = function(d, f) return timer(d, f) end,
    NewTicker = function(d, f) return timer(d, f, d) end}
_G.IsShiftKeyDown = function() return false end
_G.IsControlKeyDown = function() return false end
local altDown = false
_G.IsAltKeyDown = function() return altDown end
_G.C_Spell = nil
_G.C_PartyInfo = nil
_G.C_Emote = nil

dofile("PapaGreet.lua")
assert(PapaGreetButton.normalTexture == "Interface\\AddOns\\PapaGreet\\Media\\Greeting.tga", "stable button texture")
local function send(command)
    SlashCmdList.PAPA(command)
    return channelMessages[#channelMessages]
end
local function eq(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function cooldownOff() PapaGreetSavedVariables.profiles.Default.cooldown = 0 end
cooldownOff()
eq(PapaGreetSavedVariables.profiles.Default.autoLeave, false, "Forever default leave")
eq(send("greet")[2], "SAY", "solo")
local solo = PapaGreetSavedVariables.profiles.Default.soloGoodbyes
eq(#solo, 5, "solo goodbye defaults")
for _, message in ipairs(solo) do
    assert(not message:lower():find("heroes") and not message:lower():find("friends"), "solo line avoids plural address")
end
local soloFarewell = send("bye")
eq(soloFarewell[2], "SAY", "solo goodbye channel")
local inSoloPool = false
for _, message in ipairs(solo) do
    if soloFarewell[1] == message then inSoloPool = true end
end
assert(inSoloPool, "solo goodbye pool")
local soloLeaves = leaves
send("leave")
advance(20)
eq(leaves, soloLeaves, "explicit leave while solo does not leave")
PapaGreetSavedVariables.profiles.Default.soloGoodbyes = {"See you soon."}
eq(send("bye")[1], "See you soon.", "solo goodbye can be customized")
PapaGreetSavedVariables.profiles.Default.soloGoodbyes = solo
group = {members = {"other"}}
local groupFarewell = send("bye")[1]
local inGroupPool = false
for _, message in ipairs(PapaGreetSavedVariables.profiles.Default.goodbyes) do
    if groupFarewell == message then inGroupPool = true end
end
assert(inGroupPool, "group goodbye still uses group pool")
eq(send("greet")[2], "PARTY", "party")
group.raid = true
group.members = {"self", "other"}
eq(send("greet")[2], "RAID", "raid")
group.instance = true
eq(send("greet")[2], "INSTANCE_CHAT", "instance group")
group = {members = {"other"}}
local before = leaves
send("bye")
advance(20)
eq(leaves, before, "goodbye only")
send("leave")
send("cancel")
advance(20)
eq(leaves, before, "cancel delayed leave")
combat = true
local sent = #channelMessages
send("leave")
send("cancel")
combat = false
for _, f in ipairs(frames) do local scripts = rawget(f, "scripts"); if scripts and scripts.OnEvent then scripts.OnEvent() end end
eq(#channelMessages, sent, "cancel queued farewell")
send("leave")
group.members = {"new-other"}
advance(20)
eq(leaves, before, "changed group")
group.members = {"other"}
send("leave")
advance(20)
eq(leaves, before + 1, "explicit leave")
local old = PapaGreetSavedVariables.profiles.Default.greetings
PapaGreetSavedVariables.profiles.Other = {greetings={"Other profile"}, greetingEmotes={}, goodbyes={"Other bye"}, goodbyeEmotes={}, delayEmote=0, delayLeave=1, cooldown=0, autoLeave=false}
PapaGreetSavedVariables.currentProfile = "Other"
eq(send("greet")[1], "Other profile", "profile switch")
PapaGreetSavedVariables.currentProfile = "Default"
PapaGreetSavedVariables.profiles.Default.greetings = {"one", "two"}
local first = send("greet")[1]
local second = send("greet")[1]
assert(first ~= second, "no immediate repeat")
PapaGreetSavedVariables.profiles.Default.greetings = old
eq(send("nearby")[2], "SAY", "nearby channel")
eq(send("camp")[2], "SAY", "camp channel")
local campDeparture = send("campbye")
eq(campDeparture[2], "SAY", "camp departure stays in SAY while grouped")
local inCampGoodbyes = false
for _, message in ipairs(PapaGreetSavedVariables.profiles.Default.campGoodbyes) do
    if campDeparture[1] == message then inCampGoodbyes = true end
end
assert(inCampGoodbyes, "camp departure uses its own pool")
local thanksMessage = send("thanks")
eq(thanksMessage[2], "SAY", "thanks stays in SAY while grouped")
local inThanks = false
for _, message in ipairs(PapaGreetSavedVariables.profiles.Default.thanksMessages) do
    if thanksMessage[1] == message then inThanks = true end
end
assert(inThanks, "thanks uses its own pool")
local beforeRoleplayLeaves = leaves
advance(20)
eq(leaves, beforeRoleplayLeaves, "manual RP actions never leave group")
local beforeAltClick = #channelMessages
altDown = true
PapaGreetButton.scripts.OnMouseUp(PapaGreetButton, "RightButton")
altDown = false
eq(#channelMessages, beforeAltClick + 1, "alt-right sends a message")
eq(channelMessages[#channelMessages][2], "SAY", "alt-right campsite channel")
local campMessage = channelMessages[#channelMessages][1]
local inCampPool = false
for _, message in ipairs(PapaGreetSavedVariables.profiles.Default.campGreetings) do
    if campMessage == message then inCampPool = true end
end
assert(inCampPool, "alt-right uses campsite messages")
_G.StaticPopupDialogs = {}
_G.UIDropDownMenu_CreateInfo = function() return {} end
local dropdownCallbacks, dropdownEntries = {}, {}
_G.UIDropDownMenu_AddButton = function(info, level)
    local entries = dropdownEntries[level or 1] or {}
    entries[#entries + 1] = info
    dropdownEntries[level or 1] = entries
end
_G.UIDropDownMenu_Initialize = function(dropdown, callback)
    dropdownCallbacks[dropdown] = callback
    callback(dropdown, 1) -- WoW invokes the initializer during setup.
end
_G.UIDropDownMenu_SetSelectedValue = function() end
_G.UIDropDownMenu_SetText = function(dropdown, value) dropdown.text = value end
local shownPopup
_G.StaticPopup_Show = function(which, _, _, data) shownPopup = {which = which, data = data} end
_G.CloseDropDownMenus = function() end
_G.StaticPopup_OnClick = function() end
_G.StaticPopup_Hide = function() end
dofile("PapaGreetMenu.lua")
PapaGreetSavedVariables.profiles.Default.soloGoodbyes = nil
PapaGreetSavedVariables.profiles.Default.delayEmote = 0
ShowPapaGreetMenu()
eq(PapaGreetMenu.height, 550, "menu fits a smaller screen")
eq(PapaGreetSavedVariables.profiles.Default.delayEmote, 0, "menu keeps zero emote delay")
eq(PapaGreetDelayEditBox.text, 0, "menu displays zero emote delay")
eq(PapaGreetMessagesTab.text, "[Messages]", "message tab is labeled")
eq(PapaGreetRPTab.text, "RP / Camp", "RP tab is labeled")
eq(#PapaGreetSavedVariables.profiles.Default.soloGoodbyes, 5, "menu open restores missing solo starter pool")
assert(PapaGreetMessagePanel.shown and not PapaGreetRPPanel.shown, "message section starts visible")
PapaGreetRPTab.scripts.OnClick()
assert(PapaGreetRPPanel.shown and not PapaGreetMessagePanel.shown, "RP and camp section opens")
_G.PapaGreetAddCampButton.scripts.OnClick()
eq(shownPopup.which, "PAPA_GREET_ADD_CAMP", "camp greeting control is reachable")
_G.PapaGreetAddCampGoodbyeButton.scripts.OnClick()
eq(shownPopup.which, "PAPA_GREET_ADD_CAMP_GOODBYE", "camp goodbye control is reachable")
PapaGreetMessagesTab.scripts.OnClick()
assert(PapaGreetMessagePanel.shown and not PapaGreetRPPanel.shown, "message section reopens")
assert(_G.PapaGreetAddNearbyButton and _G.PapaGreetAddCampButton and _G.PapaGreetAutoLeaveCheck, "new menu controls")
assert(StaticPopupDialogs.PAPA_GREET_ADD_NEARBY and StaticPopupDialogs.PAPA_GREET_ADD_CAMP, "new pool popups")
assert(_G.PapaGreetAddSoloGoodbyeButton and _G.PapaGreetDeleteSoloGoodbyeDropdown, "solo goodbye menu controls")
assert(StaticPopupDialogs.PAPA_GREET_ADD_SOLO_GOODBYE, "solo goodbye popup")
assert(_G.PapaGreetAddCampGoodbyeButton and _G.PapaGreetAddThanksButton, "new RP menu controls")
assert(StaticPopupDialogs.PAPA_GREET_ADD_CAMP_GOODBYE and StaticPopupDialogs.PAPA_GREET_ADD_THANKS, "new RP popups")
local default = PapaGreetSavedVariables.profiles.Default
assert(not PapaGreetSavedVariables.profiles.Roleplay, "no shipped Roleplay profile")
for _, key in ipairs({"greetings", "goodbyes", "soloGoodbyes", "nearbyGreetings", "campGreetings", "campGoodbyes", "thanksMessages"}) do
    assert(#default[key] >= 5, key .. " has at least five starter lines")
end
eq(#default.nearbyGreetings, 5, "new nearby defaults")
eq(#default.campGreetings, 5, "new campsite defaults")
eq(default.starterPoolsVersion, 1, "fresh default migration marker")
_G.PapaGreetAddGreetingButton.scripts.OnClick()
eq(shownPopup.which, "PAPA_GREET_ADD_GREETING", "Default profile can add messages")
local manage = _G.PapaGreetDeleteGreetingDropdown.initialize
assert(manage, "greeting management dropdown exists")
local soloManage = _G.PapaGreetDeleteSoloGoodbyeDropdown.initialize
assert(soloManage, "solo dropdown initializer exists")
dropdownEntries[1] = {}
soloManage(nil, 1)
eq(#dropdownEntries[1], 5, "solo dropdown lists starter lines")
local savedSolo = default.soloGoodbyes
default.soloGoodbyes = nil
dropdownEntries[1] = {}
soloManage(nil, 1)
eq(dropdownEntries[1][1].text, "No entries", "missing pool cannot abort dropdown")
default.soloGoodbyes = savedSolo
dropdownEntries[1] = {}
manage(nil, 1)
local item = dropdownEntries[1][1]
assert(item and item.hasArrow and item.menuList, "message submenu on Default")
dropdownEntries[2] = {}
manage(nil, 2, item.menuList)
assert(dropdownEntries[2][1].text == "Edit" and dropdownEntries[2][2].text == "Delete", "edit/delete options")
dropdownEntries[2][1].func()
eq(shownPopup.which, "PAPA_GREET_EDIT_ITEM", "edit popup opened")
local editText = ""
local editBox = {
    SetText = function(_, text) editText = text end,
    GetText = function() return editText end,
    SetMaxLetters = function() end, HighlightText = function() end, SetFocus = function() end,
}
_G.TestEditBox = editBox
local popup = {data = shownPopup.data, GetName = function() return "Test" end, SetFrameStrata = function() end}
StaticPopupDialogs.PAPA_GREET_EDIT_ITEM.OnShow(popup)
eq(editText, item.menuList.original, "edit prefill")
editText = "A new default greeting"
StaticPopupDialogs.PAPA_GREET_EDIT_ITEM.OnAccept(popup)
eq(default.greetings[item.menuList.index], editText, "edit saved in place")
local length = #default.greetings
dropdownEntries[2][2].func()
eq(#default.greetings, length, "stale delete does not remove edited entry")
dropdownEntries[1] = {}
manage(nil, 1)
item = dropdownEntries[1][1]
dropdownEntries[2] = {}
manage(nil, 2, item.menuList)
dropdownEntries[2][2].func()
eq(#default.greetings, length - 1, "delete selected entry")

-- Existing Default saves gain only the new starter lines, once.
default.nearbyGreetings = {"Well met, traveler!", "Safe travels!"}
default.campGreetings = {"Mind if I join you by the fire?", "A fine place to rest. Well met!"}
default.starterPoolsVersion = nil
default.goodbyes = {
    "Farewell, champions. May your blade be sharp and your armor strong.",
    "Until we meet again, heroes.", "Safe travels, adventurers.", "Until next time champions!",
}
default.soloGoodbyes = {"Until next time!", "Time to hit the road. Safe travels!", "Farewell for now!", "The road calls. See you around!"}
default.campGoodbyes = {"Thanks for the warmth. Safe travels!", "The fire was welcome. Until next time!", "I should be on my way. Farewell!", "May your fire burn bright. Goodbye!"}
default.thanksMessages = {"Much appreciated. I owe you one.", "Thank you for the help.", "That was kind of you. Thank you.", "I won't forget that. Thanks."}
default.actionPoolsVersion = nil
dofile("PapaGreet.lua")
eq(#default.nearbyGreetings, 5, "existing nearby pool expanded")
eq(#default.campGreetings, 5, "existing campsite pool expanded")
for _, key in ipairs({"goodbyes", "soloGoodbyes", "campGoodbyes", "thanksMessages"}) do
    eq(#default[key], 5, "existing " .. key .. " pool expanded")
end
default.nearbyGreetings[5] = nil
default.soloGoodbyes = {}
dofile("PapaGreet.lua")
eq(#default.nearbyGreetings, 4, "deleted starter line stays deleted")
eq(#default.soloGoodbyes, 0, "cleared solo goodbye pool stays empty")
eq(#default.goodbyes, 5, "fifth group goodbye is not duplicated")

-- An active copy of the old Default pool also gains the lines without losing selection.
local copied = {
    greetings = {"My greeting"}, goodbyes = {"My goodbye"},
    greetingEmotes = {}, goodbyeEmotes = {}, delayEmote = 3, delayLeave = 8,
    cooldown = 3, autoLeave = false,
    nearbyGreetings = {"Well met, traveler!", "Safe travels!"},
    campGreetings = {"Mind if I join you by the fire?", "A fine place to rest. Well met!"},
}
PapaGreetSavedVariables.profiles["Default Copy"] = copied
PapaGreetSavedVariables.currentProfile = "Default Copy"
dofile("PapaGreet.lua")
eq(PapaGreetSavedVariables.currentProfile, "Default Copy", "copied profile stays selected")
eq(#copied.nearbyGreetings, 5, "copied nearby pool expanded")
eq(#copied.campGreetings, 5, "copied campsite pool expanded")
eq(#copied.soloGoodbyes, 5, "copied profile gains solo goodbye defaults")
eq(copied.greetings[1], "My greeting", "copied custom greeting preserved")
copied.campGreetings[5] = nil
dofile("PapaGreet.lua")
eq(#copied.campGreetings, 4, "copied pool deletion stays deleted")

-- Remove only the exact shipped Roleplay preset from an earlier local build.
local stockRoleplay = {
    greetings = {"Well met, travelers.", "Good to have company on the road.", "The road is kinder with friends."},
    goodbyes = {"Safe travels. Keep your eyes on the road.", "Until our paths cross again.", "May your journey be a gentle one."},
    nearbyGreetings = {"Well met. Heading this way too?", "Care to share the road a while?"},
    campGreetings = {"Mind if I warm myself by the fire?", "A welcome sight after a long road."},
    greetingEmotes = {"wave", "bow", "nod"}, goodbyeEmotes = {"wave", "bow"},
    delayEmote = 2, delayLeave = 8, cooldown = 3, autoLeave = false,
}
PapaGreetSavedVariables.profiles.Roleplay = stockRoleplay
PapaGreetSavedVariables.currentProfile = "Roleplay"
dofile("PapaGreet.lua")
assert(not PapaGreetSavedVariables.profiles.Roleplay, "untouched Roleplay preset retired")
eq(PapaGreetSavedVariables.currentProfile, "Default", "selection returns to Default")
stockRoleplay.greetings[1] = "A custom greeting"
PapaGreetSavedVariables.profiles.Roleplay = stockRoleplay
dofile("PapaGreet.lua")
eq(PapaGreetSavedVariables.profiles.Roleplay.greetings[1], "A custom greeting", "edited Roleplay profile preserved")

PapaGreetSavedVariables.profiles.Legacy = {
    greetings = {"Keep this greeting"}, goodbyes = {"Keep this goodbye"},
    greetingEmotes = {}, goodbyeEmotes = {}, delayEmote = 0, delayLeave = 7,
}
PapaGreetSavedVariables.currentProfile = "Legacy"
dofile("PapaGreet.lua")
local legacy = PapaGreetSavedVariables.profiles.Legacy
eq(legacy.greetings[1], "Keep this greeting", "legacy greeting preserved")
eq(legacy.goodbyes[1], "Keep this goodbye", "legacy goodbye preserved")
eq(#legacy.soloGoodbyes, 5, "legacy solo goodbye defaults")
eq(legacy.autoLeave, false, "legacy Forever leave default")
assert(#legacy.nearbyGreetings > 0 and #legacy.campGreetings > 0, "legacy context pools migrated")
eq(#legacy.campGoodbyes, 5, "legacy campsite goodbye defaults")
eq(#legacy.thanksMessages, 5, "legacy thank-you defaults")
PapaGreetSavedVariables = nil
dofile("PapaGreetMenu.lua")
for _, key in ipairs({"greetings", "goodbyes", "soloGoodbyes", "nearbyGreetings", "campGreetings", "campGoodbyes", "thanksMessages"}) do
    assert(#PapaGreetSavedVariables.profiles.Default[key] >= 5, "menu fallback " .. key .. " starter lines")
end
print("core, menu, and migration behavior passed")
