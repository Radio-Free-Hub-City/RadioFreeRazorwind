--------------------------------------------------
-- GLOBAL DATABASE & VARIABLES
--------------------------------------------------
RadioFreeRazorwindDB = RadioFreeRazorwindDB or {
    radioEnabled = true,
    volume = 1.0,
    selectedVoiceID = 0,
    commercialFrequency = 2 -- Default: Commercial every 2 songs (0 = Off)
}

local currentTrackIndex = nil
local radioTimer = nil
local trackStartTime = 0
local currentTrackDuration = 0
local isCommercialPlaying = false
local songsPlayedSinceCommercial = 0

--------------------------------------------------
-- PLAYLIST & ALL-TTS COMMERCIAL LIST
--------------------------------------------------
local musicPlaylist = {
    { title = "Graves Lament", fdid = 1676892, duration = 312 },
    { title = "Quiet Heart", fdid = 1067565, duration = 224 },
    { title = "Halls of Iron", fdid = 298922, duration = 196 },
    { title = "Let Him Pass", fdid = 350012, duration = 91 },
    { title = "Tournament Battle 3", fdid = 316407, duration = 162 },
    { title = "ZF Big Battle 13", fdid = 371365, duration = 54 },
    { title = "ZF Big Battle 14", fdid = 371366, duration = 61 },
    { title = "Karazhan Disco 1", fdid = 1674366, duration = 111 },
    { title = "Karazhan Disco 2", fdid = 1674367, duration = 61 },
    { title = "Druids of the Flame", fdid = 528352, duration = 91 },
    { title = "Tristring Guitar A", fdid = 1538384, duration = 36 },
    { title = "Tristring Guitar B", fdid = 1538385, duration = 33 },
    { title = "Tristring Guitar C", fdid = 1538386, duration = 47 },
    { title = "Tristring Guitar D", fdid = 1538387, duration = 37 },
    { title = "Tristring Theme A", fdid = 1538388, duration = 46 },
    { title = "Tristring Theme B", fdid = 1538389, duration = 53 },
    { title = "Tristring Theme C", fdid = 1538390, duration = 52 },
    { title = "Tristring Theme D", fdid = 1538391, duration = 50 },
    { title = "Tristring Theme E", fdid = 1538392, duration = 48 },
    { title = "Brewfest - Dwarves", fdid = 228573, duration = 115 },
    { title = "Brewfest - Goblins", fdid = 228576, duration = 93 },
    { title = "Level70ETC", fdid = 877254, duration = 280 }
}

local commercialList = {
    { 
        text = "You're listening to Radio Free Razorwind, the hottest tunes this side of Molten Core!", 
        display = "STATION ID: RADIO FREE RAZORWIND",
        duration = 6
    },
    { 
        text = "And now for a brief word from our sponsors. Need an idea what dungeon or delve to try next? Try Kah jah Cola today! It gives you ideas!", 
        display = "COMMERCIAL: KAJA'COLA!",
        duration = 7
    },
    { 
        text = "And now for a brief word from our sponsors. Hungry? Smokywood Pastures has what you need!", 
        display = "COMMERCIAL: SMOKYWOOD PASTURES",
        duration = 6
    },
    { 
        text = "And now for a brief word from our sponsors. Got a sweet tooth? Have a piece of the Crown Chocolate Sampler... it's to die for!", 
        display = "COMMERCIAL: CROWN CHOCOLATE",
        duration = 7
    }
}

--------------------------------------------------
-- SAFE TTS WRAPPER
--------------------------------------------------
local function SpeakTTS(text)
    if C_VoiceChat and C_VoiceChat.SpeakText then
        local voiceID = (RadioFreeRazorwindDB and RadioFreeRazorwindDB.selectedVoiceID) or 0
        local rate = Enum.VoiceChatSpeakTextRate and Enum.VoiceChatSpeakTextRate.Standard or 0
        C_VoiceChat.SpeakText(voiceID, text, rate, 100)
    else
        print("|cFF00FF00[RFR Commercial]:|r " .. text)
    end
end

--------------------------------------------------
-- RADIO CHASSIS FRAME
--------------------------------------------------
local mainFrame = CreateFrame("Frame", "RFR_MainFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(360, 240)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
mainFrame:Hide()

mainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 }
})

mainFrame:EnableMouse(true)
mainFrame:SetMovable(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
mainFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

-- Header
mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
mainFrame.title:SetPoint("TOP", mainFrame, "TOP", 0, -14)
mainFrame.title:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
mainFrame.title:SetTextColor(1, 0.82, 0)
mainFrame.title:SetText("RADIO FREE RAZORWIND")

--------------------------------------------------
-- RETRO GREEN LCD DISPLAY SCREEN
--------------------------------------------------
local lcdDisplay = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
lcdDisplay:SetSize(320, 55)
lcdDisplay:SetPoint("TOP", mainFrame.title, "BOTTOM", 0, -8)
lcdDisplay:SetBackdrop({
    bgFile = "Interface\\CHATFRAME\\CHATFRAMEBACKGROUND",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
lcdDisplay:SetBackdropColor(0.02, 0.12, 0.02, 0.95)
lcdDisplay:SetBackdropBorderColor(0.2, 0.4, 0.2, 1)

lcdDisplay.nowPlaying = lcdDisplay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
lcdDisplay.nowPlaying:SetPoint("TOP", lcdDisplay, "TOP", 0, -8)
lcdDisplay.nowPlaying:SetFont("Fonts\\MORPHEUS.TTF", 13, "OUTLINE")
lcdDisplay.nowPlaying:SetTextColor(0.2, 1.0, 0.2)
lcdDisplay.nowPlaying:SetText("STANDBY... TUNE IN")

lcdDisplay.timerText = lcdDisplay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
lcdDisplay.timerText:SetPoint("BOTTOM", lcdDisplay, "BOTTOM", 0, -8)
lcdDisplay.timerText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
lcdDisplay.timerText:SetTextColor(0.15, 0.8, 0.15)
lcdDisplay.timerText:SetText("00:00 / 00:00")

--------------------------------------------------
-- RADIO ENGINE & TIMING CONTROLS
--------------------------------------------------
local function FormatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", mins, secs)
end

local PlayRandomTrack
local PlayTrack
local PlayCommercial

local function ShouldPlayCommercial()
    local freq = RadioFreeRazorwindDB and RadioFreeRazorwindDB.commercialFrequency or 2
    if freq <= 0 then return false end
    return songsPlayedSinceCommercial >= freq
end

PlayCommercial = function()
    isCommercialPlaying = true
    songsPlayedSinceCommercial = 0

    local comm = commercialList[math.random(1, #commercialList)]
    trackStartTime = GetTime()
    currentTrackDuration = comm.duration
    lcdDisplay.nowPlaying:SetText(comm.display)

    SpeakTTS(comm.text)

    local nextIndex = math.random(1, #musicPlaylist)
    if #musicPlaylist > 1 and nextIndex == currentTrackIndex then
        nextIndex = (nextIndex % #musicPlaylist) + 1
    end
    
    currentTrackIndex = nextIndex
    local track = musicPlaylist[nextIndex]

    SetCVar("Sound_EnableMusic", 1)
    PlayMusic(track.fdid)

    if radioTimer then radioTimer:Cancel() end

    radioTimer = C_Timer.NewTimer(comm.duration, function()
        isCommercialPlaying = false
        songsPlayedSinceCommercial = 1
        
        trackStartTime = GetTime() - comm.duration
        currentTrackDuration = track.duration
        lcdDisplay.nowPlaying:SetText("PLAYING: " .. track.title:upper())

        local remainingTime = track.duration - comm.duration
        radioTimer = C_Timer.NewTimer(remainingTime, function()
            if ShouldPlayCommercial() then
                PlayCommercial()
            else
                PlayRandomTrack()
            end
        end)
    end)
end

PlayTrack = function(index)
    if not musicPlaylist[index] then return end
    isCommercialPlaying = false
    currentTrackIndex = index
    songsPlayedSinceCommercial = songsPlayedSinceCommercial + 1
    
    local track = musicPlaylist[index]

    if radioTimer then radioTimer:Cancel() end

    SetCVar("Sound_EnableMusic", 1)
    PlayMusic(track.fdid)
    
    trackStartTime = GetTime()
    currentTrackDuration = track.duration

    lcdDisplay.nowPlaying:SetText("PLAYING: " .. track.title:upper())

    radioTimer = C_Timer.NewTimer(track.duration, function()
        if ShouldPlayCommercial() then
            PlayCommercial()
        else
            PlayRandomTrack()
        end
    end)
end

PlayRandomTrack = function()
    local nextIndex = math.random(1, #musicPlaylist)
    if #musicPlaylist > 1 and nextIndex == currentTrackIndex then
        nextIndex = (nextIndex % #musicPlaylist) + 1
    end
    PlayTrack(nextIndex)
end

local function TurnOnRadio()
    songsPlayedSinceCommercial = 0
    local freq = RadioFreeRazorwindDB and RadioFreeRazorwindDB.commercialFrequency or 2

    -- Direct play if ads are disabled
    if freq == 0 then
        PlayRandomTrack()
        return
    end

    isCommercialPlaying = true
    local introText = "You're listening to Radio Free Razor wind! Don't touch that dial, plenty of tunes coming up!"
    local introDuration = 6

    trackStartTime = GetTime()
    currentTrackDuration = introDuration
    lcdDisplay.nowPlaying:SetText("STATION ID: RADIO FREE RAZORWIND")

    SpeakTTS(introText)

    local nextIndex = math.random(1, #musicPlaylist)
    currentTrackIndex = nextIndex
    local track = musicPlaylist[nextIndex]

    SetCVar("Sound_EnableMusic", 1)
    PlayMusic(track.fdid)

    if radioTimer then radioTimer:Cancel() end

    radioTimer = C_Timer.NewTimer(introDuration, function()
        isCommercialPlaying = false
        songsPlayedSinceCommercial = 1
        
        trackStartTime = GetTime() - introDuration
        currentTrackDuration = track.duration
        lcdDisplay.nowPlaying:SetText("PLAYING: " .. track.title:upper())

        local remainingTime = track.duration - introDuration
        radioTimer = C_Timer.NewTimer(remainingTime, function()
            if ShouldPlayCommercial() then
                PlayCommercial()
            else
                PlayRandomTrack()
            end
        end)
    end)
end

local function StopRadio()
    StopMusic()
    if radioTimer then
        radioTimer:Cancel()
        radioTimer = nil
    end
    currentTrackIndex = nil
    isCommercialPlaying = false
    songsPlayedSinceCommercial = 0
    lcdDisplay.nowPlaying:SetText("RADIO OFFLINE")
    lcdDisplay.timerText:SetText("00:00 / 00:00")
end

local function TogglePower()
    if currentTrackIndex or isCommercialPlaying then
        StopRadio()
    else
        TurnOnRadio()
    end
end

C_Timer.NewTicker(0.5, function()
    if (currentTrackIndex or isCommercialPlaying) and currentTrackDuration > 0 then
        local elapsed = math.floor(GetTime() - trackStartTime)
        if elapsed <= currentTrackDuration then
            lcdDisplay.timerText:SetText(FormatTime(elapsed) .. " / " .. FormatTime(currentTrackDuration))
        end
    end
end)

--------------------------------------------------
-- DROPDOWN SELECTIONS (VOICE & COMMERCIAL FREQ)
--------------------------------------------------
local voiceDropdown = CreateFrame("Frame", "RFR_VoiceDropdown", mainFrame, "UIDropDownMenuTemplate")
voiceDropdown:SetPoint("TOPLEFT", lcdDisplay, "BOTTOMLEFT", -15, -8)
UIDropDownMenu_SetWidth(voiceDropdown, 120)

local function InitializeVoiceDropdown(self, level)
    local voices = C_VoiceChat and C_VoiceChat.GetTtsVoices and C_VoiceChat.GetTtsVoices() or {}
    local selectedID = RadioFreeRazorwindDB and RadioFreeRazorwindDB.selectedVoiceID or 0

    if #voices == 0 then
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Default System Voice"
        info.value = 0
        info.checked = (selectedID == 0)
        info.func = function()
            RadioFreeRazorwindDB.selectedVoiceID = 0
            UIDropDownMenu_SetText(voiceDropdown, "Default Voice")
        end
        UIDropDownMenu_AddButton(info, level)
        return
    end

    for _, voice in ipairs(voices) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = voice.name or ("Voice " .. voice.voiceID)
        info.value = voice.voiceID
        info.checked = (selectedID == voice.voiceID)
        info.func = function()
            RadioFreeRazorwindDB.selectedVoiceID = voice.voiceID
            UIDropDownMenu_SetText(voiceDropdown, voice.name or ("Voice " .. voice.voiceID))
            SpeakTTS("This is Radio Free Razor Wind, the hottest tunes this side of Molten Core!")
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

local commDropdown = CreateFrame("Frame", "RFR_CommercialDropdown", mainFrame, "UIDropDownMenuTemplate")
commDropdown:SetPoint("LEFT", voiceDropdown, "RIGHT", -25, 0)
UIDropDownMenu_SetWidth(commDropdown, 120)

local function GetFreqText(val)
    if val == 0 then return "Ads: Disabled" end
    if val == 1 then return "Ads: Every Song" end
    return "Ads: Every " .. val .. " Songs"
end

local function InitializeCommDropdown(self, level)
    local currentFreq = RadioFreeRazorwindDB and RadioFreeRazorwindDB.commercialFrequency or 2
    local options = {
        { text = "Disabled (Music Only)", value = 0 },
        { text = "Every 1 Song", value = 1 },
        { text = "Every 2 Songs", value = 2 },
        { text = "Every 3 Songs", value = 3 },
        { text = "Every 4 Songs", value = 4 },
        { text = "Every 5 Songs", value = 5 }
    }

    for _, opt in ipairs(options) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = opt.text
        info.value = opt.value
        info.checked = (currentFreq == opt.value)
        info.func = function()
            RadioFreeRazorwindDB.commercialFrequency = opt.value
            UIDropDownMenu_SetText(commDropdown, GetFreqText(opt.value))
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

--------------------------------------------------
-- ANALOG CONTROLS & VOLUME SLIDER
--------------------------------------------------
local playBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
playBtn:SetSize(75, 24)
playBtn:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 20, 45)
playBtn:SetText("POWER")
playBtn:SetScript("OnClick", function() TogglePower() end)

local skipBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
skipBtn:SetSize(75, 24)
skipBtn:SetPoint("LEFT", playBtn, "RIGHT", 8, 0)
skipBtn:SetText("TUNE")
skipBtn:SetScript("OnClick", function() PlayRandomTrack() end)

local stopBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
stopBtn:SetSize(75, 24)
stopBtn:SetPoint("LEFT", skipBtn, "RIGHT", 8, 0)
stopBtn:SetText("MUTE")
stopBtn:SetScript("OnClick", function() StopRadio() end)

local volSlider = CreateFrame("Slider", "RFR_VolumeSlider", mainFrame, "OptionsSliderTemplate")
volSlider:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -25, 18)
volSlider:SetSize(110, 16)
volSlider:SetMinMaxValues(0, 1)
volSlider:SetValueStep(0.05)
volSlider:SetObeyStepOnDrag(true)

_G[volSlider:GetName() .. "Low"]:SetText("Min")
_G[volSlider:GetName() .. "High"]:SetText("Max")
_G[volSlider:GetName() .. "Text"]:SetText("VOLUME")

volSlider:SetScript("OnValueChanged", function(self, value)
    SetCVar("Sound_MusicVolume", value)
end)

local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -2, -2)

--------------------------------------------------
-- SLASH COMMANDS & EVENT HANDLING
--------------------------------------------------
SLASH_RADIOFREERAZORWIND1 = "/rfr"
SLASH_RADIOFREERAZORWIND2 = "/razorwind"
SlashCmdList["RADIOFREERAZORWIND"] = function()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        volSlider:SetValue(tonumber(GetCVar("Sound_MusicVolume")) or 0.5)
        
        local voices = C_VoiceChat and C_VoiceChat.GetTtsVoices and C_VoiceChat.GetTtsVoices() or {}
        local currentName = "Default Voice"
        for _, voice in ipairs(voices) do
            if voice.voiceID == RadioFreeRazorwindDB.selectedVoiceID then
                currentName = voice.name
                break
            end
        end
        UIDropDownMenu_SetText(voiceDropdown, currentName)
        UIDropDownMenu_SetText(commDropdown, GetFreqText(RadioFreeRazorwindDB.commercialFrequency or 2))
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == "RadioFreeRazorwind" then
        if not RadioFreeRazorwindDB then 
            RadioFreeRazorwindDB = { radioEnabled = true, volume = 1.0, selectedVoiceID = 0, commercialFrequency = 2 }
        end
        if RadioFreeRazorwindDB.selectedVoiceID == nil then 
            RadioFreeRazorwindDB.selectedVoiceID = 0 
        end
        if RadioFreeRazorwindDB.commercialFrequency == nil then
            RadioFreeRazorwindDB.commercialFrequency = 2
        end
        
        UIDropDownMenu_Initialize(voiceDropdown, InitializeVoiceDropdown)
        UIDropDownMenu_Initialize(commDropdown, InitializeCommDropdown)
        
        print("|cFF00FF00[Radio Free Razorwind]|r Broadcast online! Type /rfr to open controls.")
    end
end)