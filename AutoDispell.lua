--Define possible commands and parameters.
SLASH_AUTOD1 = "/ad"
SLASH_AUTOD2 = "/autod"
ARG_LIST = "list"
ARG_ADD = "add"
ARG_REMOVE = "remove"
ARG_ENABLE = "enable"
ARG_DISABLE = "disable"

--Local Buffs array, AutoDispell and Load frame
local adFrame = CreateFrame("Frame")
local lFrame = CreateFrame("Frame")
local lbuffs = {}

--Register events
adFrame:RegisterEvent("UNIT_AURA", arg1)
lFrame:RegisterEvent("ADDON_LOADED")


--Help function
local function PrintHelp()
	print("Available commands:")
	print("/autod or /ad - Prints this help menu.")
	print("/ad list - Lists all buffs to be dispelled.")
	print("/ad add BuffName - Adds a buff to the list.")
	print("/ad remove BuffName - Removes a buff from the list (also accepts an index, e.g. 2).")
	print("/ad enable / disable - Enables or disables the addon.")
end

--List all buffs contained in the array
local function ListBuffs()
	print("The following buffs are listed to be dispelled:")
    for i=1,table.getn(buffs),1 do
        print(string.format("%i: %s", i, buffs[i]))
    end
end

--Checks whether or not a buff already exists within the array
local function BuffAlreadyExists (val)
    for index, value in ipairs(buffs) do
        if value == val then
            return true
        end
    end

    return false
end

--Removes a buff by index.
local function RemoveBuffByIndex(i)
	if buffs[i] ~= nil then
		print(string.format("Removed %s from list", buffs[i]))
		table.remove(buffs, i)
	else		
    	print("No buffs were removed. Are you sure the buff is listed?")
	end
end

--Removes a buff by name
--Checks if buff exists before removing.
local function RemoveBuffByName(val)
	local rbuffs = 0
    for index, value in ipairs(buffs) do
        if value == val then
            print(string.format("Removed %s from list", buffs[index]))
            table.remove(buffs, index)
            rbuffs = rbuffs + 1
        end
    end
    if rbuffs == 0 then
    	print("No buffs were removed. Are you sure the buff is listed?")
    end
end

--Disables the eventbinding, /ad disable
local function RemoveEventBinding()
	adFrame:SetScript("OnEvent", nil)
end

--Adds the eventbinding, called on first start or /ad enable
local function AddEventBinding()
	adFrame:SetScript("OnEvent", function(self, event, ...) 
    	--Unpack the vararg into the variable(s) it contains
    	local unit = ...
 
        --If the event didn't fire on player, return
   	 	if unit ~= "player" then
   	    	return
	    end
 
    	--Iterate over all buffs in the array
    	for buff in ipairs(buffs) do
        	for i=1,32,1 do
            	--See if the player the buff
        		if UnitBuff("player", i) == tostring(buffs[buff]) then
                    --Dispell it
        	    	CancelUnitBuff(unit, i)
        	    	print("Canceled: ", tostring(buffs[buff]))
        		end
        	end
    	end
	end)
end

--Initial first run binding
--If buff variable is empty, fill it with a new local array.
lFrame:SetScript("OnEvent", function(self, event, ...) 
	if event == "ADDON_LOADED" then
		if buffs == nil then
			buffs = {}
		end
		if isEnabled == nil then
			print("AutoDispell has been automatically enabled. Use /ad to configure it.")
			isEnabled = true
		end
		if isEnabled then			
			print("AutoDispell is currently enabled. Use /autod or /ad to configure it.")
			AddEventBinding()
		else
			print("AutoDispell is disabled use /ad enable to enable it.")
		end
	end
end)

--Add commands to SlashCmdList
SlashCmdList["AUTOD"] = function(msg, editbox)
    -- pattern matching that skips leading whitespace and whitespace between cmd and args
    -- any whitespace at end of args is retained
    local _, _, cmd, args = string.find(msg, "%s?(%w+)%s?(.*)")
    if args == nil then
		PrintHelp()
    end
    if cmd == ARG_LIST then
       	if table.getn(buffs) == 0 then
        	print("No buffs listed, use /autod add 'BuffName' to add a new buff to list")
        else
			ListBuffs()
        end
    elseif cmd == ARG_ADD and args ~= nil then
    	if not BuffAlreadyExists(tostring(args)) then
        	print(string.format("Added: %s to list.", args))
        	table.insert(buffs, args)
        else
        	print(string.format("%s is already included in list.", args))
        end
    elseif cmd == ARG_REMOVE and args ~= nil then
    	--Check if it's a number
    	if tonumber(args) ~= nil then
   			RemoveBuffByIndex(tonumber(args))
   		else
   			RemoveBuffByName(tostring(args))
		end
	elseif cmd == ARG_ENABLE then
        AddEventBinding()
        isEnabled = true
    elseif cmd == ARG_DISABLE then
    	RemoveEventBinding()
    	isEnabled = false
    end
end
