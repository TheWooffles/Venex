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

--// Services
local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local Workspace           = game:GetService("Workspace")
local UserInputService    = game:GetService("UserInputService")
local TeleportService     = game:GetService("TeleportService")
local HttpService         = game:GetService("HttpService")
local SoundService        = game:GetService("SoundService")
local TweenService        = game:GetService("TweenService")
local MarketplaceService  = game:GetService("MarketplaceService")
local StarterGui          = game:GetService("StarterGui")
local Stats               = game:GetService("Stats")
local ACCENT              = Color3.fromRGB(255, 255, 255)
local Camera              = Workspace.CurrentCamera
local LocalPlayer         = Players.LocalPlayer

--// Libraries
local repo         = 'https://gitlab.com/Wooffles/cncspt/-/raw/main/Libraries/Interface/'   --'https://raw.githubusercontent.com/TheWooffles/Venex/main/Libraries/VenexUI/'
local Sense        = safeLoad('https://raw.githubusercontent.com/TheWooffles/Venex/main/Libraries/VenexESP/Venex.lua')
local Library      = safeLoad(repo .. 'Library.lua')
local ThemeManager = safeLoad(repo .. 'addons/ThemeManager.lua')
local SaveManager  = safeLoad(repo .. 'addons/SaveManager.lua')

if not (Library and ThemeManager and SaveManager) then
    warn("[Venex] One or more libs failed to load. Some features may be unavailable.")
end

local function notify(msg, dur)
    if Library and Library.Notify then
        Library:Notify(msg, dur or 3)
        print(msg)
    end
end

local Window = Library:CreateWindow({
    Title = 'Venex<font color="rgb(255, 0, 0)"> Vantage</font>',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Window, Tabs, Toggles, Options
if Library and Library.CreateWindow then
    local okW
    okW, Window = pcall(Library.CreateWindow, Library, {
        Title = 'Venex<font color="rgb(255, 0, 0)"> Vantage</font>',
        Center = true,
        AutoShow = true,
        TabPadding = 8,
        MenuFadeTime = 0.2
    })
    if okW and Window then
        Library.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
        Library:SetWatermarkVisibility(true)
        notify('[Venex] Welcome ' .. LocalPlayer.Name .. '!', 5)
        Tabs = {
            Combat   = Window:AddTab('Combat'),
            Visuals  = Window:AddTab('Visuals'),
            Player   = Window:AddTab('Player'),
            Misc     = Window:AddTab('Misc'),
            Settings = Window:AddTab('Settings')
        }
        Toggles = _G.Toggles or getgenv().Toggles or Toggles
        Options = _G.Options or getgenv().Options or Options
    end
end

local AimbotLG = Tabs.Combat:AddLeftGroupbox('Aimbot')
local EspLG    = Tabs.Visuals:AddLeftGroupbox('Esp')
local MiscRG   = Tabs.Misc:AddRightGroupbox('Tools')

--// Sense ESP
if Sense and Sense.Load and not Sense.__loaded then
    local ok = pcall(function() Sense:Load() end)
    if ok then Sense.__loaded = true end
end

MiscRG:AddButton('Rejoin Server', function()
    notify('Rejoining current server...', 3)
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end)

local DexLoaded = false
MiscRG:AddButton('Execute Dex Debugger', function()
    if DexLoaded then return notify('Dex Debugger already executed!', 3) end
    DexLoaded = true
    notify('[Venex] Info : Executing Dex', 3)
    safeLoad('https://raw.githubusercontent.com/TheWooffles/Venex/main/Libraries/VenexDex/DexMobile.lua')
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
Library.ToggleKeybind = Options.MenuKeybind

--// Options Accent lock to ACCENT (if present)
RunService.RenderStepped:Connect(function()
    if Library and Library.Watermark then
        Library.Watermark.Position = UDim2.new(0, 0, 0, 5)
    end
    if Options and Options.AccentColor and Options.AccentColor.Value and Options.AccentColor.SetValueRGB then
        if Options.AccentColor.Value ~= ACCENT then
            Options.AccentColor:SetValueRGB(ACCENT)
        end
    end
end)

Sense.Load()
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