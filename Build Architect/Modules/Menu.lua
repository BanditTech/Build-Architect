local BA = LibStub("AceAddon-3.0"):GetAddon("Build Architect")
local AceGUI = LibStub("AceGUI-3.0") 

local function tableContains(tbl, val)
	for _, entry in pairs(tbl) do
		if entry == val then return true end
	end
end

local function GetEntryList()
    local spellList = {}
    for _, spell in ipairs(BA.db.profile.entries) do
        local spellName, _, spellIcon = GetSpellInfo(spell)
        if spellName then
            table.insert(spellList, {
                name = spellName,
                icon = spellIcon,
                spellID = spell
            })
        end
    end
    return spellList
end

local function ShowTooltip(widget)
	GameTooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
	GameTooltip:SetSpellByID(widget.spellID)
	GameTooltip:Show()
end

local function HideTooltip(widget)
	GameTooltip:Hide()
end

local function getButtonSpellID(buttonFrame)
	local entry = buttonFrame.entry
	if not entry then return end
	local spellID = entry.Spells[#entry.Spells]
	return spellID
end

function BA:updateCheckboxes(force)
	local prefix = "CharacterAdvancementSideBarSpellListScrollFrameButton"
	for i = 1, 12 do
		local targetFrameName = prefix .. i
		local targetFrame = _G[targetFrameName]
		if targetFrame then
			local checkbox = BA.Checkboxes[i]
			local spellID = getButtonSpellID(targetFrame)
			if checkbox.spellID ~= spellID or force then
				local isChecked = tableContains(BA.db.profile.entries,spellID)
				checkbox.spellID = spellID
				checkbox:SetValue(isChecked)
			end
		end
	end
end

function BA:UpdateEntryList()
	if not self.scroll then return end
	self.scroll:ReleaseChildren()
	local entryList = GetEntryList()
	for _, spell in ipairs(entryList) do
		local spellGroup = AceGUI:Create("InlineGroup")
		spellGroup:SetLayout("Flow")
		spellGroup:SetHeight(50)
		spellGroup:SetWidth(300)

		local icon = AceGUI:Create("Icon")
		icon:SetImage(spell.icon)
		icon:SetImageSize(32, 32)
		icon:SetWidth(34) -- Adjust to provide some padding
		icon.spellID = spell.spellID
		icon:SetCallback("OnEnter", ShowTooltip)
		icon:SetCallback("OnLeave", HideTooltip)

		local label = AceGUI:Create("Label")
		label:SetText(spell.name)
		label:SetWidth(150)
		
		local removeButton = AceGUI:Create("Button")
		removeButton:SetText("Remove")
		removeButton:SetCallback("OnClick", function()
			for i, s in ipairs(BA.db.profile.entries) do
				if s == spell.spellID then
					table.remove(BA.db.profile.entries, i)
					BA:UpdateEntryList()
					BA:updateCheckboxes(true)
					break
				end
			end
		end)
		removeButton:SetWidth(75)

		spellGroup:AddChild(icon)
		spellGroup:AddChild(label)
		spellGroup:AddChild(removeButton)

		self.scroll:AddChild(spellGroup)
	end
end

local function addEntry(spellID)
	if not spellID or spellID == "" then print("No SpellID input.") return end

	local name, _, icon = GetSpellInfo(spellID)
	if not name or not icon then print("SpellID Invalid.") return end

	local entry = C_CharacterAdvancement.GetEntryBySpellID(spellID)
	if not entry then print("spellID does not return an entry from C_CharacterAdvancement.") return end
	local isTalent = entry.Type == "Talent"
	if isTalent then
		spellID = entry.Spells[#entry.Spells]
	end
	
	local contained =  tableContains(BA.db.profile.entries, spellID)
	if contained then print("Already added to list") return end
	table.insert(BA.db.profile.entries, spellID)
	BA:UpdateEntryList()
end

-- Create the main frame using AceGUI
function BA:CreateSpellMenu()
	local frame = AceGUI:Create("Frame")
	frame:SetTitle("Spell Menu")
	frame:SetCallback("OnClose", function(widget) 
		LibStub("AceGUI-3.0"):Release(widget)
		BA.MainMenu = nil
		BA.scroll = nil
	end)
	frame:SetLayout("Flow")

	local addSpellGroup = AceGUI:Create("InlineGroup")
	addSpellGroup:SetTitle("Add Spell or Talent")
	addSpellGroup:SetLayout("Flow")
	addSpellGroup:SetHeight(100)
	addSpellGroup:SetWidth(200)
	-- addSpellGroup:SetFullWidth(true)
	frame:AddChild(addSpellGroup)

	local spellIDInput = AceGUI:Create("EditBox")
	spellIDInput:SetLabel("Spell ID")
	spellIDInput:SetWidth(100)

	local addButton = AceGUI:Create("Button")
	addButton:SetText("Add")
	addButton:SetWidth(70)
	addButton:SetCallback("OnClick", function()
			local spellID = tonumber(spellIDInput:GetText())
			addEntry(spellID)
			spellIDInput:SetText("")
	end)

	addSpellGroup:AddChild(spellIDInput)
	addSpellGroup:AddChild(addButton)

	BA:CreateProfileDropdown(frame)

	-- Add the scrolling container which will hold our spell icons.
	local scrollContainer = AceGUI:Create("SimpleGroup")
	scrollContainer:SetLayout("Fill")
	scrollContainer:SetFullWidth(true)
	scrollContainer:SetFullHeight(true)
	local scroll = AceGUI:Create("ScrollFrame")
	scroll:SetLayout("Flow")
	scrollContainer:AddChild(scroll)

	frame:AddChild(scrollContainer)

	BA.scroll = scroll
	BA.MainMenu = frame
end

function BA.ShowMenu()
	if not BA.MainMenu then BA:CreateSpellMenu() end
	BA:UpdateEntryList()
	BA.MainMenu:Show()
end

function BA:CollectionSetup()
	print("Collection Setup fired")
	-- Iterate over 12 target frames
	BA.Checkboxes = {}
	local prefix = "CharacterAdvancementSideBarSpellListScrollFrameButton"
	for i = 1, 12 do
		-- Construct the target frame name
		local targetFrameName = prefix .. i
		local targetFrame = _G[targetFrameName]
		local anchorFrameName = prefix .. i .. "LockButton"
		local anchorFrame = _G[anchorFrameName]

		-- Ensure the target frame exists
		if anchorFrame and targetFrame then
			-- Create a checkbox using AceGUI
			local checkbox = AceGUI:Create("CheckBox")
			-- checkbox:SetLabel("Enable")
			checkbox:SetWidth(20) -- Set the width as required
			checkbox:SetHeight(20) -- Set the height as required

			-- Get the frame that will contain the checkbox
			local parentFrame = anchorFrame:GetParent()
			local spellID = getButtonSpellID(targetFrame)
			if spellID then
				local isChecked = tableContains(BA.db.profile.entries,spellID)
				checkbox:SetValue(isChecked)
				checkbox.spellID = spellID
			end

			checkbox:SetCallback("OnValueChanged", function(widget, _, value)
				if value then
					-- Add spellID to the appropriate table
					if not tableContains(BA.db.profile.entries, widget.spellID) then
						table.insert(BA.db.profile.entries, widget.spellID)
						BA:UpdateEntryList()
					end
				else
					-- Remove spellID from the tables
					for i, s in ipairs(BA.db.profile.entries) do
						if s == widget.spellID then
							table.remove(BA.db.profile.entries, i)
							BA:UpdateEntryList()
							break
						end
					end
				end
			end)
			
			-- Position the checkbox relative to the target frame
			checkbox.frame:SetParent(parentFrame)
			checkbox.frame:SetPoint("TOPRIGHT", anchorFrame, "TOPLEFT", 0, 5)
			BA.Checkboxes[i] = checkbox
			checkbox.frame:Show()
		else
			-- Print a warning if the target frame does not exist
			print("Warning: Frame " .. anchorFrameName .. " does not exist.")
		end
	end
	hooksecurefunc(CharacterAdvancementSideBarSpellListScrollFrame,"update", BA.updateCheckboxes)
end

function BA:CreateProfileDropdown(container)
	-- Create a horizontal group to hold the dropdown and button
	local group = AceGUI:Create("InlineGroup")
	group:SetTitle("Profile Management")
	group:SetLayout("Flow")
	group:SetWidth(350)
	group:SetHeight(100)
	
	local dropdown = AceGUI:Create("Dropdown")
	dropdown:SetLabel("Select Profile")
	dropdown:SetWidth(200)

	local profiles = self.db:GetProfiles()
	local profileList = {}
	for i, profile in ipairs(profiles) do
			profileList[profile] = profile
	end

	dropdown:SetList(profileList)

	-- Set the current profile as the selected value
	local currentProfile = self.db:GetCurrentProfile()
	dropdown:SetValue(currentProfile)

	dropdown:SetCallback("OnValueChanged", function(widget, event, key)
			self.db:SetProfile(key)
			self:UpdateEntryList()
	end)

	group:AddChild(dropdown)

	-- Create the button to add a new profile
	local addButton = AceGUI:Create("Button")
	addButton:SetText("Add Profile")
	addButton:SetWidth(100)
	addButton:SetCallback("OnClick", function()
			self:ShowNewProfilePopup(dropdown)
	end)

	group:AddChild(addButton)

	container:AddChild(group)
end

function BA:ShowNewProfilePopup(dropdown)
	local frame = AceGUI:Create("Frame")
	frame:SetTitle("Add New Profile")
	frame:SetLayout("Flow")
	frame:SetWidth(300)
	frame:SetHeight(150)
	frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)

	local editbox = AceGUI:Create("EditBox")
	editbox:SetLabel("Profile Name")
	editbox:SetWidth(200)
	editbox:DisableButton(true)

	local confirmButton = AceGUI:Create("Button")
	confirmButton:SetText("Create")
	confirmButton:SetWidth(100)
	confirmButton:SetCallback("OnClick", function()
			local profileName = editbox:GetText()
			if profileName and profileName ~= "" then
					self.db:SetProfile(profileName)
					self:UpdateEntryList()
					
					-- Update the dropdown with the new profile
					local profiles = self.db:GetProfiles()
					local profileList = {}
					for i, profile in ipairs(profiles) do
							profileList[profile] = profile
					end
					dropdown:SetList(profileList)
					dropdown:SetValue(profileName)
					
					-- Close the popup
					frame:Hide()
			else
					print("Profile name cannot be blank.")
			end
	end)

	frame:AddChild(editbox)
	frame:AddChild(confirmButton)
end