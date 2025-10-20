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

--// Variables
local LocalPlayer = Players.LocalPlayer
local DexLoaded = false

--//Libraries
local repo         = 'https://raw.githubusercontent.com/TheWooffles/Venex/main/Libraries/'
local Library      = Load(repo .. 'VenexUI/Library.lua')
local ThemeManager = Load(repo .. 'VenexUI/addons/ThemeManager.lua')
local SaveManager  = Load(repo .. 'VenexUI/addons/SaveManager.lua')
local VenexEsp     = Load(repo .. 'VenexESP/Venex.lua')

if not (Library and ThemeManager and SaveManager and VenexEsp) then
    Library:Notify("[Venex] One or more libs failed to load. Some features may be unavailable.")
end

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

local LGVisuals = Tabs.Visuals:AddLeftGroupbox('Enemy Esp')
local LGMisc    = Tabs.Misc:AddLeftGroupbox('Venex')
local RGMisc    = Tabs.Misc:AddRightGroupbox('Tools')
local MenuGroup = Tabs.Settings:AddLeftGroupbox('Menu')

LGVisuals:AddToggle('EspEnemy', {
    Text = 'Enable', Default = false, Tooltip = 'Enable Enemy Esp',
    Callback = function(v) VenexEsp.teamSettings.enemy.enabled = v end
})
LGVisuals:AddToggle('EspEnemyBox', {
    Text = 'Box 2D', Default = false,
    Callback = function(v) VenexEsp.teamSettings.enemy.box = v end
})

RGMisc:AddButton('Rejoin Server', function()
    Library:Notify('Rejoining current server...', 3)
    wait(0.5)
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end)

RGMisc:AddButton('Server Hop', function()
    Library:Notify('Searching for another server...', 5)
    local ok, res = pcall(function()
        local s = safeHttpGet(string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", game.PlaceId))
        return s and HttpService:JSONDecode(s) or nil
    end)
    if ok and res and res.data then
        for _, server in ipairs(res.data) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                Library:Notify('Joining a new server...', 3)
                TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                return
            end
        end
        Library:Notify('No other servers found.', 3)
    else
        Library:Notify('Failed to fetch server list.', 5)
    end
end)

RGMisc:AddDivider()

RGMisc:AddButton('Execute Dex', function()
    if DexLoaded then return notify('Dex already executed!', 3) end
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
    Library:Toggle()
    WatermarkConnection:Disconnect()
    VenexEsp:Unload()
	wait(1)
    print('[Venex] Info : Unloaded!')
    Library.Unloaded = true
	_G.VenexExecuted = false
end)

MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'RightShift', NoUI = true, Text = 'Menu keybind' })
Library.ToggleKeybind = Options.MenuKeybind

VenexEsp:Load()
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