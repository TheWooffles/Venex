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
local TweenService        = game:GetService("TweenService")

--// Variables
local LocalPlayer          = Players.LocalPlayer
local DexLoaded            = false
local CoreGui              = (gethui and gethui()) or game:GetService("CoreGui")
local queueTeleport        = queue_on_teleport
local protectgui           = protectgui or (syn and syn.protect_gui) or function() end
local MenuColor            = Color3.fromRGB(255, 255, 255)
local VenexWatermark       = true
local ExecuteVenexOnRejoin = true

local ScreenGui = Instance.new('ScreenGui')
protectgui(ScreenGui)
ScreenGui.Name = "Venex"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

--//Libraries
local repo         = 'https://raw.githubusercontent.com/TheWooffles/Venex/main/Libraries/'
local Library      = Load(repo .. 'VenexUI/Library.lua')
local ThemeManager = Load(repo .. 'VenexUI/addons/ThemeManager.lua')
local SaveManager  = Load(repo .. 'VenexUI/addons/SaveManager.lua')
local VenexEsp     = Load(repo .. 'VenexESP/Venex.lua')

if not (Library and ThemeManager and SaveManager and VenexEsp) then
    Library:Notify("[Venex] Error : One or more libs failed to load.\nSome features may be unavailable.")
end

local Window = Library:CreateWindow({
    Title = 'Venex<font color="rgb(255, 0, 0)"> Vantage</font>',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})
Library:SetWatermarkVisibility(true)

local Tabs = {
    Main     = Window:AddTab('Main'),
	Combat   = Window:AddTab('Combat'),
	Visuals  = Window:AddTab('Visuals'),
    Misc     = Window:AddTab('Misc'),
    Settings = Window:AddTab('Settings'),
}

local LGVisuals = Tabs.Visuals:AddLeftGroupbox('Enemy Esp')
local LGMisc    = Tabs.Misc:AddLeftGroupbox('Venex')
local RGMisc    = Tabs.Misc:AddRightGroupbox('Tools')
local MenuGroup = Tabs.Settings:AddLeftGroupbox('Menu')

LGMisc:AddToggle('Watermark', {
    Text = 'Show Watermark', Default = true, Tooltip = 'Enable Watermark',
    Callback = function(v)
        VenexWatermark = v
        Library:SetWatermarkVisibility(v)
    end
})
LGMisc:AddToggle('KeybindMenu', {
    Text = 'Show Keybind Menu', Default = false, Tooltip = 'Enable Keybind Menu',
    Callback = function(v) Library.KeybindFrame.Visible = v end
})
LGVisuals:AddToggle('EspEnemy', {
    Text = 'Enable', Default = false, Tooltip = 'Enable Enemy Esp',
    Callback = function(v) VenexEsp.teamSettings.enemy.enabled = v end
})
LGVisuals:AddToggle('EspEnemyBox', {
    Text = 'Box 2D', Default = false,
    Callback = function(v) VenexEsp.teamSettings.enemy.box = v end
})
LGVisuals:AddLabel('Box Color'):AddColorPicker('EspEnemyBoxColor', {
    Text = 'Box Color', Default = Color3.fromRGB(255,255,255),
    Callback = function(v) VenexEsp.teamSettings.enemy.boxColor[1] = v end
})
local object = VenexEsp.AddInstance(workspace.Baseplate, {
    --enabled = false,
    text = "{name}\n{distance} Studs", -- Placeholders: {name}, {distance}, {position}
    textColor = { Color3.new(1,1,1), 1 },
    textOutline = true,
    textOutlineColor = Color3.new(0,0,0),
    textSize = 13,
    textFont = 2,
    limitDistance = false,
    maxDistance = 150
})
object.options.enabled = true
LGVisuals:AddToggle('EspName', {
    Text = 'Name', Default = false,
    Callback = function(v) VenexEsp.teamSettings.enemy.name = v end
})
LGVisuals:AddToggle('EspHealthBar', {
    Text = 'Health Bar', Default = false,
    Callback = function(v) VenexEsp.teamSettings.enemy.healthBar = v end
})

RGMisc:AddButton('Rejoin Server', function()
    Library:Notify('Rejoining current server...', 3)
    if ExecuteVenexOnRejoin then
        queueTeleport(loadstring(game:HttpGet('https://raw.githubusercontent.com/TheWooffles/Venex/main/Venex.lua'))())
    end
    wait(0.5)
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end)
RGMisc:AddToggle('ExecuteVenexRejoin', {
    Text = 'Execute Venex After Rejoin', Default = ExecuteVenexOnRejoin, Tooltip = 'Executes Venex After Rejoinning',
    Callback = function(v) ExecuteVenexOnRejoin = v end
})

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
    if DexLoaded then return notify('[Venex] Error : Dex already executed!', 3) end
    DexLoaded = true
    Library:Notify('[Venex] Info : Executing Dex', 3)
    Load('https://raw.githubusercontent.com/TheWooffles/Venex/main/Libraries/VenexDEX/DexMobile.lua')
    Library:Notify('[Venex] Info : Executed!', 3)
end)

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
    if VenexWatermark and Library and Library.SetWatermark then
        Library:SetWatermark(('Venex | %s fps | %s ms'):format(
            math.floor(FPS),
            math.floor(game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue())
        ));
    end
end);

Library:OnUnload(function()
	Library:Notify('[Venex] Warning : Unloading...', 10)
    Library:Toggle()
    WatermarkConnection:Disconnect()
    VenexEsp:Unload()
    ScreenGui:Destroy()
	wait(1)
    print('[Venex] Info : Unloaded!')
    Library.Unloaded = true
	_G.VenexExecuted = false
end)

MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'RightShift', NoUI = true, Text = 'Menu keybind' })
Library.ToggleKeybind = Options.MenuKeybind

local Main = Instance.new("Frame")
Main.Name = "MainFrame"
Main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Main.BackgroundTransparency = 1
Main.Size = UDim2.new(0, 120, 0, 50)
Main.Position = UDim2.new(1, -130, 0, -50)
Main.Parent = ScreenGui

local Button = Instance.new("TextButton")
Button.Name = "MenuToggle"
Button.Text = "Venex"
Button.TextWrapped = true
Button.TextSize = 20
Button.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
Button.TextColor3 = Color3.fromRGB(255, 255, 255)
Button.BackgroundColor3 = MenuColor
Button.BackgroundTransparency = 0.5
Button.Size = UDim2.new(1, -10, 1, -10)
Button.Position = UDim2.new(0, 5, 0, 5)
Button.AutoButtonColor = false
Button.Draggable = true
Button.Parent = Main

local ButtonCorner = Instance.new("UICorner")
ButtonCorner.CornerRadius = UDim.new(0, 6)
ButtonCorner.Parent = Button

local ButtonStroke = Instance.new("UIStroke")
ButtonStroke.Color = Color3.fromRGB(80, 80, 80)
ButtonStroke.Thickness = 1
ButtonStroke.Parent = Button

local UIGradient = Instance.new("UIGradient")
UIGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, MenuColor),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 40, 40))
})
UIGradient.Rotation = 90
UIGradient.Parent = Button

local hoverTI = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Button.MouseEnter:Connect(function()
    TweenService:Create(Button, hoverTI, { BackgroundColor3 = Color3.fromRGB(220, 90, 90), BackgroundTransparency = 0.3 }):Play()
end)
Button.MouseLeave:Connect(function()
    TweenService:Create(Button, hoverTI, { BackgroundColor3 = MenuColor, BackgroundTransparency = 0.5 }):Play()
end)
Button.MouseButton1Down:Connect(function()
    task.spawn(Library.Toggle)
end)

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
Options.AccentColor:SetValueRGB(MenuColor)
Library.Watermark.Position = UDim2.new(0, 0, 0, 5)
_G.VenexExecuted = true
Library:Notify('[Venex] Info : Executed!', 5)