if _G.VenexExecuted then
	Library:Notify('[Venex] Error : Already Loaded!', 5)
    return warn("[Venex] Error : Already Loaded!")
end

--//Load Funtions
local function HttpGet(url)
    local ok, res = pcall(game.HttpGet, game, url)
    if ok then return res end
    warn("[Venex] Error : HttpGet failed:", url, res)
    return nil
end

local function Load(url)
    local src = HttpGet(url)
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

--// Services
local Players             = game:GetService("Players")
local TeleportService     = game:GetService("TeleportService")

local LocalPlayer   = Players.LocalPlayer

local repo = 'https://raw.githubusercontent.com/TheWooffles/Venex/main/Libraries/VenexUI/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
    Title = 'Venex<font color="rgb(255, 0, 0)"> Vantage</font>',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Main = Window:AddTab('Main'),
	Combat = Window:AddTab('Combat'),
	Visuals = Window:AddTab('Visuals'),
    Misc = Window:AddTab('Misc'),
    Settings = Window:AddTab('Settings'),
}

local LGMisc = Tabs.Misc:AddLeftGroupbox('Scripts')
local RGMisc = Tabs.Misc:AddRightGroupbox('Server')
local MenuGroup = Tabs.Settings:AddLeftGroupbox('Menu')

RGMisc:AddButton('Rejoin Server', function()
    Library:Notify('Rejoining current server...', 3)
    wait(0.5)
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end)
local DexLoaded = false
LGMisc:AddButton('Execute Dex', function()
    if DexLoaded then return notify('Dex Debugger already executed!', 3) end
    DexLoaded = true
    Library:Notify('[Venex] Info : Executing Dex', 3)
    Load('https://raw.githubusercontent.com/TheWooffles/Venex/main/Libraries/VenexDEX/DexMobile.lua')
    Library:Notify('[Venex] Info : Executed!', 3)
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

-- Library.KeybindFrame.Visible = true;

Library:OnUnload(function()
	Library:Notify('[Venex] Warning : Unloading...', 10)
	wait(1)
    WatermarkConnection:Disconnect()
    print('[Venex] Info : Unloaded!')
    Library.Unloaded = true
	_G.VenexExecuted = false
end)

MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'RightShift', NoUI = true, Text = 'Menu keybind' })
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:SetFolder('VenexThemes')
SaveManager:SetFolder('VenexConfigs')
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()
Options.AccentColor:SetValueRGB(Color3.fromRGB(255, 255, 255))
Library.Watermark.Position = UDim2.new(0, 0, 0, 5)
_G.VenexExecuted = true
Library:Notify('[Venex] Info : Executed!', 5)

-- --//Load Funtions
-- local function safeHttpGet(url)
--     local ok, res = pcall(game.HttpGet, game, url)
--     if ok then return res end
--     warn("[Venex] Error : HttpGet failed:", url, res)
--     return nil
-- end

-- local function safeLoad(url)
--     local src = safeHttpGet(url)
--     if not src then return nil end
--     local ok, fn = pcall(loadstring, src)
--     if ok and type(fn) == "function" then
--         local success, lib = pcall(fn)
--         if success then return lib end
--         warn("[Venex] Error : loadstring run failed:", url, lib)
--     else
--         warn("[Venex] Error : loadstring compile failed:", url, fn)
--     end
--     return nil
-- end

-- --// Services
-- local Players             = game:GetService("Players")
-- local RunService          = game:GetService("RunService")
-- local Workspace           = game:GetService("Workspace")
-- local UserInputService    = game:GetService("UserInputService")
-- local TeleportService     = game:GetService("TeleportService")
-- local HttpService         = game:GetService("HttpService")
-- local SoundService        = game:GetService("SoundService")
-- local TweenService        = game:GetService("TweenService")
-- local MarketplaceService  = game:GetService("MarketplaceService")
-- local StarterGui          = game:GetService("StarterGui")
-- local Stats               = game:GetService("Stats")
-- local MenuColor           = Color3.fromRGB(255, 255, 255)

-- --// Libraries
-- local repo         = 'https://raw.githubusercontent.com/TheWooffles/Venex/main/Libraries/VenexUI/'
-- local Sense        = safeLoad('https://raw.githubusercontent.com/TheWooffles/Venex/main/Libraries/VenexESP/Venex.lua')
-- local Library      = safeLoad(repo .. 'Library.lua')
-- local ThemeManager = safeLoad(repo .. 'addons/ThemeManager.lua')
-- local SaveManager  = safeLoad(repo .. 'addons/SaveManager.lua')

-- if not (Library and ThemeManager and SaveManager and Sense) then
--     warn("[Venex] One or more libs failed to load. Some features may be unavailable.")
-- end

-- local function notify(msg, dur)
--     if Library and Library.Notify then
--         Library:Notify(msg, dur or 3)
--         print(msg)
--     end
-- end