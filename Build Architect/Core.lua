local AddOnName = ...
local BA = LibStub("AceAddon-3.0"):GetAddon(AddOnName)

function BA:OnInitialize()
	BA:DB_INIT()
end
