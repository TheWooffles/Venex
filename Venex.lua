if _G.VenexExecuted then
	Library:Notify('[Venex] Error : Already Loaded!', 5)
    return warn("[Venex] Error : Already Loaded!")
end

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
local UserInputService    = game:GetService("UserInputService")
local RunService          = game:GetService("RunService")

--// Variables
local LocalPlayer          = Players.LocalPlayer
local DexLoaded            = false
local CoreGui              = (gethui and gethui()) or game:GetService("CoreGui")
local protectgui           = protectgui or (syn and syn.protect_gui) or function() end
local MenuColor            = Color3.fromRGB(255, 255, 255)
local VenexWatermark       = true
local Camera               = Workspace.CurrentCamera
local Workspace            = game:GetService("Workspace")
local ScreenCenter         = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

--// State
local aimbotTargetCache

--// Config
local Aimbot = {
    Enabled = false,
    Radius = 70,
    Type = 'Aimbot', -- "Aimbot" | "Custom"
    Position = 'Center', -- "Center" | "Mouse"
    TargetPart = 'Head',
    TeamCheck = true,
    WallCheck = true,
    AutoPrediction = false,
    Prediction = 0.143,
    Smoothness = 0.2,
    Offset = { X = 0, Y = 0 },
}

local function FovCirclePosition()
    if Aimbot.Position == 'Mouse' then
        return UserInputService:GetMouseLocation()
    elseif Aimbot.Position == 'Center' then
        return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    end
end

local bodyParts = {
    "Head",
    "HumanoidRootPart",
    "Torso",           -- R6
    "Left Arm",        -- R6
    "Right Arm",       -- R6
    "Left Leg",        -- R6
    "Right Leg",       -- R6
    "UpperTorso",      -- R15
    "LowerTorso",      -- R15
    "LeftUpperArm",    -- R15
    "LeftLowerArm",    -- R15
    "LeftHand",        -- R15
    "RightUpperArm",   -- R15
    "RightLowerArm",   -- R15
    "RightHand",       -- R15
    "LeftUpperLeg",    -- R15
    "LeftLowerLeg",    -- R15
    "LeftFoot",        -- R15
    "RightUpperLeg",   -- R15
    "RightLowerLeg",   -- R15
    "RightFoot"        -- R15
}

local ScreenGui = Instance.new('ScreenGui')
protectgui(ScreenGui)
ScreenGui.Name = "Venex"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui
ScreenGui.DisplayOrder = 1

local FovCircle     = Drawing.new("Circle")
FovCircle.Visible   = false
FovCircle.Thickness = 1
FovCircle.Color     = Color3.fromRGB(255,255,255)
FovCircle.Filled    = false
FovCircle.Radius    = Aimbot.Radius
FovCircle.Position  = FovCirclePosition()
FovCircle.ZIndex    = 1
FovCircle.Parent    = ScreenGui

local FovCircleOutline     = Drawing.new("Circle")
FovCircleOutline.Visible   = false
FovCircleOutline.Thickness = FovCircle.Thickness + 2
FovCircleOutline.Color     = Color3.fromRGB(0,0,0)
FovCircleOutline.Filled    = false
FovCircleOutline.Radius    = FovCircle.Radius - 1
FovCircleOutline.Position  = FovCircle.Position
FovCircleOutline.ZIndex    = 0
FovCircleOutline.Parent    = ScreenGui

local TargetIndicator        = Drawing.new("Circle")
TargetIndicator.Visible      = false
TargetIndicator.Radius       = 2
TargetIndicator.Thickness    = 1
TargetIndicator.Color        = Color3.fromRGB(255, 255, 255)
TargetIndicator.Filled       = true
TargetIndicator.Transparency = 0.2
TargetIndicator.ZIndex       = 0
TargetIndicator.Parent       = ScreenGui
 
-- local fov = Drawing.new("Circle")
-- fov.Visible = true
-- fov.Thickness = 1
-- fov.Color = Color3.fromRGB(255,255,255)
-- fov.Filled = false
-- fov.Radius = 100
-- fov.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
-- fov.ZIndex = 1
-- fov.Parent = ScreenGui
-- local fov1 = Drawing.new("Circle")
-- fov1.Visible = true
-- fov1.Thickness = fov.Thickness + 2
-- fov1.Color = Color3.fromRGB(0,0,0)
-- fov1.Filled = false
-- fov1.Radius = fov.Radius - 1
-- fov1.Position =  fov.Position
-- fov1.ZIndex = 0
-- fov1.Parent = ScreenGui

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
local LGCombat  = Tabs.Combat:AddLeftGroupbox('Aimbot')
local LGMisc    = Tabs.Misc:AddLeftGroupbox('Venex')
local RGMisc    = Tabs.Misc:AddRightGroupbox('Tools')
local MenuGroup = Tabs.Settings:AddLeftGroupbox('Menu')

-- Combat
LGCombat:AddToggle('AimbotEnabled', {
    Text = 'Enabled',
    Default = false,
    Tooltip = 'Enables Aimbot',
    Callback = function(v)
        Aimbot.Enabled = v
    end
})
LGCombat:AddToggle('AimbotTeamCheck', {
    Text = 'Team Check',
    Default = Aimbot.TeamCheck,
    Callback = function(v) Aimbot.TeamCheck = v end
})
LGCombat:AddToggle('AimbotWallCheck', {
    Text = 'Wall Check',
    Default = Aimbot.WallCheck,
    Callback = function(v) Aimbot.WallCheck = v end
})
LGCombat:AddToggle('AimbotAutoPrediction', {
    Text = 'Auto Prediction',
    Default = Aimbot.AutoPrediction,
    Callback = function(v) Aimbot.AutoPrediction = v end
})
LGCombat:AddDivider()
LGCombat:AddDropdown("AimbotType", {
    Text = "Type",
    Values = {"Aimbot"}, --, "ClientSilent"
    Default = "Aimbot",
    Callback = function(v) Aimbot.Type = v end
})
LGCombat:AddDropdown("AimbotTargetPart", {
    Text = "Target Part",
    Values = bodyParts,
    Default = Aimbot.TargetPart,
    Callback = function(v)
        Aimbot.TargetPart = v
    end
})
LGCombat:AddDropdown("AimbotPosition", {
    Text = "Position",
    Values = {"Mouse", "Center"},
    Default = Aimbot.Position,
    Callback = function(v)
        Aimbot.Position = v
    end
})
LGCombat:AddSlider('AimbotRadius', {
    Text = 'Radius',
    Default = Aimbot.Radius, Min = 0, Max = 300, Rounding = 0,
    Callback = function(v) Aimbot.Radius = v end
})
LGCombat:AddSlider('AimbotSmoothness', {
    Text = 'Smoothness',
    Default = Aimbot.Smoothness, Min = 0, Max = 1, Rounding = 2,
    Callback = function(v) Aimbot.Smoothness = v end
})
LGCombat:AddSlider('AimbotPrediction', {
    Text = 'Prediction',
    Default = Aimbot.Prediction, Min = 0, Max = 5, Rounding = 3,
    Callback = function(v) Aimbot.Prediction = v end
})
LGCombat:AddSlider('AimbotOffsetX', {
    Text = 'Horizontal Offset',
    Default = Aimbot.Offset.X, Min = -50, Max = 50, Rounding = 1,
    Callback = function(v) Aimbot.Offset.X = v end
})
LGCombat:AddSlider('AimbotOffsetY', {
    Text = 'Vertical Offset',
    Default = Aimbot.Offset.Y, Min = -50, Max = 50, Rounding = 1,
    Callback = function(v) Aimbot.Offset.Y = v end
})





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
LGVisuals:AddToggle('EspEnemyBox3D', {
    Text = 'Box 3D', Default = false,
    Callback = function(v) VenexEsp.teamSettings.enemy.box3d = v end
})
LGVisuals:AddToggle('EspEnemyName', {
    Text = 'Name', Default = false,
    Callback = function(v) VenexEsp.teamSettings.enemy.name = v end
})
LGVisuals:AddToggle('EspEnemyHealthBar', {
    Text = 'Health Bar', Default = false,
    Callback = function(v) VenexEsp.teamSettings.enemy.healthBar = v end
})
LGVisuals:AddToggle('EspEnemyHealthText', {
    Text = 'Health Text', Default = false,
    Callback = function(v) VenexEsp.teamSettings.enemy.healthText = v end
})
LGVisuals:AddToggle('EspEnemyChams', {
    Text = 'Chams', Default = false,
    Callback = function(v) VenexEsp.teamSettings.enemy.chams = v end
})
LGVisuals:AddToggle('EspEnemyChamsVisible', {
    Text = 'Chams Visible Check', Default = false,
    Callback = function(v) VenexEsp.teamSettings.enemy.chamsVisibleOnly = v end
})
-- LGVisuals:AddToggle('EspEnemyTool', {
--     Text = 'Tool/Weapon', Default = false,
--     Callback = function(v) VenexEsp.teamSettings.enemy.weapon = v end
-- })

LGVisuals:AddDivider()
LGVisuals:AddLabel('Box Color'):AddColorPicker('EspEnemyBoxColor', {
    Text = 'Box Color', Default = Color3.fromRGB(255,255,255),
    Callback = function(v) VenexEsp.teamSettings.enemy.boxColor[1] = v end
})
LGVisuals:AddLabel('Box 3D Color'):AddColorPicker('EspEnemyBox3DColor', {
    Text = 'Box 3D Color', Default = Color3.fromRGB(255,255,255),
    Callback = function(v) VenexEsp.teamSettings.enemy.box3dColor[1] = v end
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
    if DexLoaded then return notify('[Venex] Error : Dex already executed!', 3) end
    DexLoaded = true
    Library:Notify('[Venex] Info : Executing Dex', 3)
    Load('https://raw.githubusercontent.com/TheWooffles/Venex/main/Libraries/VenexDEX/DexMobile.lua')
    Library:Notify('[Venex] Info : Executed!', 3)
end)

-- local BaseplateEsp = VenexEsp.AddInstance(workspace.Baseplate, {
--     enabled = true,
--     text = "{name}\n{distance} Studs", -- Placeholders: {name}, {distance}, {position}
--     textColor = { Color3.new(1,1,1), 1 },
--     textOutline = true,
--     textOutlineColor = Color3.new(0,0,0),
--     textSize = 13,
--     textFont = 2,
--     limitDistance = false,
--     maxDistance = 150
-- })

-- local FovPositionConnection = RunService.RenderStepped:Connect(function()
--     fov.Position = UserInputService:GetMouseLocation()
--     fov1.Position = fov.Position
-- end);
local FrameTimer = tick()
local FrameCounter = 0;
local FPS = 60;
local WatermarkConnection = RunService.RenderStepped:Connect(function()
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

--// Utils
local function AliveCheck(player)
    local char = player and player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function TeamCheck(player)
    if not Aimbot.TeamCheck then return false end
    local lt, pt = LocalPlayer.Team, player.Team
    return lt and pt and (lt == pt)
end

local function isViewModel(obj)
    return obj and (obj.Parent == Camera or (LocalPlayer.Character and obj.Parent == LocalPlayer.Character))
end

local function buildRaycastParams()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.IgnoreWater = true
    local list = { LocalPlayer.Character }

    if LocalPlayer.Character then
        for _, item in ipairs(LocalPlayer.Character:GetChildren()) do
            if item:IsA("Tool") or item:IsA("Accessory") or item:IsA("Shirt") or item:IsA("Pants") or item:IsA("Hat") then
                table.insert(list, item)
            end
        end
    end
    for _, child in ipairs(Workspace:GetChildren()) do
        if isViewModel(child) then
            table.insert(list, child)
        end
    end
    params.FilterDescendantsInstances = list
    return params
end

local function canSee(part)
    if not (part and part.Parent) then return false end
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin)
    local result = Workspace:Raycast(origin, dir, buildRaycastParams())
    return (not result) or result.Instance:IsDescendantOf(part.Parent)
end

local function predictPosition(pos, vel, dist)
    if Aimbot.AutoPrediction and dist then
        return pos + (vel * (dist / 500))
    elseif Aimbot.Prediction and Aimbot.Prediction > 0 then
        return pos + (vel * Aimbot.Prediction)
    end
    return pos
end

local function getClosestTarget()
    local closest, bestDist2 = nil, (Aimbot.Radius * Aimbot.Radius)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and AliveCheck(plr) and not TeamCheck(plr) then
            local char = plr.Character
            local targetPart = char and char:FindFirstChild(Aimbot.TargetPart)
            if targetPart and (not Aimbot.WallCheck or canSee(targetPart)) then
                local sp, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local delta = Vector2.new(sp.X, sp.Y) - ScreenCenter
                    local d2 = delta.X * delta.X + delta.Y * delta.Y
                    if d2 < bestDist2 then
                        bestDist2 = d2
                        closest = plr
                    end
                end
            end
        end
    end
    return closest
end

local function aimCFrameFor(part)
    local pos = part.Position
    local dist = (Camera.CFrame.Position - pos).Magnitude
    local lookAt = predictPosition(pos, part.Velocity, dist)
    return CFrame.lookAt(Camera.CFrame.Position, lookAt)
end


local function visualAimbot(part)
    local cf = aimCFrameFor(part)
    Camera.CFrame = Camera.CFrame:Lerp(cf, math.clamp(Aimbot.Smoothness or 0.2, 0, 1))
end

local function updateFovDrawing()
    if not FovCircle then return end
    FovCircle.Position = FovCirclePosition() + Vector2.new(Aimbot.Offset.X, Aimbot.Offset.Y)
    FovCircle.Radius = Aimbot.Radius
    FovCircle.Visible = Aimbot.Enabled
    FovCircleOutline.Visible = Aimbot.Enabled
    FovCircleOutline.Position = FovCircle.Position
end

local function updateTargetIndicator(target)
    if not TargetIndicator then return end
    TargetIndicator.Visible = true
    if not (Aimbot.Enabled and target and target.Character) then
        -- if Cursor then Cursor.mode = crosshair_position end
        TargetIndicator.Visible = false
        return
    end
    local part = target.Character:FindFirstChild(Aimbot.TargetPart)
    if not part then return end
    local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
    if onScreen then
        TargetIndicator.Visible = true
        TargetIndicator.Position = Vector2.new(sp.X + lookAt.X, sp.Y + lookAt.Y)
        -- if Cursor and Cursor.sticky then
        --     Cursor.mode = 'custom'
        --     Cursor.position = Vector2.new(sp.X, sp.Y)
        -- elseif Cursor then
        --     Cursor.mode = crosshair_position
        -- end
    end
end

local AimbotConnection = RunService.RenderStepped:Connect(function()
    local vp = Camera.ViewportSize
    ScreenCenter = Vector2.new(vp.X/2, vp.Y/2)

    local closest = nil
    if Aimbot.Enabled then
        closest = getClosestTarget()
        if closest and closest.Character then
            local part = closest.Character:FindFirstChild(Aimbot.TargetPart)
            if part then
                if Aimbot.Type == "Aimbot" then
                    visualAimbot(part)
                elseif Aimbot.Type == "Custom" then
                    warn('Custom Unused')
                end
            end
        end
        updateFovDrawing()
    end
    if not Aimbot.Enabled then
        FovCircle.Visible = false
        updateFovDrawing()
    end
    if closest ~= aimbotTargetCache then
        aimbotTargetCache = closest
    end
    updateTargetIndicator(closest)
end)

local function DeleteDrawings()
    ScreenGui:Destroy()
    TargetIndicator:Destroy()
    FovCircle:Destroy()
    FovCircleOutline:Destroy()
end

Library:OnUnload(function()
	Library:Notify('[Venex] Warning : Unloading...', 10)
    Library:Toggle()
    FovPositionConnection:Disconnect()
    WatermarkConnection:Disconnect()
    Aimbot.Enabled = false
    -- AimbotConnection:Disconnect()
    VenexEsp:Unload()
    ScreenGui:Destroy()
    DeleteDrawings()
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