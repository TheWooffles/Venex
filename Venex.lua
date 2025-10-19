if _G.VenexExecuted then
    return warn("[Venex] Error : Already Loaded!")
end

--//Load Funtions
local function safeHttpGet(url)
    local ok, res = pcall(game.HttpGet, game, url)
    if ok then return res end
    warn("[Venex] Error : HttpGet failed:", url, res)
    return nil
end

local function safeLoad(url)
    local src = safeHttpGet(url)
    if not src then return nil end
    local ok, fn = pcall(loadstring, src)
    if ok and type(fn) == "function" then
        local success, lib = pcall(fn)
        if success then return lib end
        warn("[Venex] Error : loadstring run failed:", url, lib)
    else
        warn("[Venex] Error : loadstring compile failed:", url, fn)
    end
    return nil
end

-- local function round(n) return math.floor((n or 0) + 0.5) end

--// Libraries
local repo         = 'https://raw.githubusercontent.com/TheWooffles/Venex/main/Libraries/VenexUI/'
local Sense        = safeLoad('https://raw.githubusercontent.com/TheWooffles/Venex/main/Libraries/VenexESP/Venex.lua')
local Library      = safeLoad(repo .. 'Library.lua')
local ThemeManager = safeLoad(repo .. 'addons/ThemeManager.lua')
local SaveManager  = safeLoad(repo .. 'addons/SaveManager.lua')

if not (Library and ThemeManager and SaveManager and Sense) then
    warn("[Venex] One or more libs failed to load. Some features may be unavailable.")
end

local function notify(msg, dur)
    if Library and Library.Notify then
        Library:Notify(msg, dur or 3)
        print(msg)
    end
end

local Window = Library:CreateWindow({
    Title = 'Venex<font color="rgba(255, 0, 0, 1)"> Vantage</font>',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Combat   = Window:AddTab('Combat'),
    Visuals  = Window:AddTab('Visuals'),
    Player   = Window:AddTab('Player'),
    Misc     = Window:AddTab('Misc'),
    Settings = Window:AddTab('Settings')
}
local ScMiscRG = Tabs.Misc:AddRightGroupbox('Scripts')

local DexLoaded = false
ScMiscRG:AddButton('Execute Dex Debugger', function()
    if DexLoaded then return notify('Dex Debugger already executed!', 3) end
    DexLoaded = true
    notify('[Venex] Info : Executing Dex', 3)
    safeLoad('https://raw.githubusercontent.com/TheWooffles/Venex/main/Libraries/VenexDex/DexFinal.lua')
    notify('[Venex] Info : Executed!', 3)
end)

Library:SetWatermarkVisibility(true)
local FrameTimer = tick()
local FrameCounter = 0;
local FPS = 60;

local WatermarkConnection = game:GetService('RunService').RenderStepped:Connect(function()
    FrameCounter += 1;

    if (tick() - FrameTimer) >= 1 then
        FPS = FrameCounter;
        FrameTimer = tick();
        FrameCounter = 0;
    end;

    Library:SetWatermark(('Venex | %s fps | %s ms'):format(
        math.floor(FPS),
        math.floor(game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue())
    ));
end);
Library.KeybindFrame.Visible = true;

Library:OnUnload(function()
    WatermarkConnection:Disconnect()

    print('Unloaded!')
    Library.Unloaded = true
    _G.VenexExecuted = false
end)

-- UI Settings
local MenuGroup = Tabs.Settings:AddLeftGroupbox('Menu')
MenuGroup:AddButton('Destroy', function() Library:Unload() end)
MenuGroup:AddLabel('Menu Bind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu keybind' })
Library.ToggleKeybind = Options.MenuKeybind -- Allows you to have a custom keybind for the menu

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
ThemeManager:SetFolder('VenexThemes')
SaveManager:SetFolder('VenexConfigs')
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()
_G.VenexExecuted = true