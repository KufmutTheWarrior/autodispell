--Define possible commands and parameters.
SLASH_AUTOD1 = "/ad"
SLASH_AUTOD2 = "/autod"
ARG_LIST = "list"
ARG_ADD = "add"
ARG_REMOVE = "remove"
ARG_ENABLE = "enable"
ARG_DISABLE = "disable"
ARG_PLIST = "profiles"
ARG_RM = "rm"
ARG_PSEL = "select"

--Local Buffs array, AutoDispell and Load frame
local adFrame = CreateFrame("Frame")
local lFrame = CreateFrame("Frame")
local lbuffs = {}--2d array, profiles & their respective buffs
local profileName = 1

--Register events
adFrame:RegisterEvent("UNIT_AURA", arg1)
lFrame:RegisterEvent("ADDON_LOADED")

--Helper function for type checking
local function is_int(n)
    if n ~= nil then        
        return type(tonumber(n)) == "number"
    end
end

local function split (inputstr, sep)
    if sep == nil then
            sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end

local function has_value (tab, val)
    for index, value in ipairs(tab) do
        if tab[index][profileName] == val then
            return true
        end
    end
    return false
end

local function get_index(tab, val)
    for i,v in pairs(tab) do
        if tab[i][profileName] == val then
            return i
        end
    end
end

--Help function
local function PrintHelp()
    print("Available commands:")
    print("/autod or /ad - Prints this help menu.")
    print("/ad list - Lists all buffs to be dispelled.")
    print("/ad add Buff Name - Adds a buff to the list, for instance: /ad add Blessing of Salvation")
    print("/ad remove Buff Name - Removes a buff from the list by name. (also accepts an index: /ad remove 2)")
    print("/ad enable / disable - Enables or disables the addon.")
    --print("/ad profiles - Lists all profiles.")
    --print("/ad profiles add Profilename - Adds a new profile.")
    --print("/ad profiles remove Profilename - Removes a profile by name (or index).")
    --print("/ad profiles select Profilename - Selects a profile to be used.")
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

--Lists all profiles
local function ListProfiles()
    print("Profiles:")
    for i=1,table.getn(profiles),1 do
        if activeProfile == i then
            print(string.format("%i: %s (Active)", i, profiles[activeProfile][profileName]))
        else
            print(string.format("%i: %s", i, profiles[i][profileName]))
        end
    end
end

--Get the currently selected profile
local function SetProfile(val)
    if is_int(val) then
        valn = tonumber(val)
        if valn <= table.getn(profiles) and valn >= 1 then
            if valn == activeProfile then
                print(string.format("Profile: '%s' is already selected.", profiles[valn][profileName]))
            else
                activeProfile = valn
                print(string.format("Selected profile: '%s'", profiles[activeProfile][profileName]))
            end
        else
            print("Profile does not exist")
        end
    else
        if has_value(profiles, val) then 
            if activeProfile == get_index(profiles, val) then
                print(string.format("Profile: '%s' is already selected.", val))
            else
                activeProfile = get_index(profiles, val)
                print(string.format("Selected profile: '%s'", profiles[activeProfile][profileName]))                
            end
        else
            print("Profile does not exist")
        end
    end
end

--Add a profile, only accepts strings
local function AddProfile(name)
    if is_int(name) then
        print("Please enter a valid profile name.")
        return
    elseif has_value(profiles, name) then 
        print(string.format("Profile: '%s' already exists", name))
    else
        profiles[table.getn(profiles)+1] = { name }
        print(string.format("Added new profile: %s", name))
        SetProfile(name)          
    end
    return true
end

--Remove a profile by index or name
local function RemoveProfile(val)
    if is_int(val) then
        valn = tonumber(val)
        if valn <= table.getn(profiles) and valn ~= activeProfile then
            table.remove(profiles, valn)
            if activeProfile > table.getn(profiles) then
                activeProfile = activeProfile - 1
            end
            return true
        elseif valn < 1 then
            print("Profile not found.")
        else            
            print("Cannot remove active profile")
        end
        return false
    elseif has_value(profiles, val) then   
        if get_index(profiles, val) ~= activeProfile then      
            table.remove(profiles,get_index(profiles, val))
            if activeProfile > table.getn(profiles) then
                activeProfile = activeProfile - 1
            end
            return true
        else
            print("Cannot remove active profile")
        end
    else
        print("Profile not found.")
        return false
    end
end

--Initial first run binding
--If buff variable is empty, fill it with a new local array.
lFrame:SetScript("OnEvent", function(self, event, ...) 
    if event == "ADDON_LOADED" then
        if buffs == nil then
            buffs = {}
        end
        if profiles == nil then     
            profiles = {}       
            profiles[1] = {"default"}
            profiles[2] = {"tank"}
        end
        if activeProfile == nil then
            activeProfile = 1
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
    elseif cmd == ARG_PLIST then
        splitargs = split(args);
        if splitargs[1] == nil then
            ListProfiles()
        elseif splitargs[1] == ARG_PSEL and splitargs[2] ~= nil then
            SetProfile(splitargs[2])
        elseif splitargs[1] == ARG_ADD and splitargs[2] ~= nil then
            AddProfile(splitargs[2])
        elseif splitargs[1] == ARG_REMOVE or splitargs[2] == ARG_RM and splitargs[2] ~= nil then
            if RemoveProfile(splitargs[2]) then
                print("Profile was successfully removed.")
            end
        end
    else

    end

end
