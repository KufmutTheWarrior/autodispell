--Define possible commands and parameters.
SLASH_AUTOD1 = "/ad"
SLASH_AUTOD2 = "/autod"
ARG_BUFF = "buffs"
ARG_PLIST = "profiles"
ARG_LIST = "list"
ARG_VERB = "verbose"
ARG_ALERT = "alert"
ARG_ADD = "add"
ARG_REMOVE = "remove"
ARG_RM = "rm"
ARG_PSEL = "select"
ARG_PSELS = "sel"
ARG_ENABLE = "enable"
ARG_DISABLE = "disable"
ARG_ON = "on"
ARG_OFF = "off"
--Local Buffs array, AutoDispell and Load frame
adFrame = CreateFrame("Frame")
lFrame = CreateFrame("Frame")
lbuffs = {}--2d array, profiles & their respective buffs
profileName = 1
buffList = 2
local addon_loaded = false
--Register events
adFrame:RegisterEvent("UNIT_AURA", "player")
lFrame:RegisterEvent("ADDON_LOADED")

local function Alert(target, buff)
    if alertOnBuff then
        local targetName = UnitName(target)
        if alertMsg == nil then
            alertMsg = string.format("AutoDispell: " .. buff .. " has been automatically removed.")
        end
        SendChatMessage(alertMsg, "WHISPER", nil, targetName);
    end
end


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

local function has_value (tab, val, type)
    if type == profileName then
        for i=1, #tab, 1 do
            if is_int(val) then
                if tab[i] == val then
                    return true
                end
            else
                if tab[i][profileName] == val then
                    return true
                end
            end
        end
    else
        for i, v in ipairs(tab[activeProfile][type]) do
            if tab[activeProfile][type][i] ~= nil then
                if tab[activeProfile][type][i] == val then
                    return true
                end
            end
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

local function get_buff_index(tab, val)
    for i,v in pairs(tab) do
        if tab[activeProfile][buffList][i] == val then
            return i
        end
    end
end

--Help function
local function PrintHelp()
    print("Available commands:")
    print("/autod or /ad - Prints this help menu.")
    print("/ad profiles - Lists all profiles.")
    print("/ad profiles add Profilename - Adds a new profile.")
    print("/ad profiles remove Profilename - Removes a profile by name (or index).")
    print("/ad profiles select Profilename - Selects a profile to be used by name (or index).")
    print("/ad buffs - Lists all buffs to be dispelled for the current profile.")
    print("/ad buffs add Buff Name - Adds a buff to the profile, for instance: /ad buffs add Blessing of Salvation")
    print("/ad buffs remove Buff Name - Removes a buff from the profile by name (or index: /ad buffs rm 2)")
    print("/ad alert enable / disable (or on / off) - Enables or disables alerting players who cast the buff on you (default is off).")    
    print("/ad alert add Custom Alert Message - Sets a new alert message.")
    print("/ad verbose enable / disable (or on / off) - Show a message when a buff was removed.")
    print("/ad enable / disable (or on / off)- Enables or disables the addon.")
end

--List all buffs contained in the array
local function ListBuffs()
    print(string.format("The following buffs are listed to be dispelled for profile %s:", profiles[activeProfile][profileName]))
    if profiles[activeProfile][buffList] ~= nil then
        for i=1, #profiles[activeProfile][buffList] ,1 do
            print(i .. ": " .. profiles[activeProfile][buffList][i])
        end
    else       
        print("No buffs listed, use /autod add 'Buff Name' to add a new buff to list")
    end
end

--Checks whether or not a buff already exists within the array
local function BuffAlreadyExists (val)
    if profiles[activeProfile][buffList] ~= nil then
        if #profiles[activeProfile][buffList] > 0 then
            for index, value in ipairs(profiles[activeProfile][buffList]) do
                if value == val then
                    return true
                end
            end
        end
    end
    return false
end

local function AddBuff(buff)
    if not BuffAlreadyExists(buff) then
        if #profiles[activeProfile][buffList] > 0 then 
            profiles[activeProfile][buffList][#profiles[activeProfile][buffList]+1] = buff
        else
            profiles[activeProfile][buffList][1] = buff
        end
        print("Added: " .. buff .. " to list.")
    else
        print(buff .. " is already included in list.")
    end
end


--Removes a buff by index.
local function RemoveBuffByIndex(i)
    if buffs[i] ~= nil then
        print("Removed " .. buffs[i] .. " from list")
        table.remove(buffs, i)
    else        
        print("No buffs were removed. Are you sure the buff is listed?")
    end
end

--Removes a buff by name
--Checks if buff exists before removing.
local function RemoveBuff(val)
    if is_int(val) then
        valn = tonumber(val)
        if valn <= table.getn(profiles[activeProfile][buffList]) and valn > 0 then
            local rmbuff = profiles[activeProfile][buffList][valn]
            table.remove(profiles[activeProfile][buffList], valn)
            print("Removed buff: '" .. rmbuff .. "'")
        else
            print("Buff not found.")
        end
    elseif not has_value(profiles, val, buffList) then 
        print("Buff not found.")        
    else
        local rmbuff = get_buff_index(profiles, val)
        table.remove(profiles[activeProfile][buffList], valn)
        print("Removed buff: '" .. val .. "'")                
    end
end

--Disables the eventbinding, /ad disable
local function RemoveEventBinding()
    adFrame:SetScript("OnEvent", nil)
    print("AutoDispell is disabled use /ad enable to enable it.")
end

local function Dispell(...)

    if ... ~= "player" then
        return
    end    

    for i=1,#profiles[activeProfile][buffList],1 do
        for j=1,32,1 do
            local name, rank, icon, count, dispelType, duration, caster, _, _, _, _, _, _, _, _, _, _ = UnitBuff("player", j)
           
            --See if the player the buff
            if name == tostring(profiles[activeProfile][buffList][i]) then 
                --Dispell it
                CancelUnitBuff("player", j)
                Alert(caster, name)
                if verbose then
                    print("Canceled: " .. profiles[activeProfile][buffList][i])
                end
            end
        end
    end
end

--Adds the eventbinding, called on first start or /ad enable
local function AddEventBinding()
    adFrame:SetScript("OnEvent", nil)
    adFrame:SetScript("OnEvent", function(self, event, ...) 
        Dispell(...)
    end)
end

--Lists all profiles
local function ListProfiles()
    print("Profiles:")
    for i=1, #profiles,1 do
        if activeProfile == i then
            print(string.format(i .. ": ".. profiles[i][profileName]) .. " (Active)")
        else
            print(i .. ": " .. profiles[i][profileName])
        end
    end
end

--Get the currently selected profile
local function SetProfile(val)
    if is_int(val) then
        valn = tonumber(val)
        if valn <= table.getn(profiles) and valn >= 1 then
            if valn == activeProfile then
                print("Profile: '" .. profiles[valn][profileName] .. "' is already selected.")
            else
                activeProfile = valn
                print("Selected profile: '" .. profiles[activeProfile][profileName] .. "'")
            end
        else
            print("Profile does not exist")
        end
    else
        if has_value(profiles, val, profileName) then 
            if activeProfile == get_index(profiles, val) then
                print("Profile: '" .. val .. "' is already selected.")
            else
                activeProfile = get_index(profiles, val)
                print("Selected profile: '" .. profiles[activeProfile][profileName] .. "'")                
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
    elseif has_value(profiles, name, profileName) then 
        print("Profile: '" .. name .. "' already exists")
    else
        local add_profile_pos = #profiles+1
        profiles[add_profile_pos] = {}
        profiles[add_profile_pos][profileName] = name
        profiles[add_profile_pos][buffList] = {}
        print("Added new profile: " .. name)
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
    elseif has_value(profiles, val, profileName) then   
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
    if event == "ADDON_LOADED" and not addon_loaded then
        addon_loaded = true
        if activeProfile == nil then
            activeProfile = 1
        end
        if profiles == nil then     
            profiles = {}       
            profiles[activeProfile] = {}
            profiles[activeProfile][profileName] = "default"
            profiles[activeProfile][buffList] = {}
            --Set default profile buffs if addon has been in use     
            if buffs ~= nil then
                profiles[activeProfile][buffList] = buffs
            end
        end   

        if alertOnBuff == nil then
            alertOnBuff = false
        end
        if verbose == nil then
            verbose = false
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
    if cmd == ARG_ENABLE or cmd == ARG_ON then        
        print("AutoDispell " .. (isEnabled and 'is already enabled.' or 'has been enabled.'))
        isEnabled = true
    elseif cmd == ARG_DISABLE or cmd == ARG_OFF then
        print("AutoDispell " .. (isEnabled and 'has been disabled.' or 'is already disabled.'))
        isEnabled = false
    elseif cmd == ARG_PLIST then
        splitargs = split(args);
        if splitargs[1] == nil then
            ListProfiles()
        elseif splitargs[1] == ARG_PSEL or splitargs[1] == ARG_PSELS and splitargs[2] ~= nil then
            SetProfile(splitargs[2])
            Dispell("player")
        elseif splitargs[1] == ARG_ADD and splitargs[2] ~= nil then
            AddProfile(splitargs[2])
        elseif splitargs[1] == ARG_REMOVE or splitargs[1] == ARG_RM and splitargs[2] ~= nil then
            if RemoveProfile(splitargs[2]) then
                print("Profile was successfully removed.")
            end
        end
    elseif cmd == ARG_BUFF then          
        splitargs = split(args);  
        if splitargs[1] == nil then
            ListBuffs()
        elseif splitargs[1] == ARG_ADD then
            table.remove(splitargs, 1)
            local buff = table.concat(splitargs, " ")
            AddBuff(buff)
            Dispell("player")
        elseif splitargs[1] == ARG_RM or splitargs[1] == ARG_REMOVE then
            table.remove(splitargs, 1)
            local buff = table.concat(splitargs, " ")
            RemoveBuff(buff)
        end
    elseif cmd == ARG_ALERT then
        splitargs = split(args);
        if splitargs[1] == nil then
            print("Alerts are currently " .. (alertOnBuff and 'enabled.' or 'disabled.'))            
        elseif splitargs[1] == ARG_ADD then
            table.remove(splitargs, 1)
            local msg = table.concat(splitargs, " ")
            alertMsg = msg
            print("Alert message has been set to " .. msg)
        elseif splitargs[1] == ARG_ENABLE or splitargs[1] == ARG_ON then
                print("Alerts " .. (alertOnBuff and 'are already enabled' or 'enabled'))
                alertOnBuff = true
        elseif splitargs[1] == ARG_DISABLE or splitargs[1] == ARG_OFF then
                print("Alerts " .. (alertOnBuff and 'disabled' or 'are already disabled'))
                alertOnBuff = false
        end
    elseif cmd == ARG_VERB then
        splitargs = split(args);
        if splitargs[1] == nil then
            print("Verbose mode is " .. (verbose and 'enabled.' or 'disabled.')) 
        end
        if splitargs[1] == ARG_ON or splitargs[1] == ARG_ENABLE then
            print("Verbose mode " .. (verbose and 'is already enabled' or 'enabled'))
            verbose = true
        elseif splitargs[1] == ARG_OFF or splitargs[1] == ARG_DISABLE then
            print("Verbose mode " .. (verbose and 'disabled' or 'is already disabled'))
            verbose = false
        end
    end
end
