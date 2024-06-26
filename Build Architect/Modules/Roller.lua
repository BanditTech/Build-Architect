local BA = LibStub("AceAddon-3.0"):GetAddon("Build Architect")

-- This Code was sourced from XAN's Wildcard Reroller weakaura.
-- https://github.com/xanthics


local function Handler(event, ...)
	-- Events before the validation step should always be handled when they are recieved
	if event == "OPTIONS" then
			BA.initialize()
			BA.validate()
			return
	elseif event == "XAN_WCD_STOP" then
			BA.stop = true
			BA.valid = false
			BA.hooked = false
			WildCardDice.ScrollFrame:UnregisterCallback("OnRouletteFinished", BA.callbackhandle)
			return
	elseif event == "XAN_WCD_VALIDATE_FINISHED" then
			BA.validatelock = false
			return
	elseif event == "ADDON_LOADED" and select(1, ...) ~= "Ascension_CharacterAdvancement" then 
			return
	end
	
	-- Validate before doing anything
	if not BA.valid and not BA.validate() then BA.initialize() return end
	
	-- there is a slight delay after OnRouletteFinished before clicking the dice won't cause a loop
	if event == "XAN_WCD_HIDE_DICE" then
			if WildCardDice:IsVisible() and not BA.clicked then
					BA.clicked = true
					Timer.NewTimer(BA.config.clickdelay, function() WildCardDice:OnClick() Handler("XAN_WCD_HIDE_DICE") end)
			else
					BA.clicked = false
					BA.dropnext()
			end
			return not BA.stop
	elseif event == "WILDCARD_ENTRY_LEARNED" then
			local internalID = ...
			BA.updateLists(internalID)
	elseif event == "ASCENSION_KNOWN_ENTRY_REMOVED" then
			local internalID = ...
			BA.stop = false -- something was manually removed, we can start the process
			-- set up a hook for when the dice roll finishes
			if not BA.hooked and IsAddOnLoaded("Ascension_WildCard") then
					BA.hooked = true
					WildCardDice.ScrollFrame:RegisterCallback("OnRouletteFinished", function() Handler("XAN_WCD_HIDE_DICE") end, BA.callbackhandle)
			end
			BA.updateLists(internalID, true)
	elseif event == "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED" then
			BA.specChanged = true
	elseif event == "ASCENSION_KNOWN_ENTRIES_UPDATED" then
			if BA.specChanged then -- called once after a spec change finishes
					BA.valid = false
					BA.validate()
					BA.specChanged = false
			else
					BA.validateAbilityList()
			end
	elseif event == "CHARACTER_ADVANCEMENT_LOCK_ENTRY_RESULT" and not BA.validatelock then
			local result, internalID = ...
			BA.handleLockEvent(result, internalID)
	end
end



BA.callbackhandle = "XanWCRCallbackHandle"
-- Need to initialize at start and any time we change spec
local function initialize()
    BA.locked = {}       -- [ID] = true :: every locked interalID
    
    BA.unlockedskills = {} -- [ID] = true :: Skills to roll away
    BA.wantskills = {}   -- [ID] = true :: Skills we want
    BA.softskills = {}   -- [ID] = true :: roll away last
    
    BA.unlockedtalents = {} -- [ID] = true :: Talents to roll away
    BA.wanttalents = {}  -- [ID] = true :: Talents we want
    BA.softtalents = {}  -- [ID] = true :: roll away last
    
    BA.unlockchain = {}  -- [internalID] = {id1, id2, ...}  unlocks any id listed, also removes from want lists
    
    BA.validatelock = false
end
initialize()
BA.initialize = initialize

-- So we can click to stop
if BA and not BA.clickableFrame then
    BA.clickableFrame = CreateFrame("Button", BA.id, BA.region, "SecureActionButtonTemplate")
    BA.clickableFrame:SetAllPoints()
    BA.clickableFrame:SetAttribute("type", "macro")
    BA.clickableFrame:SetAttribute("macrotext", '/run Handler("XAN_WCD_STOP")')
end

-- debug function for table state
local function printState(calling)
    local buffer = calling
    local current
    local tnames = { "locked", "unlockedskills", "wantskills", "softskills", "unlockedtalents", "wanttalents", "softtalents", "unlockchain" }
    for _, t in ipairs(tnames) do
        buffer = buffer .. "\n" .. t .. ":\n"
        for k, _ in pairs(BA[t]) do
            current = C_CharacterAdvancement.GetEntryByInternalID(k)
            buffer = buffer .. current.Name .. ", "
        end
    end
    Internal_CopyToClipboard(buffer)
    print("table states copied to clipboard")
end
BA.print = printState

local function dprint(level, text)
    if level > BA.config.debug then return end
    print(text)
end
BA.dprint = dprint

-- buffer the LockID and UnlockID calls, multiple in the same frame cause issues
local function validateAbilityList()
    if BA.validatelock then
        dprint(2, "Trying to validate locks while locks are being set")
        return
    end
    
    BA.validatelock = true
    local queue = {}
    for k, _ in pairs(BA.locked) do
        if not C_CharacterAdvancement.IsLockedID(k) then
            table.insert(queue, { ["ID"] = k, ["lock"] = true })
        end
    end
    for k, _ in pairs(BA.unlockedtalents) do
        if C_CharacterAdvancement.IsLockedID(k) then
            table.insert(queue, { ["ID"] = k })
        end
    end
    for k, _ in pairs(BA.unlockedskills) do
        if C_CharacterAdvancement.IsLockedID(k) then
            table.insert(queue, { ["ID"] = k })
        end
    end
    -- sync the skills and abilities lists
    -- needs a slight delay between syncs due to the resulting event not updating the ID fast enough
    if #queue > 0 then
        local MyTicker = C_Timer.NewTicker(0, function(self)
                local nextItem = table.remove(self.queue)
                if nextItem then
                    if nextItem.lock then
                        dprint(3, "Locked: " .. C_CharacterAdvancement.GetEntryByInternalID(nextItem.ID).Name)
                        C_CharacterAdvancement.LockID(nextItem.ID)
                    else
                        dprint(3, "Unlocked: " .. C_CharacterAdvancement.GetEntryByInternalID(nextItem.ID).Name)
                        C_CharacterAdvancement.UnlockID(nextItem.ID)
                    end
                end
                if not nextItem or #self.queue == 0 then
                    self:Cancel()
                    Handler("XAN_WCD_VALIDATE_FINISHED")
                end
        end)
        MyTicker.queue = queue
    else
        BA.validatelock = false
    end
end
BA.validateAbilityList = validateAbilityList

-- process the unlock chain so that lower priority items are no longer locked
local function processUnlockChain(ID)
    if BA.unlockchain[ID] then
        for _, k in ipairs(BA.unlockchain[ID]) do
            BA.wantskills[k] = nil
            BA.wanttalents[k] = nil
            BA.unlockchain[k] = nil
            if BA.locked[k] then
                BA.locked[k] = nil
                local current = C_CharacterAdvancement.GetEntryByInternalID(k)
                if current.Type == "Talent" then
                    BA.unlockedtalents[current.ID] = true
                elseif current.Type == "Ability" or current.Type == "TalentAbility" then
                    BA.unlockedskills[current.ID] = true
                else
                    dprint(2, "Invalid item found: " .. current.Name .. " (" .. current.ID .. ")")
                end
            end
        end
        BA.unlockchain[ID] = nil
    end
end

-- Helper functions to remove code duplication
local function addbyEntry(current, tlist, slist)
    if current.Type == "Talent" then
        tlist[current.ID] = true
    elseif current.Type == "Ability" or current.Type == "TalentAbility" then
        slist[current.ID] = true
    else
        print(1, "Invalid itemType found: " .. current.Name .. " (" .. current.Type .. ")")
    end
end
local function addById(id, tlist, slist)
    local current = C_CharacterAdvancement.GetEntryBySpellID(id)
    if current then
        addbyEntry(current, tlist, slist)
        return current.ID
    else
        dprint(1, "Recieved an invalid ID: " .. id)
    end
end

-- Attempt to clean up the most common types of user input
local function cleanup_user_input(text)
    text = text:gsub("%s", ',')         -- replace spaces, tabs, and newlines with commas
    text = text:gsub(",+", ",")         -- remove any adjacent commas
    text = text:gsub("^%D*(.-)%D*$", "%1") -- remove any leading or trailing commas
    return text
end

local function validate_user()
    -- parse the drop last list
    local syn = cleanup_user_input(BA.config.syn)
    for nextid in syn:gmatch("([^,]+)") do
        if nextid then
            addById(nextid, BA.softtalents, BA.softskills)
        end
    end
    -- parse the want list
    local want = cleanup_user_input(BA.config.want)
    for item in want:gmatch("([^,]+)") do
        if item:find("|") then
            local prev = {}
            for nextid in item:gmatch("([^|]+)") do
                local ID = addById(nextid, BA.wanttalents, BA.wantskills)
                if ID then -- ignore invalid IDs
                    for _, k in ipairs(prev) do
                        if BA.unlockchain[k] == nil then
                            BA.unlockchain[k] = {}
                        end
                        BA.unlockchain[k][#BA.unlockchain[k] + 1] = ID
                    end
                    prev[#prev + 1] = ID
                end
            end
        else
            addById(item, BA.wanttalents, BA.wantskills)
        end
    end
    -- parse known abilities and talents
    for _, id in ipairs(C_CharacterAdvancement.GetKnownSpells()) do
        local current = C_CharacterAdvancement.GetEntryBySpellID(id)
        if C_CharacterAdvancement.IsLockedID(current.ID) then
            BA.locked[current.ID] = true
            BA.wanttalents[current.ID] = nil
            BA.wantskills[current.ID] = nil
        else
            addbyEntry(current, BA.unlockedtalents, BA.unlockedskills)
        end
    end
    -- inspect unlocked talents and skills
    for talent, _ in pairs(BA.wanttalents) do
        if BA.unlockedtalents[talent] then
            BA.unlockedtalents[talent] = nil
            BA.locked[talent] = true
            BA.wanttalents[talent] = nil
        end
    end
    for skill, _ in pairs(BA.wantskills) do
        if BA.unlockedskills[skill] then
            BA.unlockedskills[skill] = nil
            BA.locked[skill] = true
            BA.wantskills[skill] = nil
        end
    end
    -- process any chains
    for ID, _ in pairs(BA.unlockchain) do
        if BA.locked[ID] == true then
            processUnlockChain(ID)
        end
    end
    validateAbilityList()
end


local function listcount(t)
    local count = 0
    for _, _ in pairs(t) do
        count = count + 1
    end
    return count
end

--[[
    drop immediately if not want:
    any tame, any form, any tank stance, titan's grip, smf, consuming flames
    any tank talent
    auto shot

]]
-- the values are the internal IDs
local dropFastAbilities = {
    [34755] = true, -- Enslave Demon
    [391] = true, -- Tame Beast
    [34824] = true, -- Tether Elemental
    [34703] = true, -- Dominate Undead
    [34745] = true, -- Tame Dragonkin
    [969] = true, -- Titan's Grip
    [971] = true, -- Single-Minded Fury
    [34878] = true, -- Bear Form
    [34868] = true, -- Cat Form
    [8975] = true, -- Serpent Form
    [8980] = true, -- Worgen Form
    [313] = true, -- Righteous Fury
    [9900] = true, -- Dark Apotheosis
    [34864] = true, -- Defensive Stance
    [34782] = true, -- Mana-forged Barrier
    [392] = true, -- Auto Shot
}

local dropFastTalents = {
    [10466] = true, -- Consuming Flames
}

local function isAbilityDropFirst(ID)
    local c = C_CharacterAdvancement.GetEntryByInternalID(ID)
    return dropFastAbilities[ID] or BA.config.dfirst[c.Class][c.Tab]
end

local function isTalentDropFirst(ID)
    local c = C_CharacterAdvancement.GetEntryByInternalID(ID)
    local clvl, maxlvl = C_CharacterAdvancement.GetTalentRankByID(ID)
    return clvl ~= maxlvl or BA.config.dfirst[c.Class][c.Tab]
end

-- This function actually unlearns a skill or talent
BA.dropnext = function()
    local cvals = BA.config
    local stoken = GetTokenCount(TokenUtil.GetScrollOfFortuneForSpec())
    local ttoken = GetTokenCount(TokenUtil.GetScrollOfFortuneTalentsForSpec())
    local svalid = stoken > cvals.stop.abilityscroll and listcount(BA.wantskills) > cvals.stop.ability and listcount(BA.unlockedskills) > cvals.stop.ability
    local tvalid = (ttoken > cvals.stop.talentscroll or (cvals.useability and stoken > cvals.stop.abilityscroll + cvals.stop.talentscroll)) and listcount(BA.wanttalents) > cvals.stop.talent and listcount(BA.unlockedtalents) > cvals.stop.talent
    local first, second, third, fourth = {}, {}, {}, {}
    local candidate
    if svalid and (stoken > ttoken / 2 or not tvalid) then
        for ID, _ in pairs(BA.unlockedskills) do
            if BA.softskills[ID] then
                if isAbilityDropFirst(ID) then
                    table.insert(third, ID)
                else
                    table.insert(fourth, ID)
                end
            else
                if isAbilityDropFirst(ID) then
                    table.insert(first, ID)
                else
                    table.insert(second, ID)
                end
            end
        end
    elseif tvalid then
        for ID, _ in pairs(BA.unlockedtalents) do
            if BA.softtalents[ID] then
                if isTalentDropFirst(ID) then
                    table.insert(third, ID)
                else
                    table.insert(fourth, ID)
                end
            else
                if isTalentDropFirst(ID) then
                    table.insert(first, ID)
                else
                    table.insert(second, ID)
                end
            end
        end
    end
    
    
    for _, t in ipairs({ first, second, third, fourth }) do
        if #t > 0 then
            candidate = t[random(#t)]
            break
        end
    end
    
    if candidate and not BA.stop then
        dprint(4, "Candidate: " .. C_CharacterAdvancement.GetEntryByInternalID(candidate).Name)
        C_CharacterAdvancement.UnlearnID(candidate)
    else
        BA.stop = true
        dprint(2, "No Candidate or stop button was pressed")
    end
end

-- Updates the internal lists based on events
BA.updateLists = function(id, removed)
    -- don't do anything if we are changing spec
    if BA.specChanged then return end
    if removed then
        if BA.unlockedskills[id] then
            BA.unlockedskills[id] = nil
        elseif BA.unlockedtalents[id] then
            BA.unlockedtalents[id] = nil
        else
            dprint(2, "Invalid Skill or Talent removed, something went wrong")
            BA.valid = nil
        end
    else
        local current = C_CharacterAdvancement.GetEntryByInternalID(id)
        dprint(4, "Learned: " .. current.Name)
        -- check if it's a new id
        if not (BA.locked[current.ID] or BA.unlockedskills[current.ID] or BA.unlockedtalents[current.ID]) then
            if BA.wantskills[current.ID] or BA.wanttalents[current.ID] then
                processUnlockChain(current.ID)
                BA.locked[current.ID] = true
            else
                addbyEntry(current, BA.unlockedtalents, BA.unlockedskills)
            end
        end
    end
end

-- Updates list states as entries are locked or unlocked
BA.handleLockEvent = function(result, internalID)
    if result == "CA_LOCK_OK" then
        BA.locked[internalID] = true
        BA.unlockedskills[internalID] = nil
        BA.unlockedtalents[internalID] = nil
    elseif result == "CA_UNLOCK_OK" then
        BA.locked[internalID] = nil
        local current = C_CharacterAdvancement.GetEntryByInternalID(internalID)
        addbyEntry(current, BA.unlockedtalents, BA.unlockedskills)
    else
        BA.valid = false
        dprint(2, "Unexpected State from locking or unlocking ability or talent: " .. result)
    end
end

-- Make sure we should actually be setting anything up
BA.validate = function()
    -- if not IsAddOnLoaded("Ascension_CharacterAdvancement") or WeakAuras.IsOptionsOpen() then
    if not IsAddOnLoaded("Ascension_CharacterAdvancement") or BA.OptionsOpen then
        initialize()
    elseif not C_GameMode:IsGameModeActive(Enum.GameMode.WildCard) then
        dprint(1, "Invalid Game Mode")
    elseif BA.config.want:find("[^%s%d,|]") then
        local wsym = BA.config.want:gsub("[%s%d,|]", '')
        dprint(1, "Invalid Want list symbol(s) found: " .. wsym)
    elseif BA.config.syn:find("[^%s%d,]") then
        local ssym = BA.config.syn:gsub("[%s%d,]", '')
        dprint(1, "Invalid Drop Last symbol(s) found: " .. ssym)
    elseif not BA.config.rules then
        dprint(1, "Read and agree to AFK policy")
    else
        BA.valid = true
        if not BA.last or BA.last + 1 < GetTime() then
            BA.last = GetTime()
            initialize()
            validate_user()
        end
        return true
    end
end

