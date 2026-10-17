--------------------------------------------------
-- GLOBAL DATABASE & VARIABLES
--------------------------------------------------
RadioFreeRazorwindDB = RadioFreeRazorwindDB or {
    radioEnabled = true,
    volume = 1.0,
    selectedVoiceID = 0,
    commercialFrequency = 2, -- Default: Commercial every 2 songs (0 = Off)
    newsFrequency = 5,       -- Default: News every 5 songs (0 = Off)
    streamerMode = false,    -- Streamer mode toggle
    customCommercial = "Support the stream at twitch.tv/yourchannel!" -- Default custom ad text
}

local currentTrackIndex = nil
local radioTimer = nil
local trackStartTime = 0
local currentTrackDuration = 0
local isCommercialPlaying = false
local isNewsPlaying = false
local isScanning = false
local songsPlayedSinceCommercial = 0
local songsPlayedSinceNews = 0

--------------------------------------------------
-- PLAYLIST, COMMERCIALS, NEWS & STATIC SFX
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

local newsList = {
    { display = "NEWS: GNOMES TO RETAKE HOME", fdid = 222760, duration = 37 },
    { display = "NEWS: WAR COMING?", fdid = 222758, duration = 45 },
    { display = "NEWS: TRAGEDY IN IRONFORGE", fdid = 222759, duration = 48 },
    { display = "NEWS: MALFURION RETURNS", fdid = 222762, duration = 29 },
    { display = "NEWS: FORESAKEN WRONGLY BLAMED", fdid = 222766, duration = 54 },
    { display = "NEWS: THRALL WANTS YOU!", fdid = 466155, duration = 36 }
}

local staticList = {
    569693,
    568039,
    568977,
    568792,
    569734,
    568565,
    568775,
    568777
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
        print("|cFF00FF00[RFR TTS]:|r " .. text)
    end
end

--------------------------------------------------
-- RADIO CHASSIS FRAME
--------------------------------------------------
local mainFrame = CreateFrame("Frame", "RFR_MainFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(360, 340) -- Height adjusted to fit Streamer Mode controls
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
local PlayNews
local QueueNextMedia
local ScanAndTune

local function ShouldPlayNews()
    local freq = RadioFreeRazorwindDB and RadioFreeRazorwindDB.newsFrequency or 5
    if freq <= 0 then return false end
    return songsPlayedSinceNews >= freq
end

local function ShouldPlayCommercial()
    local freq = RadioFreeRazorwindDB and RadioFreeRazorwindDB.commercialFrequency or 2
    if freq <= 0 then return false end
    return songsPlayedSinceCommercial >= freq
end

QueueNextMedia = function()
    if ShouldPlayNews() then
        PlayNews()
    elseif ShouldPlayCommercial() then
        PlayCommercial()
    else
        PlayRandomTrack()
    end
end

PlayNews = function()
    isNewsPlaying = true
    isCommercialPlaying = false
    isScanning = false
    songsPlayedSinceNews = 0

    local newsItem = newsList[math.random(1, #newsList)]
    local introDuration = 4

    trackStartTime = GetTime()
    currentTrackDuration = newsItem.duration + introDuration
    lcdDisplay.nowPlaying:SetText(newsItem.display)

    SpeakTTS("And now the latest news")

    if radioTimer then radioTimer:Cancel() end

    radioTimer = C_Timer.NewTimer(introDuration, function()
        SetCVar("Sound_EnableMusic", 1)
        PlayMusic(newsItem.fdid)

        radioTimer = C_Timer.NewTimer(newsItem.duration, function()
            isNewsPlaying = false
            QueueNextMedia()
        end)
    end)
end

PlayCommercial = function()
    isCommercialPlaying = true
    isNewsPlaying = false
    isScanning = false
    songsPlayedSinceCommercial = 0

    local commText = ""
    local commDisplay = ""
    local commDuration = 6

    -- Check if Streamer Mode is enabled and custom text exists
    if RadioFreeRazorwindDB.streamerMode and RadioFreeRazorwindDB.customCommercial and RadioFreeRazorwindDB.customCommercial ~= "" then
        commText = RadioFreeRazorwindDB.customCommercial
        commDisplay = "COMMERCIAL: STREAMER PROMO"
        -- Estimate spoken TTS duration based on length (~12 chars per sec, min 5 seconds)
        commDuration = math.max(5, math.ceil(string.len(commText) / 12))
    else
        local comm = commercialList[math.random(1, #commercialList)]
        commText = comm.text
        commDisplay = comm.display
        commDuration = comm.duration
    end

    trackStartTime = GetTime()
    currentTrackDuration = commDuration
    lcdDisplay.nowPlaying:SetText(commDisplay)

    SpeakTTS(commText)

    local nextIndex = math.random(1, #musicPlaylist)
    if #musicPlaylist > 1 and nextIndex == currentTrackIndex then
        nextIndex = (nextIndex % #musicPlaylist) + 1
    end
    
    currentTrackIndex = nextIndex
    local track = musicPlaylist[nextIndex]

    SetCVar("Sound_EnableMusic", 1)
    PlayMusic(track.fdid)

    if radioTimer then radioTimer:Cancel() end

    radioTimer = C_Timer.NewTimer(commDuration, function()
        isCommercialPlaying = false
        songsPlayedSinceCommercial = 1
        
        trackStartTime = GetTime() - commDuration
        currentTrackDuration = track.duration
        lcdDisplay.nowPlaying:SetText("PLAYING: " .. track.title:upper())

        local remainingTime = track.duration - commDuration
        radioTimer = C_Timer.NewTimer(remainingTime, function()
            QueueNextMedia()
        end)
    end)
end

PlayTrack = function(index)
    if not musicPlaylist[index] then return end
    isCommercialPlaying = false
    isNewsPlaying = false
    isScanning = false
    currentTrackIndex = index
    songsPlayedSinceCommercial = songsPlayedSinceCommercial + 1
    songsPlayedSinceNews = songsPlayedSinceNews + 1
    
    local track = musicPlaylist[index]

    if radioTimer then radioTimer:Cancel() end

    SetCVar("Sound_EnableMusic", 1)
    PlayMusic(track.fdid)
    
    trackStartTime = GetTime()
    currentTrackDuration = track.duration

    lcdDisplay.nowPlaying:SetText("PLAYING: " .. track.title:upper())

    radioTimer = C_Timer.NewTimer(track.duration, function()
        QueueNextMedia()
    end)
end

PlayRandomTrack = function()
    local nextIndex = math.random(1, #musicPlaylist)
    if #musicPlaylist > 1 and nextIndex == currentTrackIndex then
        nextIndex = (nextIndex % #musicPlaylist) + 1
    end
    PlayTrack(nextIndex)
end

ScanAndTune = function()
    StopMusic()
    if radioTimer then radioTimer:Cancel() end

    isScanning = true
    isCommercialPlaying = false
    isNewsPlaying = false
    
    lcdDisplay.nowPlaying:SetText("*** SCANNING ***")
    lcdDisplay.timerText:SetText("00:00 / 00:01")

    local staticSFX = staticList[math.random(1, #staticList)]
    PlaySoundFile(staticSFX, "SFX")

    radioTimer = C_Timer.NewTimer(1.0, function()
        isScanning = false
        PlayRandomTrack()
    end)
end

local function TurnOnRadio()
    songsPlayedSinceCommercial = 0
    songsPlayedSinceNews = 0
    
    if ShouldPlayNews() then
        PlayNews()
        return
    elseif ShouldPlayCommercial() then
        PlayCommercial()
        return
    end

    PlayRandomTrack()
end

local function StopRadio()
    StopMusic()
    if radioTimer then
        radioTimer:Cancel()
        radioTimer = nil
    end
    currentTrackIndex = nil
    isCommercialPlaying = false
    isNewsPlaying = false
    isScanning = false
    songsPlayedSinceCommercial = 0
    songsPlayedSinceNews = 0
    lcdDisplay.nowPlaying:SetText("RADIO OFFLINE")
    lcdDisplay.timerText:SetText("00:00 / 00:00")
end

local function TogglePower()
    if currentTrackIndex or isCommercialPlaying or isNewsPlaying or isScanning then
        StopRadio()
    else
        TurnOnRadio()
    end
end

C_Timer.NewTicker(0.5, function()
    if (currentTrackIndex or isCommercialPlaying or isNewsPlaying) and not isScanning and currentTrackDuration > 0 then
        local elapsed = math.floor(GetTime() - trackStartTime)
        if elapsed <= currentTrackDuration then
            lcdDisplay.timerText:SetText(FormatTime(elapsed) .. " / " .. FormatTime(currentTrackDuration))
        end
    end
end)

--------------------------------------------------
-- DROPDOWN SELECTIONS (VOICE, AD FREQ, NEWS FREQ)
--------------------------------------------------
local voiceDropdown = CreateFrame("Frame", "RFR_VoiceDropdown", mainFrame, "UIDropDownMenuTemplate")
voiceDropdown:SetPoint("TOPLEFT", lcdDisplay, "BOTTOMLEFT", -15, -8)
UIDropDownMenu_SetWidth(voiceDropdown, 120)

local function InitializeVoiceDropdown(self, level)
    local voices = C_VoiceChat and C_VoiceChat.GetTtsVoices and C_VoiceChat.GetTtsVoices() or {}
    local selectedID = RadioFreeRazorwindDB and RadioFreeRazorwindDB.selectedVoiceID or 0

    if #voices == 0 then
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Default Voice"
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
            SpeakTTS("This is Radio Free Razor Wind!")
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

local commDropdown = CreateFrame("Frame", "RFR_CommercialDropdown", mainFrame, "UIDropDownMenuTemplate")
commDropdown:SetPoint("LEFT", voiceDropdown, "RIGHT", -25, 0)
UIDropDownMenu_SetWidth(commDropdown, 120)

local function GetCommFreqText(val)
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
            UIDropDownMenu_SetText(commDropdown, GetCommFreqText(opt.value))
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

-- News Dropdown Configuration
local newsDropdown = CreateFrame("Frame", "RFR_NewsDropdown", mainFrame, "UIDropDownMenuTemplate")
newsDropdown:SetPoint("TOPLEFT", voiceDropdown, "BOTTOMLEFT", 0, 2)
UIDropDownMenu_SetWidth(newsDropdown, 120)

local function GetNewsFreqText(val)
    if val == 0 then return "News: Disabled" end
    if val == 1 then return "News: Every Song" end
    return "News: Every " .. val .. " Songs"
end

local function InitializeNewsDropdown(self, level)
    local currentFreq = RadioFreeRazorwindDB and RadioFreeRazorwindDB.newsFrequency or 5
    local options = {
        { text = "Disabled (Off)", value = 0 },
        { text = "Every 1 Song (Debug)", value = 1 },
        { text = "Every 5 Songs", value = 5 },
        { text = "Every 10 Songs", value = 10 },
        { text = "Every 15 Songs", value = 15 },
        { text = "Every 20 Songs", value = 20 }
    }

    for _, opt in ipairs(options) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = opt.text
        info.value = opt.value
        info.checked = (currentFreq == opt.value)
        info.func = function()
            RadioFreeRazorwindDB.newsFrequency = opt.value
            UIDropDownMenu_SetText(newsDropdown, GetNewsFreqText(opt.value))
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

--------------------------------------------------
-- STREAMER MODE CONTROLS
--------------------------------------------------
local streamerCheck = CreateFrame("CheckButton", "RFR_StreamerCheck", mainFrame, "UICheckButtonTemplate")
streamerCheck:SetPoint("TOPLEFT", newsDropdown, "BOTTOMLEFT", 15, -4)
_G[streamerCheck:GetName() .. "Text"]:SetText("Enable Streamer Mode (Custom Commercial)")
_G[streamerCheck:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")

streamerCheck:SetScript("OnClick", function(self)
    RadioFreeRazorwindDB.streamerMode = self:GetChecked()
end)

local editBoxLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
editBoxLabel:SetPoint("TOPLEFT", streamerCheck, "BOTTOMLEFT", 0, -4)
editBoxLabel:SetText("Custom Commercial Text:")

local customEditBox = CreateFrame("EditBox", "RFR_CustomCommEditBox", mainFrame, "InputBoxTemplate")
customEditBox:SetSize(310, 20)
customEditBox:SetPoint("TOPLEFT", editBoxLabel, "BOTTOMLEFT", 5, -4)
customEditBox:SetAutoFocus(false)
customEditBox:SetMaxLetters(250)

local function SaveCustomText(self)
    RadioFreeRazorwindDB.customCommercial = self:GetText()
    self:ClearFocus()
end

customEditBox:SetScript("OnEnterPressed", SaveCustomText)
customEditBox:SetScript("OnEditFocusLost", SaveCustomText)

--------------------------------------------------
-- ANALOG CONTROLS & VOLUME SLIDER
--------------------------------------------------
local volSlider = CreateFrame("Slider", "RFR_VolumeSlider", mainFrame, "OptionsSliderTemplate")
volSlider:SetPoint("TOPLEFT", newsDropdown, "TOPRIGHT", -10, -5)
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

local playBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
playBtn:SetSize(90, 24)
playBtn:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 25, 20)
playBtn:SetText("POWER")
playBtn:SetScript("OnClick", function() TogglePower() end)

local skipBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
skipBtn:SetSize(90, 24)
skipBtn:SetPoint("LEFT", playBtn, "RIGHT", 20, 0)
skipBtn:SetText("TUNE")
skipBtn:SetScript("OnClick", function() ScanAndTune() end)

local stopBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
stopBtn:SetSize(90, 24)
stopBtn:SetPoint("LEFT", skipBtn, "RIGHT", 20, 0)
stopBtn:SetText("MUTE")
stopBtn:SetScript("OnClick", function() StopRadio() end)

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
        UIDropDownMenu_SetText(commDropdown, GetCommFreqText(RadioFreeRazorwindDB.commercialFrequency or 2))
        UIDropDownMenu_SetText(newsDropdown, GetNewsFreqText(RadioFreeRazorwindDB.newsFrequency or 5))

        -- Refresh Streamer Mode UI elements
        streamerCheck:SetChecked(RadioFreeRazorwindDB.streamerMode or false)
        customEditBox:SetText(RadioFreeRazorwindDB.customCommercial or "")
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == "RadioFreeRazorwind" then
        if not RadioFreeRazorwindDB then 
            RadioFreeRazorwindDB = { 
                radioEnabled = true, 
                volume = 1.0, 
                selectedVoiceID = 0, 
                commercialFrequency = 2, 
                newsFrequency = 5,
                streamerMode = false,
                customCommercial = "Support the stream at twitch.tv/yourchannel!"
            }
        end
        if RadioFreeRazorwindDB.selectedVoiceID == nil then 
            RadioFreeRazorwindDB.selectedVoiceID = 0 
        end
        if RadioFreeRazorwindDB.commercialFrequency == nil then
            RadioFreeRazorwindDB.commercialFrequency = 2
        end
        if RadioFreeRazorwindDB.newsFrequency == nil then
            RadioFreeRazorwindDB.newsFrequency = 5
        end
        if RadioFreeRazorwindDB.streamerMode == nil then
            RadioFreeRazorwindDB.streamerMode = false
        end
        if not RadioFreeRazorwindDB.customCommercial then
            RadioFreeRazorwindDB.customCommercial = "Support the stream at twitch.tv/yourchannel!"
        end
        
        UIDropDownMenu_Initialize(voiceDropdown, InitializeVoiceDropdown)
        UIDropDownMenu_Initialize(commDropdown, InitializeCommDropdown)
        UIDropDownMenu_Initialize(newsDropdown, InitializeNewsDropdown)
        
        print("|cFF00FF00[Radio Free Razorwind]|r Broadcast online! Type /rfr to open controls.")
    end
end)