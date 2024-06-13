local AddOnName = ...
local BA = LibStub("AceAddon-3.0"):GetAddon(AddOnName)

local defaults = {
	global = {
		builds = {},
	}
}

BA.Options = {
	type = "group",
	name = AddOnName,
	args = {},
};


function BA:DB_INIT()
	self.db = LibStub("AceDB-3.0"):New("Build_Architect_Options", defaults, true)
	BA.Options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
end
