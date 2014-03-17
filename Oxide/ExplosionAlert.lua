PLUGIN.Title = "Explosion Alert"
PLUGIN.Description = "Alerts when an explosion is being used"
PLUGIN.Version = "0.7"
PLUGIN.Author = "Shaheel"
PLUGIN.ConfigVersion = "1.2"

--datetime
local OSdateTime = util.GetStaticPropertyGetter( System.DateTime, 'Now' )

-- Loads the default configuration into the config table
function PLUGIN:LoadDefaultConfig()
	-- Sets default configuration settings
	self.Config.chatname = self.Config.chatname or "ExplosionAlert"
	self.Config.explosionMessage = self.Config.explosionMessage or "Ouch!"
	self.Config.showsAttackersName = self.Config.showsAttackersName or true
	self.Config.showsVictimsName = self.Config.showsVictimsName or true
	self.Config.showsDamagedObjectsName = self.Config.showsDamagedObjectsName or true
	self.Config.showsAlertInChat = self.Config.showsAlertInChat or true
	self.Config.showsAlertInChatToAdminsOnly = self.Config.showsAlertInChatToAdminsOnly or false
	self.Config.showsAlertToAdminConsole = self.Config.showsAlertToAdminConsole or false
	self.Config.showsLocationCoordinates = self.Config.showsLocationCoordinates or true
	self.Config.logsEnabled = self.Config.logsEnabled or true
	self.Config.showLogCommandEnabled = self.Config.showLogCommandEnabled or true
	self.Config.showLogCommandToAdminOnly = self.Config.showLogCommandToAdminOnly or true
	self.Config.ConfigVersion = "1.2"
end

-- Initialization
function PLUGIN:Init()
	-- Load the config file
	local b, res = config.Read( "explosionAlert" )
	self.Config = res or {}
	if (not b) then
		self:LoadDefaultConfig()
		if (res) then config.Save( "explosionAlert" ) end
	end
	-- update configuration if required
	if ( self.Config.ConfigVersion ~= self.ConfigVersion) then
		self:LoadDefaultConfig()
		config.Save( "explosionAlert" )
	end

	-- get log file
	self.logFile = util.GetDatafile( "log_explosionAlert" )
	local txt = self.logFile:GetText()
	if (txt ~= "") then
		self.logDataArray = json.decode( txt )
	else
		self.logDataArray = {}
		self:Save()
	end

	-- Add chat commands
	self:AddChatCommands();
end

-- Commands
function PLUGIN:AddChatCommands()
	-- command log enable
	if( self.Config.showLogCommandEnabled ) then
		self:AddChatCommand( "explosionlog", self.cmdExplosionLog )
	end
end

-- CMD ManageCommands
function PLUGIN:cmdExplosionLog(netuser, cmd, args)
	if( self.Config.showLogCommandToAdminOnly ) then
		if ( netuser:CanAdmin() ) then
			-- shows logs to user
			self:sendLogViaChatToUser(netuser)
		else
			-- notice
			rust.Notice( netuser, "You must be an admin to run this command!" )
		end
	else
		self:sendLogViaChatToUser(netuser)
	end
end

-- location
function PLUGIN:getLocationStringFromUser(netuser)
	if( netuser == nil) then
		return "{unknown location}"
	end
	local coords = netuser.playerClient.lastKnownPosition
	local X = 0
	local Y = 0
	local Z = 0
	if (coords ~= nil) then
		if (coords.x ~= nil) then
			if(type(coords.x)=='number') then
				X = math.floor(coords.x);
			end
		end
		if (coords.y ~= nil) then
			if(type(coords.y)=='number') then
				Y = math.floor(coords.y);
			end
		end
		if (coords.z ~= nil) then
			if(type(coords.z)=='number') then
				Z = math.floor(coords.z);
			end
		end
	end
	return "{x:"..X.." y:"..Y.." z:"..Z.."}";
end

-- logging
function PLUGIN:logData(data)
	local datetime = tostring( OSdateTime() )
	-- remove numbers after PM
	local index = string.find(datetime, "PM:")

	-- remove numbers after AM
	if( index == nil) then
		index = string.find(datetime, "AM:")
	end

	local cleanedDateTime = datetime
	if( index ) then
		cleanedDateTime = string.sub(datetime,1,index+3)
	end

	if( cleanedDateTime == nil) then
		cleanedDateTime = ""
	end

	table.insert(self.logDataArray, cleanedDateTime..data)
	self:Save()
end

function PLUGIN:sendLogViaChatToUser(netuser)
	for i, str in pairs(self.logDataArray) do
		rust.SendChatToUser( netuser, self.Config.chatname, str)
	end
end

-- saves log file
function PLUGIN:Save()
	self.logFile:SetText( json.encode( self.logDataArray ) );
	self.logFile:Save();
end

-- damage listener
typesystem.LoadEnum( Rust.DamageTypeFlags, "DamageType" )
function PLUGIN:ModifyDamage(takedamage, damage)
	local damagetype = tostring(damage.damageTypes)
	local expectedDamageType = tostring(DamageType.damage_explosion)
	if(damagetype == expectedDamageType) then
		-- start building string
		local str = self.Config.explosionMessage
		local attackersName = damage.attacker.client.userName
		local damagedObjectName = self:SubStringAtPattern(takedamage.gameObject.Name, "%(Clone", "a structure")
		local victimsName = "Unknown"
		local locationDetails = self:getLocationStringFromUser(damage.attacker.client.netUser)

		-- get victim's name
		if( damage.victim.client and damage.victim.client.userName ) then
			victimsName = damage.victim.client.userName
		end

		if( self.Config.showsAttackersName ) then
			str = str.." "..attackersName
		end

		if( self.Config.showsDamagedObjectsName ) then
			str = str.." damaged "..damagedObjectName
		end

		if( self.Config.showsVictimsName and victimsName ~= "Unknown" ) then
			str = str.." belonging to "..victimsName
		end

		--location
		if( self.Config.showsLocationCoordinates and locationDetails ~=  "{unknown location}") then
			str = str.." located at "..locationDetails
		end

		-- end building string
		-- get all users (maybe not optimized ?)
		for _, netuser in pairs( rust.GetAllNetUsers() ) do
			-- if admin
			if ( netuser:CanAdmin() ) then
				-- alert to admin only ?
				if (self.Config.showsAlertInChat and self.Config.showsAlertInChatToAdminsOnly) then
					rust.SendChatToUser( netuser, self.Config.chatname, str)
				end
				-- show in admin console ?
				if (self.Config.showsAlertToAdminConsole) then
					rust.RunClientCommand( netuser, "echo "..str )
				end
			end
			-- alert to everyone ?
			if (self.Config.showsAlertInChat == true and self.Config.showsAlertInChatToAdminsOnly == false) then
				rust.SendChatToUser( netuser, self.Config.chatname, str)
			end
		end

		--log
		if( self.Config.logsEnabled ) then
			local logstring = attackersName.." -> "..damagedObjectName.."("..victimsName.." | "..locationDetails.." )"
			self:logData(logstring)
		end
	end
end

-- string utilities : substring from passed pattern
function PLUGIN:SubStringAtPattern(str, pattern, defaultStr)
	if( str == nil ) then
		return defaultStr
	end

	local index = string.find(str,pattern)
	if( index ) then
		return string.sub(str,1,index-1)
	end
	return str
end
