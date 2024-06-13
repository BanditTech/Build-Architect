local BA = LibStub("AceAddon-3.0"):GetAddon("Build Architect")

function BA:OnInitialize()
	BA:DB_INIT()
	BA:RegisterChatCommand("ba", BA.ShowMenu)
	BA:RegisterEvent("ADDON_LOADED")
	-- BA:CreateSpellMenu()
end

function BA:ADDON_LOADED(event, arg1)
	-- setup for collection frame
	if event == "ADDON_LOADED" and arg1 == "Ascension_CharacterAdvancement" then
		Timer.After(2,BA:CollectionSetup())
	end
end