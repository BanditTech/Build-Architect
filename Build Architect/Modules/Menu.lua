local BA = LibStub("AceAddon-3.0"):GetAddon("Build Architect")
local ACEGUI = LibStub("AceGUI-3.0") 

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

function BA:UpdateEntryList()
		self.scroll:ReleaseChildren()
		local entryList = GetEntryList()
		for _, spell in ipairs(entryList) do
				local spellGroup = ACEGUI:Create("InlineGroup")
				spellGroup:SetLayout("Flow")

				local icon = ACEGUI:Create("Icon")
				icon:SetImage(spell.icon)
				icon:SetImageSize(32, 32)
				icon:SetWidth(34) -- Adjust to provide some padding
				icon.spellID = spell.spellID
				icon:SetCallback("OnEnter", ShowTooltip)
				icon:SetCallback("OnLeave", HideTooltip)

				local label = ACEGUI:Create("Label")
				label:SetText(spell.name)
				label:SetWidth(150)
				
				local removeButton = ACEGUI:Create("Button")
				removeButton:SetText("Remove")
				removeButton:SetCallback("OnClick", function()
					for i, s in ipairs(BA.db.profile.entries) do
						if s == spell.spellID then
							table.remove(BA.db.profile.entries, i)
							BA:UpdateEntryList()
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
	local frame = ACEGUI:Create("Frame")
	frame:SetTitle("Spell Menu")
	frame:SetCallback("OnClose", function(widget) 
		LibStub("AceGUI-3.0"):Release(widget)
		BA.MainMenu = nil
		BA.scroll = nil
	end)
	frame:SetLayout("Flow")

	local addSpellGroup = ACEGUI:Create("InlineGroup")
	addSpellGroup:SetTitle("Add Spell")
	addSpellGroup:SetLayout("Flow")
	addSpellGroup:SetFullWidth(true)
	frame:AddChild(addSpellGroup)

	local spellIDInput = ACEGUI:Create("EditBox")
	spellIDInput:SetLabel("Spell ID")
	-- spellIDInput:SetWidth(150)

	local addButton = ACEGUI:Create("Button")
	addButton:SetText("Add Spell")
	addButton:SetWidth(150)
	addButton:SetCallback("OnClick", function()
			local spellID = tonumber(spellIDInput:GetText())
			addEntry(spellID)
			spellIDInput:SetText("")
	end)

	addSpellGroup:AddChild(spellIDInput)
	addSpellGroup:AddChild(addButton)


	local scrollContainer = ACEGUI:Create("SimpleGroup")
	scrollContainer:SetFullWidth(true)
	scrollContainer:SetFullHeight(true)
	scrollContainer:SetLayout("Fill")
	local scroll = ACEGUI:Create("ScrollFrame")
	scroll:SetLayout("Flow")
	scrollContainer:AddChild(scroll)

	frame:AddChild(scrollContainer)

	BA.scroll = scroll
	BA.MainMenu = frame
	-- Register a chat command to show the frame
end

function BA.ShowMenu()
	if not BA.MainMenu then BA:CreateSpellMenu() end
	BA:UpdateEntryList()
	BA.MainMenu:Show()
end

function BA:CollectionSetup()
	print("Collection Setup fired")
	-- Iterate over 12 target frames
	for i = 1, 12 do
		-- Construct the target frame name
		local targetFrameName = "CharacterAdvancementSideBarSpellListScrollFrameButton" .. i .. "LockButton"
		local targetFrame = _G[targetFrameName]

		-- Ensure the target frame exists
		if targetFrame then
			-- Create a checkbox using AceGUI
			local checkbox = ACEGUI:Create("CheckBox")
			-- checkbox:SetLabel("Enable")
			checkbox:SetWidth(20) -- Set the width as required
			checkbox:SetHeight(20) -- Set the height as required

			-- Get the frame that will contain the checkbox
			local parentFrame = targetFrame:GetParent()

			-- Position the checkbox relative to the target frame
			checkbox.frame:SetParent(parentFrame)
			checkbox.frame:SetPoint("TOPRIGHT", targetFrame, "TOPLEFT", 0, 5)
			checkbox.frame:Show()
		else
			-- Print a warning if the target frame does not exist
			print("Warning: Frame " .. targetFrameName .. " does not exist.")
		end
	end
end
