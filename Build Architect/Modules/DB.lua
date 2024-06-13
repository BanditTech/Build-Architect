local BA = LibStub("AceAddon-3.0"):GetAddon("Build Architect")
local config = LibStub("AceConfig-3.0")
local dialog = LibStub("AceConfigDialog-3.0")


local defaults = {
	profile = {
		entries = {}
	}
}

local function initDB()
	BA.db = LibStub("AceDB-3.0"):New("Build_Architect_Options", defaults, true)
end

-- Use this function to add all the options to use
local function createOptions()
	local function get(info) return BA.db.profile.OPTIONS[info[#info]] end
	local function set(info,val) BA.db.profile.OPTIONS[info[#info]] = val end
	local options = {
		type = "group",
		name = "Build Architect",
		args = {},
		get = get,
		set = set,
	}
	-- Add more option groups here:
	-- options.args.newgroup = {}
	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(BA.db)
	return options
end

-- initialize the options into the blizzard frames
local function initOptions()
	local options = createOptions()
	config:RegisterOptionsTable("BuildArchitect-Bliz", {
		name = "Build Architect",
		type = "group",
		args = {
			help = {
				type = "description",
				name = "Build Architect is a build designer and exporter for Elune S9. Use this to create the build of your dreams or easily export your current build.",
			},
		},
	})
	dialog:SetDefaultSize("BuildArchitect-Bliz", 600, 400)
	dialog:AddToBlizOptions("BuildArchitect-Bliz", "Build Architect")
	-- General
	config:RegisterOptionsTable("BuildArchitect-Profile", options.args.profiles)
	dialog:AddToBlizOptions("BuildArchitect-Profile", options.args.profiles.name, "Build Architect")
end

function BA:DB_INIT()
	initDB()
	initOptions()
	self.db.RegisterCallback(self, "OnProfileChanged", "ProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "ProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "ProfileChanged")
end

function BA:ProfileChanged(event, database, newProfileKey)
	-- Call your update function
	self:UpdateEntryList()
end
