-- PapaGreetMenu.lua
-- Version: 1.4.1

-- Localize globals for performance
local CreateFrame = CreateFrame
local UIParent = UIParent
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local UIDropDownMenu_SetSelectedValue = UIDropDownMenu_SetSelectedValue
local StaticPopup_Show = StaticPopup_Show
local StaticPopupDialogs = StaticPopupDialogs
local print = print
local table_insert = table.insert
local table_remove = table.remove
local math_floor = math.floor
local tonumber = tonumber

-- Constants
local DEFAULT_PROFILE = "Default"
local MAX_MESSAGE_LENGTH = 255
local MAX_EMOTE_LENGTH = 50
local MAX_PROFILE_NAME_LENGTH = 50

-- Input sanitization utility
local function sanitizeInput(input, maxLength)
    if not input then return nil end
    -- Trim whitespace
    input = input:match("^%s*(.-)%s*$")
    -- Check if empty after trimming
    if input == "" then return nil end
    -- Truncate if too long
    if #input > maxLength then
        input = input:sub(1, maxLength)
    end
    return input
end

-- Deep copy utility
local function deepcopy(orig)
    if type(orig) ~= 'table' then return orig end
    local copy = {}
    for k, v in next, orig, nil do
        copy[deepcopy(k)] = deepcopy(v)
    end
    setmetatable(copy, deepcopy(getmetatable(orig)))
    return copy
end

-- Initialize saved variables and current profile
local function InitializeVariables()
    PapaGreetSavedVariables = PapaGreetSavedVariables or {}
    PapaGreetSavedVariables.profiles = PapaGreetSavedVariables.profiles or {}
    PapaGreetSavedVariables.profiles[DEFAULT_PROFILE] = PapaGreetSavedVariables.profiles[DEFAULT_PROFILE] or {
        greetings = {
            "Hail, champions!", "Greetings, heroes!", "Greetings!",
            "Salutations, adventurers!", "Well met!", "Good evening!",
        },
        goodbyes = {
            "Farewell, champions. May your blade be sharp and your armor strong.",
            "Until we meet again, heroes.", "Safe travels, adventurers.",
            "Until next time champions!", "It was good traveling with you. Farewell!",
        },
        soloGoodbyes = {
            "Until next time!", "Time to hit the road. Safe travels!",
            "Farewell for now!", "The road calls. See you around!",
            "Take care out there!",
        },
        greetingEmotes = {},
        goodbyeEmotes = {},
        delayEmote = 3,
        delayLeave = 8,
        nearbyGreetings = {
            "Well met, traveler!", "Safe travels!", "Heading somewhere interesting?",
            "Need a hand out here?", "Good to see a friendly face.",
        },
        campGreetings = {
            "Mind if I join you by the fire?", "A fine place to rest. Well met!",
            "There's room by the fire if you'd like to sit.",
            "That fire is a welcome sight.", "Rest well before the road calls again.",
        },
        campGoodbyes = {
            "Thanks for the warmth. Safe travels!", "The fire was welcome. Until next time!",
            "I should be on my way. Farewell!", "May your fire burn bright. Goodbye!",
            "The road awaits. Thank you for the company!",
        },
        thanksMessages = {
            "Much appreciated. I owe you one.", "Thank you for the help.",
            "That was kind of you. Thank you.", "I won't forget that. Thanks.",
            "Your help made a difference. Thank you.",
        },
        actionPoolsVersion = 1,
    }
    PapaGreetSavedVariables.currentProfile = PapaGreetSavedVariables.currentProfile or DEFAULT_PROFILE

    -- Ensure all profiles have necessary fields
    for name, profile in pairs(PapaGreetSavedVariables.profiles) do
        profile.greetings = profile.greetings or {}
        profile.goodbyes = profile.goodbyes or {}
        profile.soloGoodbyes = profile.soloGoodbyes or {
            "Until next time!", "Time to hit the road. Safe travels!",
            "Farewell for now!", "The road calls. See you around!",
            "Take care out there!",
        }
        profile.greetingEmotes = profile.greetingEmotes or {}
        profile.goodbyeEmotes = profile.goodbyeEmotes or {}
        if profile.delayEmote == nil then profile.delayEmote = 3 end
        if profile.delayLeave == nil then profile.delayLeave = 8 end
        if profile.cooldown == nil then profile.cooldown = 3 end
        profile.nearbyGreetings = profile.nearbyGreetings or {"Well met, traveler!", "Safe travels!"}
        profile.campGreetings = profile.campGreetings or {"Mind if I join you by the fire?", "A fine place to rest. Well met!"}
        profile.campGoodbyes = profile.campGoodbyes or {
            "Thanks for the warmth. Safe travels!", "The fire was welcome. Until next time!",
            "I should be on my way. Farewell!", "May your fire burn bright. Goodbye!",
            "The road awaits. Thank you for the company!",
        }
        profile.thanksMessages = profile.thanksMessages or {
            "Much appreciated. I owe you one.", "Thank you for the help.",
            "That was kind of you. Thank you.", "I won't forget that. Thanks.",
            "Your help made a difference. Thank you.",
        }
        if profile.autoLeave == nil then profile.autoLeave = not (select(4, GetBuildInfo()) >= 16000 and select(4, GetBuildInfo()) < 17000) end
    end
    if not PapaGreetSavedVariables.profiles[PapaGreetSavedVariables.currentProfile] then
        PapaGreetSavedVariables.currentProfile = DEFAULT_PROFILE
    end
end

InitializeVariables()
local currentProfile = PapaGreetSavedVariables.currentProfile

-- Refresh the menu UI
local function RefreshPapaGreetMenu()
    currentProfile = PapaGreetSavedVariables.currentProfile
    local emoteDelayEditBox = _G["PapaGreetDelayEditBox"]
    if emoteDelayEditBox then
        emoteDelayEditBox:SetText(math_floor(PapaGreetSavedVariables.profiles[currentProfile].delayEmote))
    end

    local leaveDelayEditBox = _G["PapaGreetLeaveDelayEditBox"]
    if leaveDelayEditBox then
        leaveDelayEditBox:SetText(math_floor(PapaGreetSavedVariables.profiles[currentProfile].delayLeave))
    end

    local cooldownEditBox = _G["PapaGreetCooldownEditBox"]
    if cooldownEditBox then
        cooldownEditBox:SetText(math_floor(PapaGreetSavedVariables.profiles[currentProfile].cooldown))
    end

    UIDropDownMenu_SetSelectedValue(PapaGreetProfileDropdown, currentProfile)
    local autoLeave = _G["PapaGreetAutoLeaveCheck"]
    if autoLeave then autoLeave:SetChecked(PapaGreetSavedVariables.profiles[currentProfile].autoLeave) end
end

-- Helper function to create buttons
local function createButton(name, parent, point, offsetX, offsetY, width, height, text, popup)
    local btn = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    btn:SetPoint(point, offsetX, offsetY)
    btn:SetSize(width, height)
    btn:SetText(text)
    btn:SetScript("OnClick", function()
        if popup then StaticPopup_Show(popup) end
    end)
    return btn
end

-- One submenu per entry keeps edit and delete actions together.
local function createManageDropdown(name, parent, point, offsetX, offsetY, width, itemsKey)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint(point, parent, point, offsetX - 15, offsetY)
    dropdown:SetSize(width, 25)

    -- Assigning initialize avoids an immediate callback while the menu is
    -- still being built; WoW invokes it when the dropdown is opened.
    dropdown.initialize = function(self, level, menuList)
        if level == 2 then
            if not menuList then return end
            local data = menuList
            local profile = PapaGreetSavedVariables.profiles[data.profile]
            local items = profile and profile[data.key]
            if not items or items[data.index] ~= data.original then return end
            local editInfo = UIDropDownMenu_CreateInfo()
            editInfo.text = "Edit"
            editInfo.notCheckable = true
            editInfo.func = function()
                CloseDropDownMenus()
                StaticPopup_Show("PAPA_GREET_EDIT_ITEM", nil, nil, data)
            end
            UIDropDownMenu_AddButton(editInfo, level)
            local deleteInfo = UIDropDownMenu_CreateInfo()
            deleteInfo.text = "Delete"
            deleteInfo.notCheckable = true
            deleteInfo.func = function()
                if items[data.index] == data.original then
                    table_remove(items, data.index)
                    RefreshPapaGreetMenu()
                end
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(deleteInfo, level)
            return
        end
        local profile = PapaGreetSavedVariables.profiles[currentProfile]
        local items = (profile and profile[itemsKey]) or {}
        if #items == 0 then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "No entries"
            info.disabled = true
            UIDropDownMenu_AddButton(info, level)
            return
        end
        for i, item in ipairs(items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item
            info.notCheckable = true
            info.hasArrow = true
            info.menuList = {profile = currentProfile, key = itemsKey, index = i, original = item}
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_SetText(dropdown, "Edit / Delete...")
    return dropdown
end

-- Define Static Popups (must be defined before ShowPapaGreetMenu)
StaticPopupDialogs["PAPA_GREET_CREATE_PROFILE"] = {
    text = "Enter the name for the new profile:",
    button1 = "Create",
    button2 = "Cancel",
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnShow = function(self)
        self:SetFrameStrata("TOOLTIP")
        self:SetFrameLevel(1000)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        self:SetScale(1.0)
        self:Show()
        local editBox = _G[self:GetName().."EditBox"] or _G[self:GetName().."WideEditBox"]
        if editBox then
            editBox:SetText("")
            editBox:SetFocus()
        end
    end,
    OnAccept = function(self)
        -- For StaticPopup dialogs, the text is in self.data if we pass it,
        -- or we need to get it from the wndchild1 (editBox1)
        local editBox = _G[self:GetName().."EditBox"] or _G[self:GetName().."WideEditBox"]
        local editBoxText = editBox and editBox:GetText() or ""

        local profileName = sanitizeInput(editBoxText, MAX_PROFILE_NAME_LENGTH)

        if profileName then
            if PapaGreetSavedVariables.profiles[profileName] then
                print("Profile '" .. profileName .. "' already exists.")
            else
                PapaGreetSavedVariables.profiles[profileName] = deepcopy(PapaGreetSavedVariables.profiles[currentProfile])
                currentProfile = profileName
                PapaGreetSavedVariables.currentProfile = currentProfile
                RefreshPapaGreetMenu()
                print("Profile '" .. profileName .. "' created.")
            end
        else
            print("Profile name cannot be empty or contain only whitespace.")
        end
    end,
    EditBoxOnEnterPressed = function(self)
        StaticPopup_OnClick(self:GetParent(), 1)
    end,
    EditBoxOnEscapePressed = function(self)
        StaticPopup_OnClick(self:GetParent(), 2)
    end
}

StaticPopupDialogs["PAPA_GREET_DELETE_PROFILE"] = {
    text = "Are you sure you want to delete the current profile?",
    button1 = "Delete",
    button2 = "Cancel",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnShow = function(self)
        self:SetFrameStrata("TOOLTIP")
    end,
    OnAccept = function(self)
        if currentProfile == DEFAULT_PROFILE then
            print("Cannot delete the Default profile.")
            return
        end
        local deletedProfile = currentProfile
        PapaGreetSavedVariables.profiles[currentProfile] = nil
        currentProfile = DEFAULT_PROFILE
        PapaGreetSavedVariables.currentProfile = currentProfile
        RefreshPapaGreetMenu()
        print("Profile '" .. deletedProfile .. "' deleted.")
    end
}

StaticPopupDialogs["PAPA_GREET_COPY_PROFILE"] = {
    text = "Enter the name for the copied profile:",
    button1 = "Copy",
    button2 = "Cancel",
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnShow = function(self)
        self:SetFrameStrata("TOOLTIP")
        local editBox = _G[self:GetName().."EditBox"] or _G[self:GetName().."WideEditBox"]
        if editBox then
            editBox:SetText(currentProfile .. " Copy")
            editBox:SetFocus()
        end
    end,
    OnAccept = function(self)
        local editBox = _G[self:GetName().."EditBox"] or _G[self:GetName().."WideEditBox"]
        local editBoxText = editBox and editBox:GetText() or ""
        local profileName = sanitizeInput(editBoxText, MAX_PROFILE_NAME_LENGTH)
        if profileName then
            if PapaGreetSavedVariables.profiles[profileName] then
                print("Profile '" .. profileName .. "' already exists.")
            else
                PapaGreetSavedVariables.profiles[profileName] = deepcopy(PapaGreetSavedVariables.profiles[currentProfile])
                print("Profile '" .. profileName .. "' created as a copy of '" .. currentProfile .. "'.")
                RefreshPapaGreetMenu()
            end
        else
            print("Profile name cannot be empty or contain only whitespace.")
        end
    end,
    EditBoxOnEnterPressed = function(self)
        StaticPopup_OnClick(self:GetParent(), 1)
    end,
    EditBoxOnEscapePressed = function(self)
        StaticPopup_OnClick(self:GetParent(), 2)
    end
}

StaticPopupDialogs["PAPA_GREET_ADD_GREETING"] = {
    text = "Enter the greeting message:",
    button1 = "Add",
    button2 = "Cancel",
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnShow = function(self)
        self:SetFrameStrata("TOOLTIP")
        local editBox = _G[self:GetName().."EditBox"] or _G[self:GetName().."WideEditBox"]
        if editBox then
            editBox:SetText("")
            editBox:SetFocus()
        end
    end,
    OnAccept = function(self)
        local editBox = _G[self:GetName().."EditBox"] or _G[self:GetName().."WideEditBox"]
        local editBoxText = editBox and editBox:GetText() or ""
        local greeting = sanitizeInput(editBoxText, MAX_MESSAGE_LENGTH)
        if greeting then
            table_insert(PapaGreetSavedVariables.profiles[currentProfile].greetings, greeting)
            RefreshPapaGreetMenu()
        else
            print("Greeting cannot be empty or contain only whitespace.")
        end
    end,
    EditBoxOnEnterPressed = function(self)
        StaticPopup_OnClick(self:GetParent(), 1)
    end,
    EditBoxOnEscapePressed = function(self)
        StaticPopup_OnClick(self:GetParent(), 2)
    end
}

StaticPopupDialogs["PAPA_GREET_ADD_GOODBYE"] = {
    text = "Enter the goodbye message:",
    button1 = "Add",
    button2 = "Cancel",
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnShow = function(self)
        self:SetFrameStrata("TOOLTIP")
        local editBox = _G[self:GetName().."EditBox"] or _G[self:GetName().."WideEditBox"]
        if editBox then
            editBox:SetText("")
            editBox:SetFocus()
        end
    end,
    OnAccept = function(self)
        local editBox = _G[self:GetName().."EditBox"] or _G[self:GetName().."WideEditBox"]
        local editBoxText = editBox and editBox:GetText() or ""
        local goodbye = sanitizeInput(editBoxText, MAX_MESSAGE_LENGTH)
        if goodbye then
            table_insert(PapaGreetSavedVariables.profiles[currentProfile].goodbyes, goodbye)
            RefreshPapaGreetMenu()
        else
            print("Goodbye cannot be empty or contain only whitespace.")
        end
    end,
    EditBoxOnEnterPressed = function(self)
        StaticPopup_OnClick(self:GetParent(), 1)
    end,
    EditBoxOnEscapePressed = function(self)
        StaticPopup_OnClick(self:GetParent(), 2)
    end
}

StaticPopupDialogs["PAPA_GREET_ADD_GREETING_EMOTE"] = {
    text = "Enter the greeting emote:",
    button1 = "Add",
    button2 = "Cancel",
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnShow = function(self)
        self:SetFrameStrata("TOOLTIP")
        local editBox = _G[self:GetName().."EditBox"] or _G[self:GetName().."WideEditBox"]
        if editBox then
            editBox:SetText("")
            editBox:SetFocus()
        end
    end,
    OnAccept = function(self)
        local editBox = _G[self:GetName().."EditBox"] or _G[self:GetName().."WideEditBox"]
        local editBoxText = editBox and editBox:GetText() or ""
        local emote = sanitizeInput(editBoxText, MAX_EMOTE_LENGTH)
        if emote then
            table_insert(PapaGreetSavedVariables.profiles[currentProfile].greetingEmotes, emote)
            RefreshPapaGreetMenu()
        else
            print("Greeting emote cannot be empty or contain only whitespace.")
        end
    end,
    EditBoxOnEnterPressed = function(self)
        StaticPopup_OnClick(self:GetParent(), 1)
    end,
    EditBoxOnEscapePressed = function(self)
        StaticPopup_OnClick(self:GetParent(), 2)
    end
}

StaticPopupDialogs["PAPA_GREET_ADD_GOODBYE_EMOTE"] = {
    text = "Enter the goodbye emote:",
    button1 = "Add",
    button2 = "Cancel",
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnShow = function(self)
        self:SetFrameStrata("TOOLTIP")
        local editBox = _G[self:GetName().."EditBox"] or _G[self:GetName().."WideEditBox"]
        if editBox then
            editBox:SetText("")
            editBox:SetFocus()
        end
    end,
    OnAccept = function(self)
        local editBox = _G[self:GetName().."EditBox"] or _G[self:GetName().."WideEditBox"]
        local editBoxText = editBox and editBox:GetText() or ""
        local emote = sanitizeInput(editBoxText, MAX_EMOTE_LENGTH)
        if emote then
            table_insert(PapaGreetSavedVariables.profiles[currentProfile].goodbyeEmotes, emote)
            RefreshPapaGreetMenu()
        else
            print("Goodbye emote cannot be empty or contain only whitespace.")
        end
    end,
    EditBoxOnEnterPressed = function(self)
        StaticPopup_OnClick(self:GetParent(), 1)
    end,
    EditBoxOnEscapePressed = function(self)
        StaticPopup_OnClick(self:GetParent(), 2)
    end
}

local function AddContextGreetingPopup(key, label, noun)
    return {
        text = "Enter the " .. label .. " " .. (noun or "greeting") .. ":",
        button1 = "Add", button2 = "Cancel", hasEditBox = true,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        OnShow = function(self)
            self:SetFrameStrata("TOOLTIP")
            local editBox = _G[self:GetName() .. "EditBox"] or _G[self:GetName() .. "WideEditBox"]
            if editBox then editBox:SetText(""); editBox:SetFocus() end
        end,
        OnAccept = function(self)
            local editBox = _G[self:GetName() .. "EditBox"] or _G[self:GetName() .. "WideEditBox"]
            local greeting = sanitizeInput(editBox and editBox:GetText(), MAX_MESSAGE_LENGTH)
            if greeting then
                table_insert(PapaGreetSavedVariables.profiles[currentProfile][key], greeting)
                RefreshPapaGreetMenu()
            end
        end,
        EditBoxOnEnterPressed = function(self) StaticPopup_OnClick(self:GetParent(), 1) end,
        EditBoxOnEscapePressed = function(self) StaticPopup_OnClick(self:GetParent(), 2) end,
    }
end

StaticPopupDialogs["PAPA_GREET_ADD_NEARBY"] = AddContextGreetingPopup("nearbyGreetings", "nearby")
StaticPopupDialogs["PAPA_GREET_ADD_CAMP"] = AddContextGreetingPopup("campGreetings", "campsite")
StaticPopupDialogs["PAPA_GREET_ADD_SOLO_GOODBYE"] = AddContextGreetingPopup("soloGoodbyes", "solo", "goodbye")
StaticPopupDialogs["PAPA_GREET_ADD_CAMP_GOODBYE"] = AddContextGreetingPopup("campGoodbyes", "campsite", "goodbye")
StaticPopupDialogs["PAPA_GREET_ADD_THANKS"] = AddContextGreetingPopup("thanksMessages", "thank-you", "message")

StaticPopupDialogs["PAPA_GREET_EDIT_ITEM"] = {
    text = "Edit this entry:",
    button1 = "Save", button2 = "Cancel", hasEditBox = true,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    OnShow = function(self)
        self:SetFrameStrata("TOOLTIP")
        local data = self.data
        local editBox = _G[self:GetName() .. "EditBox"] or _G[self:GetName() .. "WideEditBox"]
        if editBox and data then
            local isEmote = data.key == "greetingEmotes" or data.key == "goodbyeEmotes"
            editBox:SetMaxLetters(isEmote and MAX_EMOTE_LENGTH or MAX_MESSAGE_LENGTH)
            editBox:SetText(data.original)
            editBox:HighlightText()
            editBox:SetFocus()
        end
    end,
    OnAccept = function(self)
        local data = self.data
        if not data then return end
        local profile = PapaGreetSavedVariables.profiles[data.profile]
        local items = profile and profile[data.key]
        if not items or items[data.index] ~= data.original then
            print("Entry changed. Open the menu again before editing it.")
            return
        end
        local editBox = _G[self:GetName() .. "EditBox"] or _G[self:GetName() .. "WideEditBox"]
        local isEmote = data.key == "greetingEmotes" or data.key == "goodbyeEmotes"
        local value = sanitizeInput(editBox and editBox:GetText(), isEmote and MAX_EMOTE_LENGTH or MAX_MESSAGE_LENGTH)
        if not value then
            print("Entry cannot be empty.")
            return
        end
        items[data.index] = value
        RefreshPapaGreetMenu()
    end,
    EditBoxOnEnterPressed = function(self) StaticPopup_OnClick(self:GetParent(), 1) end,
    EditBoxOnEscapePressed = function(self) StaticPopup_OnClick(self:GetParent(), 2) end,
}

-- Show the menu
function ShowPapaGreetMenu()
    InitializeVariables()
    currentProfile = PapaGreetSavedVariables.currentProfile
    -- Reuse existing frame if it exists
    if PapaGreetMenu then
        PapaGreetMenu:Show()
        RefreshPapaGreetMenu()
        return
    end

    local menu = CreateFrame("Frame", "PapaGreetMenu", UIParent, "BasicFrameTemplate")
    menu:SetSize(380, 550)
    menu:SetPoint("CENTER")
    menu:SetFrameStrata("DIALOG")
    menu:SetMovable(true)
    menu:EnableMouse(true)

    -- Title
    local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", menu, "TOP", 0, -5)
    title:SetText("PapaGreet Menu")

    -- Enable moving the frame with MiddleButton
    menu:SetScript("OnMouseDown", function(self, button)
        if button == "MiddleButton" then self:StartMoving() end
    end)
    menu:SetScript("OnMouseUp", function(self, button)
        if button == "MiddleButton" then self:StopMovingOrSizing() end
    end)

    -- Profile Dropdown
    local profileDropdown = CreateFrame("Frame", "PapaGreetProfileDropdown", menu, "UIDropDownMenuTemplate")
    profileDropdown:SetPoint("TOPLEFT", menu, "TOPLEFT", 190, -30)

    UIDropDownMenu_Initialize(profileDropdown, function(self, level)
        for name, _ in pairs(PapaGreetSavedVariables.profiles) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.func = function()
                currentProfile = name
                PapaGreetSavedVariables.currentProfile = currentProfile
                UIDropDownMenu_SetSelectedValue(profileDropdown, currentProfile)
                RefreshPapaGreetMenu()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    UIDropDownMenu_SetSelectedValue(profileDropdown, currentProfile)

    -- Create Profile Buttons
    createButton("PapaGreetCreateProfileButton", menu, "TOPRIGHT", -240, -30, 120, 27, "Create Profile", "PAPA_GREET_CREATE_PROFILE")
    createButton("PapaGreetDeleteProfileButton", menu, "TOPRIGHT", -240, -70, 120, 27, "Delete Profile", "PAPA_GREET_DELETE_PROFILE")
    createButton("PapaGreetCopyProfileButton", menu, "TOPLEFT", 207, -70, 120, 27, "Copy Profile", "PAPA_GREET_COPY_PROFILE")

    -- Helper function to create delay labels and edit boxes
    local function createDelay(labelText, editBoxName, yOffset, configKey, defaultValue)
        local label = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", menu, "TOPLEFT", 20, yOffset)
        label:SetText(labelText)

        local editBox = CreateFrame("EditBox", editBoxName, menu, "InputBoxTemplate")
        editBox:SetSize(50, 25)
        editBox:SetPoint("LEFT", label, "RIGHT", 10, 0)
        editBox:SetNumeric(true)
        editBox:SetMaxLetters(2)
        editBox:SetAutoFocus(false)
        local value = PapaGreetSavedVariables.profiles[currentProfile][configKey]
        editBox:SetText(math_floor(value == nil and defaultValue or value))

        editBox:SetScript("OnEnterPressed", function(self)
            local inputValue = tonumber(self:GetText())
            if inputValue then
                PapaGreetSavedVariables.profiles[currentProfile][configKey] = math_floor(inputValue)
                RefreshPapaGreetMenu()
            else
                print("Invalid input for " .. configKey)
            end
            self:ClearFocus()
        end)
    end

    -- Create Delay EditBoxes
    createDelay("Emote Delay (seconds):", "PapaGreetDelayEditBox", -120, "delayEmote", 3)
    createDelay("Leave Delay (seconds):", "PapaGreetLeaveDelayEditBox", -160, "delayLeave", 8)
    createDelay("Cooldown (seconds, 0=off):", "PapaGreetCooldownEditBox", -200, "cooldown", 3)

    -- Keep both sets of message controls within the visible menu height.
    local messageTab = CreateFrame("Button", "PapaGreetMessagesTab", menu, "UIPanelButtonTemplate")
    messageTab:SetPoint("TOPLEFT", menu, "TOPLEFT", 20, -230)
    messageTab:SetSize(150, 25)
    local rpTab = CreateFrame("Button", "PapaGreetRPTab", menu, "UIPanelButtonTemplate")
    rpTab:SetPoint("TOPLEFT", menu, "TOPLEFT", 180, -230)
    rpTab:SetSize(150, 25)

    local messagePanel = CreateFrame("Frame", "PapaGreetMessagePanel", menu)
    messagePanel:SetPoint("TOPLEFT", menu, "TOPLEFT", 0, -265)
    messagePanel:SetSize(350, 205)
    local rpPanel = CreateFrame("Frame", "PapaGreetRPPanel", menu)
    rpPanel:SetPoint("TOPLEFT", menu, "TOPLEFT", 0, -265)
    rpPanel:SetSize(350, 205)

    local function ShowSection(section)
        messagePanel:SetShown(section == "messages")
        rpPanel:SetShown(section == "rp")
        messageTab:SetText(section == "messages" and "[Messages]" or "Messages")
        rpTab:SetText(section == "rp" and "[RP / Camp]" or "RP / Camp")
    end
    messageTab:SetScript("OnClick", function() ShowSection("messages") end)
    rpTab:SetScript("OnClick", function() ShowSection("rp") end)
    ShowSection("messages")

    createButton("PapaGreetAddGreetingButton", messagePanel, "TOPLEFT", 20, -10, 140, 27, "Add Greeting", "PAPA_GREET_ADD_GREETING")
    createManageDropdown("PapaGreetDeleteGreetingDropdown", messagePanel, "TOPLEFT", 180, -10, 140, "greetings")
    createButton("PapaGreetAddGoodbyeButton", messagePanel, "TOPLEFT", 20, -50, 140, 27, "Add Group Goodbye", "PAPA_GREET_ADD_GOODBYE")
    createManageDropdown("PapaGreetDeleteGoodbyeDropdown", messagePanel, "TOPLEFT", 180, -50, 140, "goodbyes")
    createButton("PapaGreetAddSoloGoodbyeButton", messagePanel, "TOPLEFT", 20, -90, 140, 27, "Add Solo Goodbye", "PAPA_GREET_ADD_SOLO_GOODBYE")
    createManageDropdown("PapaGreetDeleteSoloGoodbyeDropdown", messagePanel, "TOPLEFT", 180, -90, 140, "soloGoodbyes")
    createButton("PapaGreetAddGreetingEmoteButton", messagePanel, "TOPLEFT", 20, -130, 140, 27, "Add Greeting Emote", "PAPA_GREET_ADD_GREETING_EMOTE")
    createManageDropdown("PapaGreetDeleteGreetingEmoteDropdown", messagePanel, "TOPLEFT", 180, -130, 140, "greetingEmotes")
    createButton("PapaGreetAddGoodbyeEmoteButton", messagePanel, "TOPLEFT", 20, -170, 140, 27, "Add Goodbye Emote", "PAPA_GREET_ADD_GOODBYE_EMOTE")
    createManageDropdown("PapaGreetDeleteGoodbyeEmoteDropdown", messagePanel, "TOPLEFT", 180, -170, 140, "goodbyeEmotes")

    createButton("PapaGreetAddNearbyButton", rpPanel, "TOPLEFT", 20, -10, 140, 27, "Add Nearby Greeting", "PAPA_GREET_ADD_NEARBY")
    createManageDropdown("PapaGreetDeleteNearbyDropdown", rpPanel, "TOPLEFT", 180, -10, 140, "nearbyGreetings")
    createButton("PapaGreetAddCampButton", rpPanel, "TOPLEFT", 20, -50, 140, 27, "Add Camp Greeting", "PAPA_GREET_ADD_CAMP")
    createManageDropdown("PapaGreetDeleteCampDropdown", rpPanel, "TOPLEFT", 180, -50, 140, "campGreetings")
    createButton("PapaGreetAddCampGoodbyeButton", rpPanel, "TOPLEFT", 20, -90, 140, 27, "Add Camp Goodbye", "PAPA_GREET_ADD_CAMP_GOODBYE")
    createManageDropdown("PapaGreetDeleteCampGoodbyeDropdown", rpPanel, "TOPLEFT", 180, -90, 140, "campGoodbyes")
    createButton("PapaGreetAddThanksButton", rpPanel, "TOPLEFT", 20, -130, 140, 27, "Add Thank You", "PAPA_GREET_ADD_THANKS")
    createManageDropdown("PapaGreetDeleteThanksDropdown", rpPanel, "TOPLEFT", 180, -130, 140, "thanksMessages")
    local autoLeave = CreateFrame("CheckButton", "PapaGreetAutoLeaveCheck", menu, "UICheckButtonTemplate")
    autoLeave:SetPoint("TOPLEFT", menu, "TOPLEFT", 20, -490)
    _G[autoLeave:GetName() .. "Text"]:SetText("Leave group after goodbye")
    autoLeave:SetScript("OnClick", function(self)
        PapaGreetSavedVariables.profiles[currentProfile].autoLeave = self:GetChecked() and true or false
    end)

    -- Refresh the menu after creating all elements
    RefreshPapaGreetMenu()
end

-- Toggle menu visibility
function TogglePapaGreetMenu()
    if not PapaGreetMenu then
        ShowPapaGreetMenu()
    else
        if PapaGreetMenu:IsShown() then
            PapaGreetMenu:Hide()
        else
            PapaGreetMenu:Show()
        end
    end
end
