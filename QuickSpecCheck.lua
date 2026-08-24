-- Create modal popup window
StaticPopupDialogs["SPEC_CHECK_ALERT"] = {
    text = "CHECK YOUR SPEC & GEAR!\n\nBuild:\n|cFF00FF00%s|r\n\nEquipment Set:\n|cFF00FF00%s|r",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Helper function to find the name of the currently equipped equipment set
local function GetEquippedSetName()
    local equipmentSetIDs = C_EquipmentSet.GetEquipmentSetIDs()
    for _, setID in ipairs(equipmentSetIDs) do
        local name, _, _, isEquipped = C_EquipmentSet.GetEquipmentSetInfo(setID)
        if isEquipped then
            return name
        end
    end
    return "None / Custom Gear"
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, isInitialLogin, isReloading)
    if isInitialLogin or isReloading then return end

    local _, instanceType = GetInstanceInfo()

    if instanceType == "party" or instanceType == "raid" or instanceType == "scenario" then
        
        -- Get active specialization name
        local specIndex = GetSpecialization()
        local specID = specIndex and GetSpecializationInfo(specIndex)
        local specName = specIndex and select(2, GetSpecializationInfo(specIndex)) or "No Spec"

        -- Get saved loadout name
        local buildName = "Default / Custom"
        if specID then
            local lastSavedConfigID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
            if lastSavedConfigID then
                local configInfo = C_Traits.GetConfigInfo(lastSavedConfigID)
                if configInfo and configInfo.name and configInfo.name ~= "" then
                    buildName = configInfo.name
                end
            end
        end

        local fullSpecDisplay = specName .. " - " .. buildName
        local gearSetName = GetEquippedSetName()

        -- 1. Audio Warning
        PlaySound(8959, "Master")

        -- 2. Chat Log
        print("|cFFFF0000[Spec Check]|r Build: |cFF00FF00" .. fullSpecDisplay .. "|r | Gear: |cFF00FF00" .. gearSetName .. "|r")

        -- 3. Screen Alert Box
        StaticPopup_Show("SPEC_CHECK_ALERT", fullSpecDisplay, gearSetName)
    end
end)