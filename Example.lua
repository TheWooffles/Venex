if _G.VenexExecuted then
    return warn("[Venex] Error : Already Loaded!")
end
_G.VenexExecuted = true

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

--// Environment / exploit funcs (nil-guarded)
local CoreGui          = (gethui and gethui()) or game:GetService("CoreGui")
local queueTeleport    = queue_on_teleport
local setfpscap        = setfpscap or function() end
local protectgui       = protectgui or function() end

--// Player / Camera
local Camera        = Workspace.CurrentCamera
local LocalPlayer   = Players.LocalPlayer
local LPDisplayName = (LocalPlayer and LocalPlayer.DisplayName) or "Player"
local Executor      = identifyexecutor()

--// Colors
local ACCENT = Color3.fromRGB(100, 70, 200)

--// Helpers
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

local function round(n) return math.floor((n or 0) + 0.5) end

--// Libraries
local repo         = 'https://gitlab.com/Wooffles/cncspt/-/raw/main/Libraries/Interface/'            --'https://raw.githubusercontent.com/LionTheGreatRealFrFr/MobileLinoriaLib/main/'
local Sense        = safeLoad('https://gitlab.com/Wooffles/cncspt/-/raw/main/Libraries/Sense.lua')
-- local Cursor       = safeLoad('https://gitlab.com/Wooffles/cncspt/-/raw/main/Libraries/Cursor.lua')
local Library      = safeLoad(repo .. 'Library.lua') or _G.Library
local ThemeManager = safeLoad(repo .. 'addons/ThemeManager.lua')
local SaveManager  = safeLoad(repo .. 'addons/SaveManager.lua')

if not (Library and ThemeManager and SaveManager and Sense and Cursor) then
    warn("[Venex] One or more libs failed to load. Some features may be unavailable.")
end

--// GUI root early (so all later UI can parent safely)
local ScreenGui = Instance.new('ScreenGui')
protectgui(ScreenGui)
ScreenGui.Name = "Venex"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

--// State
local MainColor = ACCENT
local ScreenCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
local WatermarkVisible = true
local ControllerBinds = {"ButtonB", "ButtonX", "ButtonY", "DPadUp", "DPadDown", "DPadLeft", "DPadRight"}
local keepFovConn -- connection holder for Keep FOV
local fpsCounter = {t0 = tick(), frames = 0, fps = 60}
local AimbotFovCircle, TargetIndicator
local auraAttachment
local aimbotTargetCache -- last frame target cache
local SBLoaded = false
local crosshair_position = "Middle"

--// Config
local Config = {
    Aimbot = {
        Enabled = false,
        Radius = 50,
        Type = "Aimbot", -- "Aimbot" | "ClientSilent"
        FovVisible = true,
        FovFilled = false,
        FovPosition = function() return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2) end,
        FovColor = ACCENT,
        TargetPart = 'Head',
        TeamCheck = true,
        WallCheck = true,
        AutoPrediction = false,
        Prediction = 0.143,
        Smoothness = 0.2,
        Offset = { X = 0, Y = 0 },
    },
    SilentAim = { -- reserved, using Config.Aimbot for core logic
        Enabled = false,
        Radius = 50,
        FovVisible = true,
        FovFilled = false,
        FovColor = ACCENT,
        TargetPart = 'Head',
        TeamCheck = true,
        WallCheck = true,
        AutoPrediction = false,
        Prediction = 0.143,
        Offset = { X = 0, Y = 0 },
    },
    Chams = {
        FFBodyEnabled = false,
        FFToolsEnabled = false,
        FFHatsEnabled = false,
        FFBodyColor = ACCENT,
        FFToolsColor = ACCENT,
        FFHatsColor = ACCENT,
    },
    Aura = { Enabled = false, Type = "Heal" }, -- "Heal" | "Swirl"
    CFrameSpeed = {
        Enabled = false,
        Speed = 1,
        ControllerShortcut = false,
        ControllerValue = false,
        ControllerBind = 'ButtonY',
    },
    CameraFov = {
        KeepFov = false,
        Fov = nil,
        DefaultFOV = Camera.FieldOfView,
    },
    HitSounds = {
        Rust      = "rbxassetid://1255040462",
        Neverlose = 'rbxassetid://6534948092',
        Hit       = 'rbxassetid://1347140027',
        GameSense = 'rbxassetid://6534948092'
    },
}

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

--// Notify helper via Linoria if available
local function notify(msg, dur)
    if Library and Library.Notify then
        Library:Notify(msg, dur or 3)
        print(msg)
    else
        StarterGui:SetCore("SendNotification", {
            Title = "cncspt",
            Text = tostring(msg),
            Duration = dur or 3
        })
        print(msg)
    end
end

--// Drawing objects (guard if Drawing API unavailable)
local function makeDrawingObjects()
    if not Drawing then return end
    AimbotFovCircle = Drawing.new("Circle")
    AimbotFovCircle.Visible = false
    AimbotFovCircle.Thickness = 0.5
    AimbotFovCircle.Color = Config.Aimbot.FovColor
    AimbotFovCircle.Filled = Config.Aimbot.FovFilled
    AimbotFovCircle.Radius = Config.Aimbot.Radius
    AimbotFovCircle.Position = Config.Aimbot.FovPosition()
    AimbotFovCircle.ZIndex = 0

    TargetIndicator = Drawing.new("Circle")
    TargetIndicator.Visible = false
    TargetIndicator.Radius = 2
    TargetIndicator.Color = ACCENT
    TargetIndicator.Filled = true
    TargetIndicator.Transparency = 0.4
    TargetIndicator.ZIndex = 0
end
makeDrawingObjects()

--// Utils
local function isAlive(player)
    local char = player and player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function sameTeam(player)
    if not Config.Aimbot.TeamCheck then return false end
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
    if Config.Aimbot.AutoPrediction and dist then
        return pos + (vel * (dist / 500))
    elseif Config.Aimbot.Prediction and Config.Aimbot.Prediction > 0 then
        return pos + (vel * Config.Aimbot.Prediction)
    end
    return pos
end

local function getClosestTarget()
    local closest, bestDist2 = nil, (Config.Aimbot.Radius * Config.Aimbot.Radius)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr) and not sameTeam(plr) then
            local char = plr.Character
            local targetPart = char and char:FindFirstChild(Config.Aimbot.TargetPart)
            if targetPart and (not Config.Aimbot.WallCheck or canSee(targetPart)) then
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
    Camera.CFrame = Camera.CFrame:Lerp(cf, math.clamp(Config.Aimbot.Smoothness or 0.2, 0, 1))
end

local function updateFovDrawing()
    if not AimbotFovCircle then return end
    AimbotFovCircle.Position = Config.Aimbot.FovPosition() + Vector2.new(Config.Aimbot.Offset.X, Config.Aimbot.Offset.Y)
    AimbotFovCircle.Radius = Config.Aimbot.Radius
    AimbotFovCircle.Visible = Config.Aimbot.Enabled and Config.Aimbot.FovVisible
    AimbotFovCircle.Color = Config.Aimbot.FovColor
    AimbotFovCircle.Filled = Config.Aimbot.FovFilled
end

local function updateTargetIndicator(target)
    if not TargetIndicator then return end
    TargetIndicator.Visible = false
    if not (Config.Aimbot.Enabled and target and target.Character) then
        if Cursor then Cursor.mode = crosshair_position end
        return
    end
    local part = target.Character:FindFirstChild(Config.Aimbot.TargetPart)
    if not part then return end
    local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
    if onScreen then
        TargetIndicator.Visible = TargetIndicator.Visible
        TargetIndicator.Position = Vector2.new(sp.X, sp.Y)
        if Cursor and Cursor.sticky then
            Cursor.mode = 'custom'
            Cursor.position = Vector2.new(sp.X, sp.Y)
        elseif Cursor then
            Cursor.mode = crosshair_position
        end
    end
end

local function playHitSound()
    local sound = Instance.new('Sound')
    sound.SoundId = Config.HitSounds.Rust
    sound.Volume = 1
    sound.PlayOnRemove = true
    sound.Parent = SoundService
    sound:Destroy()
end

--// Forcefield chams
local function applyForcefieldToParts(parts, enabled, color)
    for _, p in ipairs(parts) do
        if p:IsA("BasePart") then
            if enabled then
                p.Material = Enum.Material.ForceField
                p.Color = color
            else
                p.Material = Enum.Material.Plastic
                -- keep existing part.Color to avoid forcing white each frame
            end
        end
    end
end

local function applyFFBody()
    local char = LocalPlayer.Character
    if char then
        applyForcefieldToParts(char:GetChildren(), Config.Chams.FFBodyEnabled, Config.Chams.FFBodyColor)
    end
end

local function applyFFTools()
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                applyForcefieldToParts(tool:GetChildren(), Config.Chams.FFToolsEnabled, Config.Chams.FFToolsColor)
            end
        end
    end
end

local function applyFFHats()
    local char = LocalPlayer.Character
    if char then
        for _, acc in ipairs(char:GetChildren()) do
            if acc:IsA("Accessory") then
                applyForcefieldToParts(acc:GetChildren(), Config.Chams.FFHatsEnabled, Config.Chams.FFHatsColor)
            end
        end
    end
end

--// Aura particles
local swirl, HealingWave1, HealingWave2, Sparks, StarSparks
local function initAura()
    auraAttachment = auraAttachment or Instance.new("Attachment")
    if not swirl then
        swirl = Instance.new("ParticleEmitter")
        swirl.Name = "swirl"
        swirl.Lifetime = NumberRange.new(2, 2)
        swirl.SpreadAngle = Vector2.new(-360, 360)
        swirl.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5006, 0.5),
            NumberSequenceKeypoint.new(1, 1)
        })
        swirl.LightEmission = 1
        swirl.Color = ColorSequence.new(ACCENT)
        swirl.VelocitySpread = -360
        swirl.Speed = NumberRange.new(0.01, 0.01)
        swirl.Size = NumberSequence.new(7)
        swirl.ZOffset = -1
        swirl.ShapeInOut = Enum.ParticleEmitterShapeInOut.InAndOut
        swirl.Rate = 150
        swirl.Texture = "rbxassetid://10558425570"
        swirl.RotSpeed = NumberRange.new(200, 200)
        swirl.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
        swirl.Parent = auraAttachment
    end
    if not HealingWave1 then
        HealingWave1 = Instance.new("ParticleEmitter")
        HealingWave1.Name = "Healing Wave 1"
        HealingWave1.Lifetime = NumberRange.new(1, 1)
        HealingWave1.SpreadAngle = Vector2.new(10, -10)
        HealingWave1.LockedToPart = true
        HealingWave1.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.1702, 0.7, 0.014),
            NumberSequenceKeypoint.new(0.2254, 0.03125, 0.03125),
            NumberSequenceKeypoint.new(0.2852, 0),
            NumberSequenceKeypoint.new(0.7024, 0),
            NumberSequenceKeypoint.new(0.8374, 0.9125, 0.06),
            NumberSequenceKeypoint.new(1, 1)
        })
        HealingWave1.LightEmission = 0.4
        HealingWave1.Color = ColorSequence.new(ACCENT)
        HealingWave1.VelocitySpread = 10
        HealingWave1.Speed = NumberRange.new(3, 6)
        HealingWave1.Brightness = 10
        HealingWave1.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 3.0625, 1.88),
            NumberSequenceKeypoint.new(0.642, 2, 1.76),
            NumberSequenceKeypoint.new(1, 0.75, 0.75)
        })
        HealingWave1.Rate = 10
        HealingWave1.Texture = "rbxassetid://8047533775"
        HealingWave1.RotSpeed = NumberRange.new(200, 400)
        HealingWave1.Rotation = NumberRange.new(-180, 180)
        HealingWave1.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
        HealingWave1.Parent = auraAttachment
    end
    if not HealingWave2 then
        HealingWave2 = Instance.new("ParticleEmitter")
        HealingWave2.Name = "Healing Wave 2"
        HealingWave2.Lifetime = NumberRange.new(1, 1)
        HealingWave2.SpreadAngle = Vector2.new(10, -10)
        HealingWave2.LockedToPart = true
        HealingWave2.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.2254, 0.03125, 0.03125),
            NumberSequenceKeypoint.new(0.6288, 0.25625, 0.059),
            NumberSequenceKeypoint.new(0.8374, 0.9125, 0.0601),
            NumberSequenceKeypoint.new(1, 1)
        })
        HealingWave2.LightEmission = 1
        HealingWave2.Color = ColorSequence.new(ACCENT)
        HealingWave2.VelocitySpread = 10
        HealingWave2.Speed = NumberRange.new(3, 5)
        HealingWave2.Brightness = 10
        HealingWave2.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 3.125),
            NumberSequenceKeypoint.new(0.4165, 1.375, 1.375),
            NumberSequenceKeypoint.new(1, 0.9375, 0.9375)
        })
        HealingWave2.Rate = 10
        HealingWave2.Texture = "rbxassetid://8047796070"
        HealingWave2.RotSpeed = NumberRange.new(100, 300)
        HealingWave2.Rotation = NumberRange.new(-180, 180)
        HealingWave2.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
        HealingWave2.Parent = auraAttachment
    end
    if not Sparks then
        Sparks = Instance.new("ParticleEmitter")
        Sparks.Name = "Sparks"
        Sparks.Lifetime = NumberRange.new(0.3, 1)
        Sparks.SpreadAngle = Vector2.new(180, -180)
        Sparks.LightEmission = 1
        Sparks.Color = ColorSequence.new(ACCENT)
        Sparks.Drag = 3
        Sparks.VelocitySpread = 180
        Sparks.Speed = NumberRange.new(5, 15)
        Sparks.Brightness = 10
        Sparks.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.146, 0.4375, 0.1875),
            NumberSequenceKeypoint.new(1, 0)
        })
        Sparks.Acceleration = Vector3.new(0, 3, 0)
        Sparks.ZOffset = -1
        Sparks.Rate = 30
        Sparks.Texture = "rbxassetid://8611887361"
        Sparks.RotSpeed = NumberRange.new(-30, 30)
        Sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
        Sparks.Parent = auraAttachment
    end
    if not StarSparks then
        StarSparks = Instance.new("ParticleEmitter")
        StarSparks.Name = "Star Sparks"
        StarSparks.Lifetime = NumberRange.new(1, 1)
        StarSparks.SpreadAngle = Vector2.new(180, -180)
        StarSparks.LightEmission = 1
        StarSparks.Color = ColorSequence.new(ACCENT)
        StarSparks.Drag = 3
        StarSparks.VelocitySpread = 180
        StarSparks.Speed = NumberRange.new(5, 10)
        StarSparks.Brightness = 10
        StarSparks.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.149, 0.6875, 0.6875),
            NumberSequenceKeypoint.new(1, 0)
        })
        StarSparks.Acceleration = Vector3.new(0, 3, 0)
        StarSparks.ZOffset = 2
        StarSparks.Texture = "rbxassetid://8611887703"
        StarSparks.RotSpeed = NumberRange.new(-30, 30)
        StarSparks.Rotation = NumberRange.new(-30, 30)
        StarSparks.Parent = auraAttachment
    end
end

local function parentAuraEffects()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        if not auraAttachment then initAura() end
        auraAttachment.Parent = hrp
    end
end

local function setupParticles()
    if not auraAttachment then return end
    local heal = (Config.Aura.Enabled and Config.Aura.Type == "Heal")
    local swirlOn = (Config.Aura.Enabled and Config.Aura.Type == "Swirl")
    if swirl then swirl.Enabled = swirlOn end
    if StarSparks then StarSparks.Enabled = heal end
    if Sparks then Sparks.Enabled = heal end
    if HealingWave1 then HealingWave1.Enabled = heal end
    if HealingWave2 then HealingWave2.Enabled = heal end
end

Players.LocalPlayer.CharacterAdded:Connect(parentAuraEffects)
parentAuraEffects()

--// Linoria UI
local Window, Tabs, Toggles, Options
if Library and Library.CreateWindow then
    local okW
    okW, Window = pcall(Library.CreateWindow, Library, {
        Title = 'Cncspt<font color="rgb(100, 70, 200)"> Main</font>',
        Center = true,
        AutoShow = true,
        TabPadding = 8,
        MenuFadeTime = 0.2
    })
    if okW and Window then
        Library.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
        Library:SetWatermarkVisibility(true)
        notify('cncspt | Welcome ' .. LocalPlayer.Name .. '!', 5)
        Tabs = {
            Combat   = Window:AddTab('Combat'),
            Visuals  = Window:AddTab('Visuals'),
            Player   = Window:AddTab('Player'),
            Misc     = Window:AddTab('Misc'),
            Settings = Window:AddTab('Settings'),
        }
        Toggles = _G.Toggles or getgenv().Toggles or Toggles
        Options = _G.Options or getgenv().Options or Options
    end
end

--// Sense ESP
if Sense and Sense.Load and not Sense.__loaded then
    local ok = pcall(function() Sense:Load() end)
    if ok then Sense.__loaded = true end
end

--// Cursor defaults guard
if Cursor then
    Cursor.enabled = (Cursor.enabled ~= false)
    Cursor.color = Cursor.color or ACCENT
    Cursor.length = Cursor.length or 20
    Cursor.radius = Cursor.radius or 15
    Cursor.spin = Cursor.spin or false
    Cursor.spinSpeed = Cursor.spinSpeed or 60
    Cursor.resize = Cursor.resize or false
    Cursor.resizeSpeed = Cursor.resizeSpeed or 10
    Cursor.sticky = Cursor.sticky or false
    Cursor.mode = Cursor.mode or "Middle"
end

--// UI: Watermark + title button
do
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    Main.BackgroundTransparency = 1
    Main.Size = UDim2.new(0, 120, 0, 50)
    Main.Position = UDim2.new(1, -130, 0, -50)
    Main.Parent = ScreenGui

    local Button = Instance.new("TextButton")
    Button.Name = "Toggle"
    Button.Text = "Cncspt"
    Button.TextWrapped = true
    Button.TextSize = 20
    Button.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.BackgroundColor3 = ACCENT
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
        ColorSequenceKeypoint.new(0, ACCENT),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 40, 150))
    })
    UIGradient.Rotation = 90
    UIGradient.Parent = Button

    local hoverTI   = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    Button.MouseEnter:Connect(function()
        TweenService:Create(Button, hoverTI, { BackgroundColor3 = Color3.fromRGB(120, 90, 220), BackgroundTransparency = 0.3 }):Play()
    end)
    Button.MouseLeave:Connect(function()
        TweenService:Create(Button, hoverTI, { BackgroundColor3 = ACCENT, BackgroundTransparency = 0.5 }):Play()
    end)
    Button.MouseButton1Down:Connect(function()
        if Library and Library.Toggle then
            task.spawn(Library.Toggle)
            task.wait(0.7)
            if Window and Window.Holder then
                Window.Holder.Position = UDim2.fromScale(0.5, 0.5)
            end
        end
    end)
end

--// Tabs and controls (only if UI loaded)
if Tabs then
    local CombatLG = Tabs.Combat:AddLeftGroupbox('Aimbot')
    local SoundLG  = Tabs.Combat:AddLeftGroupbox('Sound')
    local EspLG    = Tabs.Visuals:AddLeftGroupbox('Esp')
    local PVisuals = Tabs.Visuals:AddRightGroupbox('Self Visuals')
    local AimVLG   = Tabs.Visuals:AddLeftGroupbox("Aimbot Visuals")
    local CursorLG = Tabs.Visuals:AddRightGroupbox('Crosshair')
    local PlayerLG = Tabs.Player:AddLeftGroupbox('Movement')
    local PFovLG   = Tabs.Player:AddRightGroupbox('Camera')
    local CncsptLG = Tabs.Misc:AddLeftGroupbox('Cncspt')
    local SMiscRG  = Tabs.Misc:AddRightGroupbox('Server')
    local ScMiscRG = Tabs.Misc:AddRightGroupbox('Scripts')

    -- Cncspt controls
    CncsptLG:AddToggle('CncsptWatermark', {
        Text = 'Watermark',
        Default = true,
        Tooltip = 'Enables Watermark/Stats',
        Callback = function(v)
            WatermarkVisible = v
            if Library then Library:SetWatermarkVisibility(v) end
        end
    })

    CncsptLG:AddToggle('CncsptKeybindMenu', {
        Text = 'Keybind Menu',
        Default = false,
        Tooltip = 'Enables Keybinds Menu!',
        Callback = function(v)
            if Library and Library.KeybindFrame then
                Library.KeybindFrame.Visible = v
            end
        end
    })

    CncsptLG:AddButton("Unlock/Uncap Fps", function()
        setfpscap(0)
    end)

    -- Server
    SMiscRG:AddButton('Rejoin Server', function()
        notify('Rejoining current server...', 3)
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)

    SMiscRG:AddButton('Server Hop', function()
        notify('Searching for another server...', 5)
        local ok, res = pcall(function()
            local s = safeHttpGet(string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", game.PlaceId))
            return s and HttpService:JSONDecode(s) or nil
        end)
        if ok and res and res.data then
            for _, server in ipairs(res.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    notify('Joining a new server...', 3)
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                    return
                end
            end
            notify('No other servers found.', 3)
        else
            notify('Failed to fetch server list.', 5)
        end
    end)

    -- Scripts
    local ddLoaded, iyLoaded = false, false
    ScMiscRG:AddButton('Execute Dex Debugger', function()
        if ddLoaded then return notify('Dex Debugger already executed!', 3) end
        ddLoaded = true
        notify('Executing Dex Debugger', 3)
        safeLoad('https://gitlab.com/Wooffles/cncspt.lol/-/raw/main/Lib/Dex.Lua')
        notify('Executed!', 3)
    end)

    ScMiscRG:AddButton('Execute Infinite Yield', function()
        if iyLoaded then return notify('Infinite Yield already executed!', 3) end
        iyLoaded = true
        notify('Executing Infinite Yield', 3)
        safeLoad('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source')
        notify('Executed!', 3)
    end)

    ScMiscRG:AddButton("Test Executor's UNC", function()
        notify("Testing " .. Executor .. "'s UNC...", 3)
        safeLoad("https://pastebin.com/raw/1cjxTJWt")
    end)

    -- Combat
    CombatLG:AddToggle('AimbotEnabled', {
        Text = 'Enabled',
        Default = false,
        Tooltip = 'Enables Aimbot!',
        Callback = function(v)
            Config.Aimbot.Enabled = v
            if TargetIndicator then TargetIndicator.Visible = v end
        end
    })
    CombatLG:AddDropdown("AimbotType", {
        Text = "Type",
        Values = {"Aimbot"}, --, "ClientSilent"
        Default = "Aimbot",
        Callback = function(v) Config.Aimbot.Type = v end
    })
    CombatLG:AddDropdown("AimbotTargetPart", {
        Text = "Target Part",
        Values = bodyParts,
        Default = Config.Aimbot.TargetPart,
        Callback = function(v)
            Config.Aimbot.TargetPart = v
        end
    })
    CombatLG:AddSlider('AimbotRadius', {
        Text = 'Radius',
        Default = Config.Aimbot.Radius, Min = 0, Max = 300, Rounding = 0,
        Callback = function(v) Config.Aimbot.Radius = v end
    })
    CombatLG:AddSlider('AimbotSmoothness', {
        Text = 'Smoothness',
        Default = Config.Aimbot.Smoothness, Min = 0, Max = 1, Rounding = 2,
        Callback = function(v) Config.Aimbot.Smoothness = v end
    })
    CombatLG:AddSlider('AimbotPrediction', {
        Text = 'Prediction',
        Default = Config.Aimbot.Prediction, Min = 0, Max = 5, Rounding = 3,
        Callback = function(v) Config.Aimbot.Prediction = v end
    })
    CombatLG:AddToggle('AimbotTeamCheck', {
        Text = 'Team Check',
        Default = Config.Aimbot.TeamCheck,
        Callback = function(v) Config.Aimbot.TeamCheck = v end
    })
    CombatLG:AddToggle('AimbotWallCheck', {
        Text = 'Wall Check',
        Default = Config.Aimbot.WallCheck,
        Callback = function(v) Config.Aimbot.WallCheck = v end
    })
    CombatLG:AddToggle('AimbotAutoPrediction', {
        Text = 'Auto Prediction',
        Default = Config.Aimbot.AutoPrediction,
        Callback = function(v) Config.Aimbot.AutoPrediction = v end
    })
    CombatLG:AddSlider('AimbotOffsetX', {
        Text = 'Horizontal Offset',
        Default = Config.Aimbot.Offset.X, Min = -50, Max = 50, Rounding = 1,
        Callback = function(v) Config.Aimbot.Offset.X = v end
    })
    CombatLG:AddSlider('AimbotOffsetY', {
        Text = 'Vertical Offset',
        Default = Config.Aimbot.Offset.Y, Min = -50, Max = 50, Rounding = 1,
        Callback = function(v) Config.Aimbot.Offset.Y = v end
    })

    SoundLG:AddButton('Play Hit Sound', playHitSound)

    -- ESP
    if Sense and Sense.teamSettings and Sense.sharedSettings then
        EspLG:AddToggle('EspEnemy', {
            Text = 'Enable', Default = false, Tooltip = 'Enemy Esp Master Toggle',
            Callback = function(v) Sense.teamSettings.enemy.enabled = v end
        })
        -- EspLG:AddToggle('EspEnemyBox', {
        --     Text = 'Box 2D', Default = false,
        --     Callback = function(v) Sense.teamSettings.enemy.box = v end
        -- })
        EspLG:AddToggle('EspEnemyBox3d', {
            Text = 'Box 3D', Default = false,
            Callback = function(v) Sense.teamSettings.enemy.box3d = v end
        })
        -- EspLG:AddLabel('Box Color'):AddColorPicker('EspEnemyBoxColor', {
        --     Text = 'Box Color', Default = Color3.fromRGB(255,255,255),
        --     Callback = function(v) Sense.teamSettings.enemy.boxColor = v end
        -- })
        -- EspLG:AddSlider('EspEnemyBoxThickness', {
        --     Text = 'Box Thickness', Default = 1, Min = 1, Max = 5, Rounding = 0,
        --     Callback = function(v) Sense.teamSettings.enemy.boxThickness = v end
        -- })
        -- EspLG:AddToggle('EspEnemyBoxOutline', {
        --     Text = 'Box Outline', Default = true,
        --     Callback = function(v) Sense.teamSettings.enemy.boxOutline = v end
        -- })

        EspLG:AddToggle('EspEnemyName', {
            Text = 'Name', Default = false,
            Callback = function(v) Sense.teamSettings.enemy.name = v end
        })
        -- EspLG:AddLabel('Name Color'):AddColorPicker('EspEnemyNameColor', {
        --     Text = 'Name Color', Default = Color3.fromRGB(255,255,255),
        --     Callback = function(v) Sense.teamSettings.enemy.textColor = v end
        -- })

        EspLG:AddToggle('EspEnemyHealthBar', {
            Text = 'Health Bar', Default = false,
            Callback = function(v) Sense.teamSettings.enemy.healthBar = v end
        })
        EspLG:AddToggle('EspEnemyHealthText', {
            Text = 'Health Text', Default = false,
            Callback = function(v) Sense.teamSettings.enemy.healthText = v end
        })
        -- EspLG:AddLabel('Health Color'):AddColorPicker('EspEnemyHealthColor', {
        --     Text = 'Health Color', Default = Color3.fromRGB(0,255,0),
        --     Callback = function(v) Sense.teamSettings.enemy.healthColor = v end
        -- })

        -- EspLG:AddToggle('EspEnemyTracer', {
        --     Text = 'Tracers', Default = false,
        --     Callback = function(v) Sense.teamSettings.enemy.tracer = v end
        -- })
        -- EspLG:AddLabel('Tracer Color'):AddColorPicker('EspEnemyTracerColor', {
        --     Text = 'Tracer Color', Default = Color3.fromRGB(255,255,255),
        --     Callback = function(v) Sense.teamSettings.enemy.tracerColor = v end
        -- })
        -- EspLG:AddDropdown('EspEnemyTracerOrigin', {
        --     Text = 'Tracer Origin', Values = {'Bottom','Middle','Top'}, Default = 'Bottom',
        --     Callback = function(v) Sense.teamSettings.enemy.tracerOrigin = v end
        -- })
        -- Enemy Chams
        EspLG:AddToggle('EspEnemyChams', {
            Text = 'Chams', Default = false,
            Callback = function(v) Sense.teamSettings.enemy.chams = v end
        })
        EspLG:AddToggle('EspEnemyChamsVisible', {
            Text = 'Chams Visible Check', Default = false,
            Callback = function(v) Sense.teamSettings.enemy.chamsVisibleOnly = v end
        })
        EspLG:AddToggle('EspEmemyWeapon', {
            Text = 'Weapon/Tool', Default = false,
            Callback = function(v) Sense.teamSettings.enemy.weapon = v end
        })
        -- EspLG:AddLabel('Chams Color'):AddColorPicker('EspEnemyChamsColor', {
        --     Text = 'Chams Color', Default = Color3.fromRGB(255,0,0),
        --     Callback = function(v) Sense.teamSettings.enemy.chamsColor = v end
        -- })
        -- EspLG:AddSlider('EspEnemyChamsTransparency', {
        --     Text = 'Chams Transparency', Default = 0.25, Min = 0, Max = 1, Rounding = 2,
        --     Callback = function(v) Sense.teamSettings.enemy.chamsTransparency = v end
        -- })

        -------------------------------------------------------------------
        local EspAllyLG = Tabs.Visuals:AddRightGroupbox('Esp Ally')

        EspAllyLG:AddToggle('EspAlly', {
            Text = 'Enable', Default = false, Tooltip = 'Ally Esp Master Toggle',
            Callback = function(v) Sense.teamSettings.friendly.enabled = v end
        })
        EspAllyLG:AddToggle('EspAllyBox', {
            Text = 'Box 2D', Default = false,
            Callback = function(v) Sense.teamSettings.friendly.box = v end
        })
        EspAllyLG:AddLabel('Box Color'):AddColorPicker('EspAllyBoxColor', {
            Text = 'Box Color', Default = Color3.fromRGB(80,200,255),
            Callback = function(v) Sense.teamSettings.friendly.boxColor = v end
        })
        EspAllyLG:AddSlider('EspAllyBoxThickness', {
            Text = 'Box Thickness', Default = 1, Min = 1, Max = 5, Rounding = 0,
            Callback = function(v) Sense.teamSettings.friendly.boxThickness = v end
        })
        EspAllyLG:AddToggle('EspAllyBoxOutline', {
            Text = 'Box Outline', Default = true,
            Callback = function(v) Sense.teamSettings.friendly.boxOutline = v end
        })

        EspAllyLG:AddToggle('EspAllyName', {
            Text = 'Name', Default = false,
            Callback = function(v) Sense.teamSettings.friendly.name = v end
        })
        EspAllyLG:AddLabel('Name Color'):AddColorPicker('EspAllyNameColor', {
            Text = 'Name Color', Default = Color3.fromRGB(255,255,255),
            Callback = function(v) Sense.teamSettings.friendly.textColor = v end
        })

        EspAllyLG:AddToggle('EspAllyHealthBar', {
            Text = 'Health Bar', Default = false,
            Callback = function(v) Sense.teamSettings.friendly.healthBar = v end
        })
        EspAllyLG:AddToggle('EspAllyHealthText', {
            Text = 'Health Text', Default = false,
            Callback = function(v) Sense.teamSettings.friendly.healthText = v end
        })
        EspAllyLG:AddLabel('Health Color'):AddColorPicker('EspAllyHealthColor', {
            Text = 'Health Color', Default = Color3.fromRGB(0,255,0),
            Callback = function(v) Sense.teamSettings.friendly.healthColor = v end
        })

        EspAllyLG:AddToggle('EspAllyTracer', {
            Text = 'Tracers', Default = false,
            Callback = function(v) Sense.teamSettings.friendly.tracer = v end
        })
        EspAllyLG:AddLabel('Tracer Color'):AddColorPicker('EspAllyTracerColor', {
            Text = 'Tracer Color', Default = Color3.fromRGB(255,255,255),
            Callback = function(v) Sense.teamSettings.friendly.tracerColor = v end
        })
        EspAllyLG:AddDropdown('EspAllyTracerOrigin', {
            Text = 'Tracer Origin', Values = {'Bottom','Middle','Top'}, Default = 'Bottom',
            Callback = function(v) Sense.teamSettings.friendly.tracerOrigin = v end
        })
        EspAllyLG:AddToggle('EspAllyChams', {
            Text = 'Chams', Default = false,
            Callback = function(v) Sense.teamSettings.friendly.chams = v end
        })
        EspAllyLG:AddToggle('EspAllyChamsVisible', {
            Text = 'Chams Visible Check', Default = false,
            Callback = function(v) Sense.teamSettings.friendly.chamsVisibleOnly = v end
        })
        EspAllyLG:AddLabel('Chams Color'):AddColorPicker('EspAllyChamsColor', {
            Text = 'Chams Color', Default = Color3.fromRGB(0,170,255),
            Callback = function(v) Sense.teamSettings.friendly.chamsColor = v end
        })
        EspAllyLG:AddSlider('EspAllyChamsTransparency', {
            Text = 'Chams Transparency', Default = 0.25, Min = 0, Max = 1, Rounding = 2,
            Callback = function(v) Sense.teamSettings.friendly.chamsTransparency = v end
        })
        -- EspLG:AddToggle('EspEnemy', {
        --     Text = 'Enable', Default = false, Tooltip = 'Enemy Esp Master Toggle',
        --     Callback = function(v) Sense.teamSettings.enemy.enabled = v end
        -- })
        -- EspLG:AddToggle('EspEnemyBox', {
        --     Text = 'Box 2D', Default = false, Tooltip = '2D Box Around the Enemy',
        --     Callback = function(v) Sense.teamSettings.enemy.box = v end
        -- })
        -- EspLG:AddToggle('EspEnemyName', {
        --     Text = 'Name', Default = false,
        --     Callback = function(v) Sense.teamSettings.enemy.name = v end
        -- })
        -- EspLG:AddToggle('EspEnemyHealthBar', {
        --     Text = 'Health Bar', Default = false,
        --     Callback = function(v) Sense.teamSettings.enemy.healthBar = v end
        -- })
        -- EspLG:AddToggle('EspEnemyHealthText', {
        --     Text = 'Health Text', Default = false,
        --     Callback = function(v) Sense.teamSettings.enemy.healthText = v end
        -- })
        -- EspLG:AddSlider('EspTextSize', {
        --     Text = 'Text Size', Default = 10, Min = 0, Max = 20, Rounding = 0,
        --     Callback = function(v) Sense.sharedSettings.textSize = v end
        -- })
    end

    -- Aimbot visuals
    AimVLG:AddLabel('Fov Color'):AddColorPicker("AimbotRadiusColor", {
        Text = "Color", Default = Config.Aimbot.FovColor,
        Callback = function(v) Config.Aimbot.FovColor = v end
    })
    AimVLG:AddToggle('AimbotFovVisible', {
        Text = 'Fov Visible', Default = true,
        Callback = function(v) Config.Aimbot.FovVisible = v end
    })
    AimVLG:AddToggle('AimbotFovFilled', {
        Text = 'Fov Filled', Default = false,
        Callback = function(v) Config.Aimbot.FovFilled = v end
    })
    AimVLG:AddToggle('TargetIndicatorToggle', {
        Text = 'Target Indicator',
        Default = TargetIndicator and TargetIndicator.Visible or false,
        Callback = function(v)
            if TargetIndicator then
                TargetIndicator.Visible = v
            end
        end
    })
    AimVLG:AddToggle('PredictionDotToggle', {
        Text = 'Prediction Dot',
        Default = PredictionDot and PredictionDot.Visible or false,
        Callback = function(v)
            if PredictionDot then
                PredictionDot.Visible = v
            end
        end
    })

    -- Self visuals
    PVisuals:AddToggle("FFBodyEnabled", {
        Text = "Forcefield Body",
        Default = Config.Chams.FFBodyEnabled,
        Callback = function(v) Config.Chams.FFBodyEnabled = v; applyFFBody() end
    })
    local FFBDepbox = PVisuals:AddDependencyBox()
    FFBDepbox:AddLabel('Body Color'):AddColorPicker("FFBodyColor", {
        Text = "Color", Default = Config.Chams.FFBodyColor,
        Callback = function(v) Config.Chams.FFBodyColor = v; applyFFBody() end
    })

    PVisuals:AddToggle("FFToolsEnabled", {
        Text = "Forcefield Tools",
        Default = Config.Chams.FFToolsEnabled,
        Callback = function(v) Config.Chams.FFToolsEnabled = v; applyFFTools() end
    })
    local FFTDepbox = PVisuals:AddDependencyBox()
    FFTDepbox:AddLabel('Tools Color'):AddColorPicker("FFToolsColor", {
        Text = "Color", Default = Config.Chams.FFToolsColor,
        Callback = function(v) Config.Chams.FFToolsColor = v; applyFFTools() end
    })

    PVisuals:AddToggle("FFHatsEnabled", {
        Text = "Forcefield Hats",
        Default = Config.Chams.FFHatsEnabled,
        Callback = function(v) Config.Chams.FFHatsEnabled = v; applyFFHats() end
    })
    local FFHDepbox = PVisuals:AddDependencyBox()
    FFHDepbox:AddLabel('Hats Color'):AddColorPicker("FFHatsColor", {
        Text = "Color", Default = Config.Chams.FFHatsColor,
        Callback = function(v) Config.Chams.FFHatsColor = v; applyFFHats() end
    })

    PVisuals:AddToggle("AuraEnabled", {
        Text = "Aura", Default = Config.Aura.Enabled,
        Callback = function(v) Config.Aura.Enabled = v; setupParticles() end
    })
    PVisuals:AddDropdown("AuraType", {
        Text = "Aura Type", Values = {"Heal", "Swirl"}, Default = "Heal",
        Callback = function(v) Config.Aura.Type = v; setupParticles() end
    })

    -- Crosshair
    if Cursor then
        CursorLG:AddToggle("CrosshairShow", {
            Text = "Enabled", Default = Cursor.enabled,
            Callback = function(v) Cursor.enabled = v end
        })
        CursorLG:AddLabel('Color'):AddColorPicker("CrosshairColor", {
            Text = "Cursor Color", Default = Cursor.color,
            Callback = function(v) Cursor.color = v end
        })
        CursorLG:AddDropdown("CrosshairMode", {
            Text = "Type", Default = "Middle", Values = {"Mouse", "Middle"},
            Callback = function(v) crosshair_position = v end
        })
        CursorLG:AddToggle("CrosshairStick", {
            Text = "Stick", Default = Cursor.sticky,
            Callback = function(v) Cursor.sticky = v end
        })
        CursorLG:AddSlider("CrosshairSize", {
            Text = "Size", Default = Cursor.length, Min = 10, Max = 50, Rounding = 0,
            Callback = function(v) Cursor.length = v end
        })
        CursorLG:AddSlider("CrosshairGap", {
            Text = "Gap", Default = Cursor.radius, Min = 10, Max = 50, Rounding = 0,
            Callback = function(v) Cursor.radius = v end
        })
        CursorLG:AddToggle("CrosshairSpin", {
            Text = "Spinning", Default = Cursor.spin,
            Callback = function(v) Cursor.spin = v end
        })
        CursorLG:AddSlider("CrosshairSpinSpeed", {
            Text = "Spinning Speed", Default = Cursor.spinSpeed, Min = 1, Max = 340, Rounding = 0,
            Callback = function(v) Cursor.spinSpeed = v end
        })
        CursorLG:AddToggle("CrosshairResize", {
            Text = "Resize", Default = Cursor.resize,
            Callback = function(v) Cursor.resize = v end
        })
        CursorLG:AddSlider("CrosshairResizeSpeed", {
            Text = "Resize Speed", Default = Cursor.resizeSpeed, Min = 1, Max = 40, Rounding = 0,
            Callback = function(v) Cursor.resizeSpeed = v end
        })
    end

    -- Movement
    PlayerLG:AddToggle("CFrameSpeedEnabled", {
        Text = "Enabled", Default = Config.CFrameSpeed.Enabled,
        Callback = function(v) Config.CFrameSpeed.Enabled = v end
    })
    PlayerLG:AddLabel('Keybind'):AddKeyPicker("CFrameSpeedKeybind", {
        Default = "V", SyncToggleState = true, Mode = "Toggle", Text = "CFrame Speed", NoUI = false,
        Callback = function(v) Config.CFrameSpeed.Enabled = v end
    })
    PlayerLG:AddSlider("CFrameSpeed", {
        Text = "Speed", Default = Config.CFrameSpeed.Speed, Min = 0.1, Max = 10, Rounding = 1,
        Callback = function(v) Config.CFrameSpeed.Speed = v end
    })
    PlayerLG:AddToggle("CFrameControllerShortcut", {
        Text = "Controller Shortcut", Default = Config.CFrameSpeed.ControllerShortcut,
        Callback = function(v) Config.CFrameSpeed.ControllerShortcut = v end
    })
    PlayerLG:AddDropdown("CFrameControllerBind", {
        Text = "Controller Button", Values = ControllerBinds, Default = Config.CFrameSpeed.ControllerBind,
        Callback = function(v) Config.CFrameSpeed.ControllerBind = v end
    })

    -- -- Camera
    -- PFovLG:AddSlider('CameraFov', {
    --     Text = 'Fov', Default = Config.CameraFov.DefaultFOV, Min = 0, Max = 200, Rounding = 0,
    --     Callback = function(v) Camera.FieldOfView = v; Config.CameraFov.Fov = v end
    -- })
    -- PFovLG:AddButton('Reset Camera Fov', function()
    --     if Camera.FieldOfView ~= Config.CameraFov.DefaultFOV then
    --         Camera.FieldOfView = Config.CameraFov.DefaultFOV
    --         if Options and Options.CameraFov and Options.CameraFov.SetValue then
    --             Options.CameraFov:SetValue(Config.CameraFov.DefaultFOV)
    --         end
    --         notify(('FOV reset to default (%d)'):format(Config.CameraFov.DefaultFOV), 3)
    --     end
    -- end)
    -- PFovLG:AddToggle('KeepCameraFov', {
    --     Text = 'Keep Camera Fov', Default = false,
    --     Callback = function(v)
    --         Config.CameraFov.KeepFov = v
    --         if keepFovConn then keepFovConn:Disconnect() keepFovConn = nil end
    --         if v and Config.CameraFov.Fov then
    --             keepFovConn = RunService.RenderStepped:Connect(function()
    --                 Camera.FieldOfView = Config.CameraFov.Fov
    --             end)
    --         end
    --     end
    -- })

--     -- Quick Speed Button (uses existing ScreenGui)
--     PlayerLG:AddButton("Load Button", function()
--         if SBLoaded then return print('Speed Button already loaded!') end
--         SBLoaded = true

--         local sMain = Instance.new("Frame")
--         sMain.Name = "Main"
--         sMain.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
--         sMain.BackgroundTransparency = 1
--         sMain.Size = UDim2.new(0, 120, 0, 50)
--         sMain.Position = UDim2.new(1, -130, 0, 0)
--         sMain.Parent = ScreenGui

--         local sButton = Instance.new("TextButton")
--         sButton.Name = "Toggle"
--         sButton.Text = "Speed"
--         sButton.TextWrapped = true
--         sButton.TextSize = 20
--         sButton.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
--         sButton.TextColor3 = Color3.fromRGB(255, 255, 255)
--         sButton.BackgroundColor3 = ACCENT
--         sButton.BackgroundTransparency = 0.5
--         sButton.Size = UDim2.new(1, -10, 1, -10)
--         sButton.Position = UDim2.new(0, 5, 0, 5)
--         sButton.AutoButtonColor = false
--         sButton.Draggable = true
--         sButton.Parent = sMain

--         local sButtonCorner = Instance.new("UICorner")
--         sButtonCorner.CornerRadius = UDim.new(0, 6)
--         sButtonCorner.Parent = sButton

--         local sButtonStroke = Instance.new("UIStroke")
--         sButtonStroke.Color = Color3.fromRGB(80, 80, 80)
--         sButtonStroke.Thickness = 1
--         sButtonStroke.Parent = sButton

--         local sUIGradient = Instance.new("UIGradient")
--         sUIGradient.Color = ColorSequence.new({
--             ColorSequenceKeypoint.new(0, ACCENT),
--             ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 40, 150))
--         })
--         sUIGradient.Rotation = 90
--         sUIGradient.Parent = sButton

--         local hoverTI = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
--         sButton.MouseButton1Down:Connect(function()
--             Config.CFrameSpeed.Enabled = not Config.CFrameSpeed.Enabled
--             local col = Config.CFrameSpeed.Enabled and Color3.fromRGB(85, 255, 85) or ACCENT
--             TweenService:Create(sButton, hoverTI, { BackgroundColor3 = col, BackgroundTransparency = 0.5 }):Play()
--         end)
--     end)

--     -- Dependencies
--     if FFBDepbox and Toggles and Toggles.FFBodyEnabled then
--         FFBDepbox:SetupDependencies({ { Toggles.FFBodyEnabled, true } })
--     end
--     if FFHDepbox and Toggles and Toggles.FFHatsEnabled then
--         FFHDepbox:SetupDependencies({ { Toggles.FFHatsEnabled, true } })
--     end
--     if FFTDepbox and Toggles and Toggles.FFToolsEnabled then
--         FFTDepbox:SetupDependencies({ { Toggles.FFToolsEnabled, true } })
--     end
-- end

-- --// Options Accent lock to ACCENT (if present)
-- RunService.RenderStepped:Connect(function()
--     if Library and Library.Watermark then
--         Library.Watermark.Position = UDim2.new(0, 0, 0, 5)
--     end
--     if Options and Options.AccentColor and Options.AccentColor.Value and Options.AccentColor.SetValueRGB then
--         if Options.AccentColor.Value ~= ACCENT then
--             Options.AccentColor:SetValueRGB(ACCENT)
--         end
--     end
-- end)

-- --// Controller toggle for CFrame speed
-- UserInputService.InputBegan:Connect(function(input, gameProcessed)
--     if gameProcessed then return end
--     if input.UserInputType == Enum.UserInputType.Gamepad1 and Config.CFrameSpeed.ControllerShortcut then
--         if input.KeyCode == Enum.KeyCode[Config.CFrameSpeed.ControllerBind] then
--             Config.CFrameSpeed.ControllerValue = not Config.CFrameSpeed.ControllerValue
--             Config.CFrameSpeed.Enabled = Config.CFrameSpeed.ControllerValue
--         end
--     end
-- end)

-- --// Welcome notification
-- StarterGui:SetCore("SendNotification", {
--     Title = "Cncspt",
--     Text = "Welcome, " .. LPDisplayName,
--     Icon = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=180&h=180 true",
--     Duration = 3
-- })

--// Theme/Save managers
if ThemeManager and SaveManager and Library then
    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({})
    ThemeManager:SetFolder('VenexThemes')
    SaveManager:SetFolder('VenexConfigs')
    SaveManager:BuildConfigSection(Tabs and Tabs.Settings or nil)
    ThemeManager:ApplyToTab(Tabs and Tabs.Settings or nil)
    SaveManager:LoadAutoloadConfig()
end

--// Main consolidated loop
RunService.RenderStepped:Connect(function(dt)
    -- Keep ScreenCenter accurate if viewport changes
    local vp = Camera.ViewportSize
    ScreenCenter = Vector2.new(vp.X/2, vp.Y/2)

    -- Aimbot
    local closest = nil
    if Config.Aimbot.Enabled then
        closest = getClosestTarget()
        if closest and closest.Character then
            local part = closest.Character:FindFirstChild(Config.Aimbot.TargetPart)
            if part then
                if Config.Aimbot.Type == "Aimbot" then
                    visualAimbot(part)
                elseif Config.Aimbot.Type == "ClientSilent" then
                    -- client-only fake aim; reserved for integrations
                    -- cf = aimCFrameFor(part) -- compute if needed
                end
            end
        end
        updateFovDrawing()
    end
    if closest ~= aimbotTargetCache then
        aimbotTargetCache = closest
    end
    updateTargetIndicator(closest)

    -- Movement CFrame speed
    if Config.CFrameSpeed.Enabled then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hum and hrp then
            local dir = hum.MoveDirection
            if dir.Magnitude > 0 then
                -- dt-aware movement for smoother motion
                hrp.CFrame = hrp.CFrame + (dir * Config.CFrameSpeed.Speed)
            end
        end
    end

    -- Watermark (update fps once per second)
    fpsCounter.frames += 1
    local now = tick()
    if now - fpsCounter.t0 >= 1 then
        fpsCounter.fps = fpsCounter.frames
        fpsCounter.frames = 0
        fpsCounter.t0 = now
        if WatermarkVisible and Library and Library.SetWatermark then
            local ping = Stats.Network.ServerStatsItem['Data Ping']
            local ms = ping and round(ping:GetValue()) or 0
            Library:SetWatermark(('[Venex Beta] | %s fps | %s ms | %s'):format(
                fpsCounter.fps, ms, LocalPlayer.Name
            ))
        end
    end
end)

notify('[Venex] Info : Executed!', 5)
