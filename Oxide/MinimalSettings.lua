PLUGIN.Title = "Minimal Settings"
PLUGIN.Description = "A set of configurable settings (banner,grass, and nudity atm)"
PLUGIN.Version = "0.18"
PLUGIN.Author = "Shaheel"

-- restore previous configuration on user connect
function PLUGIN:OnUserConnect( netuser )
local userID = rust.GetUserID(netuser)
	-- selects between config file or user's settings
local dataSource = self.JsonData[userID] or self.Config
	-- perform commands as per dataSource
	self:performNudityCommand(dataSource.nudityOn, netuser)
	self:performGrassCommand(dataSource.removesGrass, netuser)
	self:performBannerCommand(dataSource.removesBanner, netuser)
end

-- Loads the default configuration into the config table
function PLUGIN:LoadDefaultConfig()
	-- Sets default configuration settings
	self.Config.removesGrass = true
	self.Config.removesBanner = true
	self.Config.nudityOn = true
end

-- Initialization
function PLUGIN:Init()
	-- Load the config file
	local b, res = config.Read( "minimalSettings" )
	self.Config = res or {}
	if (not b) then
		self:LoadDefaultConfig()
		if (res) then config.Save( "minimalSettings" ) end
	end

	-- Create/retrieve users
	self.JsonDataDataFile = util.GetDatafile( "userSettings" )
	local txt = self.JsonDataDataFile:GetText()
	if (txt ~= "") then
		self.JsonData = json.decode( txt )
	else
		self.JsonData = {}
		self:Save();
	end

	-- Add chat commands
	self:AddChatCommands();
end

-- Commands
--Adds chat commands to the server
function PLUGIN:AddChatCommands()
	self:AddChatCommand( "grass", self.cmdManageForUserSettings )
	self:AddChatCommand( "banner", self.cmdManageForUserSettings )
	self:AddChatCommand( "nudity", self.cmdManageForUserSettings )
	self:AddChatCommand( "nude", self.cmdManageForUserSettings )
end
-- CMD Manage Helper
function  PLUGIN:getKeyForCommand(cmd)
	local result = nil
	if( cmd == "grass" ) then
		result = "removesGrass"
	end
	if (cmd == "banner" ) then
		result = "removesBanner"
	end
	if(cmd == "nudity" or cmd == "nude") then
		result = "nudityOn"
	end

	return result
end
-- CMD ManageCommands
function PLUGIN:cmdManageForUserSettings(netuser, cmd, args)
	-- create default user
	self:AddDefaultUserEntryToJsonDataIfNotExist(netuser)
	local userID = rust.GetUserID( netuser )
	local dataKey = self:getKeyForCommand(cmd)
	-- if arguments used
	if( args[1] ) then
		local arg = args[1]
		if( arg:lower() == "on" ) then
			self.JsonData[userID][dataKey] = false;
		elseif ( arg:lower() == "off" ) then
			self.JsonData[userID][dataKey] = true;
		else
			rust.Notice( netuser, "Command not recognized! Use /help to get a list of commands" )
			return true
		end
	else
		-- toggle
		if( self.JsonData[userID][dataKey]) then
			self.JsonData[userID][dataKey] = false;
		else
			self.JsonData[userID][dataKey] = true;
		end
	end

	if( cmd == "grass" ) then
		self:performGrassCommand(self.JsonData[userID].removesGrass, netuser)
	end
	if ( cmd == "banner" ) then
		self:performBannerCommand(self.JsonData[userID].removesBanner, netuser)
	end
	if ( cmd == "nudity") then
		self:performNudityCommand(self.JsonData[userID].nudityOn, netuser)
	end
	-- saves user data
	self:Save();
end

-- Client command executions
-- grass
function PLUGIN:performGrassCommand( isOff , netuser )
	if(isOff) then
		rust.RunClientCommand(netuser, "grass.on false")
	else
		rust.RunClientCommand(netuser, "grass.on true")
	end
end
-- banner
function PLUGIN:performBannerCommand( hide , netuser)
	if(hide) then
		rust.RunClientCommand(netuser, "gui.hide_branding")
	else
		rust.RunClientCommand(netuser, "gui.show_branding")
	end
end
-- nudity
function PLUGIN:performNudityCommand( isOff , netuser)
	if(isOff) then
		rust.RunClientCommand(netuser, "censor.nudity false")
	else
		rust.RunClientCommand(netuser, "censor.nudity true")
	end
end

-- userSettings
-- default entry for user
function PLUGIN:AddDefaultUserEntryToJsonDataIfNotExist(netuser)
local userID = rust.GetUserID( netuser );
local userentry = self.JsonData[userID];
--Create user if user is not present
	if (not userentry) then
		userentry = {};
		userentry.removesGrass  = self.Config.removesGrass
		userentry.removesBanner = self.Config.removesBanner
		userentry.nudityOn = self.Config.nudityOn
		self.JsonData[userID] = userentry;
	end
end

-- saves users settings
function PLUGIN:Save()
	self.JsonDataDataFile:SetText( json.encode( self.JsonData ) );
	self.JsonDataDataFile:Save();
end
