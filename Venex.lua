if _G.VantageExecuted then
    return warn("[Vantage] Error : Already Loaded!")
end

local function HttpGet(url)
    local ok, res = pcall(game.HttpGet, game, url)
    if ok then return res end
    warn("[Vantage] Error : HttpGet failed:", url, res)
    return nil
end

local function Load(url)
    local src = HttpGet(url)
    if not src then return nil end
    local ok, fn = pcall(loadstring, src)
    if ok and type(fn) == "function" then
        local success, lib = pcall(fn)
        if success then return lib end
        warn("[Vantage] Error : loadstring run failed:", url, lib)
    else
        warn("[Vantage] Error : loadstring compile failed:", url, fn)
    end
    return nil
end

local Players             = game:GetService("Players")
local TeleportService     = game:GetService("TeleportService")
local TweenService        = game:GetService("TweenService")
local UserInputService    = game:GetService("UserInputService")
local RunService          = game:GetService("RunService")
local HttpService         = game:GetService("HttpService")
local Lighting            = game:GetService("Lighting")
local LocalPlayer         = Players.LocalPlayer
local Mouse               = LocalPlayer:GetMouse()
local Camera              = workspace.CurrentCamera

local syde         = Load("https://raw.githubusercontent.com/TheWooffles/syde/main/source",true)
local VenexEsp     = Load('https://raw.githubusercontent.com/TheWooffles/Venex/main/Libraries/VenexESP/Venex.lua')

local Config = {
    CFrameSpeed = {
        Enabled = false,
        Speed = 1,
    },
    TriggerBot = {
        Enabled = false,
        Delay = 0,
        TeamCheck = true,
        WallCheck = true,
        HitChance = 100,
        AutoShoot = true,
    },
    World = {
        Fullbright = false,
        NoShadows = false,
        NoTextures = false,
        OriginalLighting = {},
    }
}

syde:Load({
	Logo = '7488932274',
	Name = 'Vantage Internal',
	Status = 'Stable',
	Accent = Color3.fromRGB(255, 255, 255),
	HitBox = Color3.fromRGB(255, 0, 0),
	AutoLoad = false,
	Socials = {
		{
			Name = 'Syde';
			Style = 'Discord';
			Size = "Large";
			CopyToClip = false
		},
		{
			Name = 'GitHub';
			Style = 'GitHub';
			Size = "Small";
			CopyToClip = false
		}
	},
	ConfigurationSaving = {
		Enabled = true,
		FolderName = 'Vantage',
		FileName = "Config"
	},
	AutoJoinDiscord = { 
		Enabled = false,
		Invite = "CZRZBwPz",
		RememberJoins = false
	},
})

local Window = syde:Init({
	Title = 'Vantage Internal';
	SubText = 'Made With 💓 By @Cncspt'
})

local Combat  = Window:InitTab({ Title = 'Combat' })
local Visuals = Window:InitTab({ Title = 'Visuals' })
local Player  = Window:InitTab({ Title = 'Player' })
local World   = Window:InitTab({ Title = 'World' })
local Misc    = Window:InitTab({ Title = 'Misc' })

-- Enhanced AimLock Configuration
_G.AimLock = _G.AimLock or {
    Enabled = false,
    FOVEnabled = false,
    TargetPlayer = nil,
    
    -- Smoothness Settings
    Smoothness = 0.2,
    SmoothingStyle = "Exponential", -- Linear, Exponential, Sine, Bezier
    AdaptiveSmoothing = true, -- Adjust smoothness based on distance
    
    -- Prediction Settings
    PredictionEnabled = true,
    PredictionStrength = 0.133,
    UseVelocity = true,
    UseAcceleration = false,
    AutoPrediction = false, -- Auto-adjust based on ping
    HorizontalPredictionOnly = false,
    
    -- Target Part Settings
    TargetPart = "Head", -- Head, HumanoidRootPart, UpperTorso, Auto
    HitChance = 100, -- Percentage to aim at head vs body
    SmartPartSelection = false, -- Use distance-based part selection
    
    -- FOV Settings
    FOVSize = 100,
    FOVColor = Color3.fromRGB(255, 255, 255),
    FOVTransparency = 0.5,
    FOVFilled = false,
    
    -- Checks
    WallCheck = true,
    TeamCheck = true,
    KnockedCheck = true,
    
    -- Advanced
    StickyLock = false, -- Keep locked until target dies or out of FOV
    MaxLockDistance = 500,
    AutoUnlock = true,
    ShakeReduction = 0, -- 0-100, reduces camera shake
    
    Keybind = Enum.KeyCode.Q,
}

local targetPlayer = nil
local connections = {}
local FOVCircle = nil
local lastTargetVelocity = Vector3.zero
local lastTargetPosition = Vector3.zero
local targetAcceleration = Vector3.zero
local pingEstimate = 0

-- Smoothing Functions
local SmoothingFunctions = {
    Linear = function(delta, smoothness)
        return delta * smoothness
    end,
    
    Exponential = function(delta, smoothness)
        return delta * (1 - math.exp(-smoothness * 10))
    end,
    
    Sine = function(delta, smoothness)
        local t = math.sin((smoothness * math.pi) / 2)
        return delta * t
    end,
    
    Bezier = function(delta, smoothness)
        local t = smoothness
        local bezier = 3 * t^2 - 2 * t^3
        return delta * bezier
    end
}

local function CreateFOVCircle()
    if FOVCircle then
        FOVCircle:Remove()
    end
    
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = 2
    FOVCircle.NumSides = 64
    FOVCircle.Radius = _G.AimLock.FOVSize
    FOVCircle.Color = _G.AimLock.FOVColor
    FOVCircle.Transparency = _G.AimLock.FOVTransparency
    FOVCircle.Filled = _G.AimLock.FOVFilled
    FOVCircle.Visible = false
    FOVCircle.ZIndex = 1000
end

CreateFOVCircle()

local function UpdateFOVCircle()
    if FOVCircle and _G.AimLock.FOVEnabled then
        FOVCircle.Position = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
        FOVCircle.Radius = _G.AimLock.FOVSize
        FOVCircle.Color = _G.AimLock.FOVColor
        FOVCircle.Transparency = _G.AimLock.FOVTransparency
        FOVCircle.Filled = _G.AimLock.FOVFilled
        FOVCircle.Visible = _G.AimLock.Enabled
    else
        if FOVCircle then
            FOVCircle.Visible = false
        end
    end
end

local function SaveOriginalLighting()
    Config.World.OriginalLighting = {
        Brightness = Lighting.Brightness,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        GlobalShadows = Lighting.GlobalShadows,
    }
end

SaveOriginalLighting()

local function ApplyFullbright(enabled)
    if enabled then
        Lighting.Brightness = 2
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.ClockTime = 12
        Lighting.FogEnd = 100000
    else
        Lighting.Brightness = Config.World.OriginalLighting.Brightness or 1
        Lighting.Ambient = Config.World.OriginalLighting.Ambient or Color3.fromRGB(0, 0, 0)
        Lighting.OutdoorAmbient = Config.World.OriginalLighting.OutdoorAmbient or Color3.fromRGB(0, 0, 0)
        Lighting.ClockTime = Config.World.OriginalLighting.ClockTime or 14
        Lighting.FogEnd = Config.World.OriginalLighting.FogEnd or 100000
    end
end

local function ApplyNoShadows(enabled)
    Lighting.GlobalShadows = not enabled
end

local function isPlayerAlive(player)
    if not player or not player.Character then return false end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    
    if _G.AimLock.KnockedCheck then
        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Dead or state == Enum.HumanoidStateType.Physics then
            return false
        end
    end
    
    return humanoid.Health > 0
end

local function GetPing()
    local stats = game:GetService("Stats")
    if stats and stats.Network and stats.Network.ServerStatsItem then
        local ping = stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        pingEstimate = ping / 1000
        return ping
    end
    return 0
end

local function CalculatePrediction(targetPart, targetCharacter)
    if not _G.AimLock.PredictionEnabled then
        return targetPart.Position
    end
    
    local hrp = targetCharacter:FindFirstChild("HumanoidRootPart")
    if not hrp then return targetPart.Position end
    
    local velocity = hrp.AssemblyLinearVelocity or hrp.Velocity or Vector3.zero
    local position = targetPart.Position
    
    -- Calculate acceleration if enabled
    if _G.AimLock.UseAcceleration then
        local currentVelocity = velocity
        local deltaTime = 0.016 -- Approximate frame time
        targetAcceleration = (currentVelocity - lastTargetVelocity) / deltaTime
        lastTargetVelocity = currentVelocity
    end
    
    -- Auto prediction based on ping
    local predictionAmount = _G.AimLock.PredictionStrength
    if _G.AimLock.AutoPrediction then
        GetPing()
        predictionAmount = pingEstimate + 0.03 -- Base latency + ping
    end
    
    -- Apply velocity prediction
    if _G.AimLock.UseVelocity then
        local predictedPosition = position + (velocity * predictionAmount)
        
        -- Apply acceleration if enabled
        if _G.AimLock.UseAcceleration then
            predictedPosition = predictedPosition + (targetAcceleration * predictionAmount * predictionAmount * 0.5)
        end
        
        -- Horizontal only prediction
        if _G.AimLock.HorizontalPredictionOnly then
            predictedPosition = Vector3.new(predictedPosition.X, position.Y, predictedPosition.Z)
        end
        
        return predictedPosition
    end
    
    return position
end

local function GetTargetPart(character, distance)
    -- Smart part selection based on distance
    if _G.AimLock.SmartPartSelection then
        if distance < 50 then
            return character:FindFirstChild("Head")
        elseif distance < 150 then
            return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
        else
            return character:FindFirstChild("HumanoidRootPart")
        end
    end
    
    -- Hit chance based part selection
    if _G.AimLock.TargetPart == "Auto" then
        local chance = math.random(1, 100)
        if chance <= _G.AimLock.HitChance then
            return character:FindFirstChild("Head")
        else
            return character:FindFirstChild("HumanoidRootPart") or 
                   character:FindFirstChild("UpperTorso") or 
                   character:FindFirstChild("Torso")
        end
    end
    
    -- Manual part selection
    local part = character:FindFirstChild(_G.AimLock.TargetPart)
    if not part then
        part = character:FindFirstChild("Head") or 
               character:FindFirstChild("HumanoidRootPart")
    end
    
    return part
end

-- Trigger Bot Functions
local triggerBotActive = false
local lastShootTime = 0

local function isPlayerInCrosshair()
    if not LocalPlayer.Character or not isPlayerAlive(LocalPlayer) then return false, nil end
    
    local ray = Camera:ScreenPointToRay(Mouse.X, Mouse.Y)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
    
    if result and result.Instance then
        local hitPart = result.Instance
        local targetChar = hitPart:FindFirstAncestorOfClass("Model")

        if targetChar then
            local targetPlayer = Players:GetPlayerFromCharacter(targetChar)

            if targetPlayer and targetPlayer ~= LocalPlayer and isPlayerAlive(targetPlayer) then

                if Config.TriggerBot.TeamCheck and targetPlayer.Team == LocalPlayer.Team then
                    return false, nil
                end

                if Config.TriggerBot.WallCheck then
                    local directRayParams = RaycastParams.new()
                    local filterList = {LocalPlayer.Character, targetChar}
                    for _, player in pairs(Players:GetPlayers()) do
                        if player.Character then
                            table.insert(filterList, player.Character)
                        end
                    end
                    
                    directRayParams.FilterDescendantsInstances = filterList
                    directRayParams.FilterType = Enum.RaycastFilterType.Exclude
                    
                    local origin = Camera.CFrame.Position
                    local direction = (hitPart.Position - origin).Unit * (hitPart.Position - origin).Magnitude
                    local directResult = workspace:Raycast(origin, direction, directRayParams)
                    
                    if directResult then
                        return false, nil
                    end
                end
                
                if math.random(1, 100) <= Config.TriggerBot.HitChance then
                    return true, targetPlayer
                end
            end
        end
    end
    
    return false, nil
end

local function TriggerShoot()
    if not Config.TriggerBot.AutoShoot then return end
    local currentTime = tick()
    if currentTime - lastShootTime < Config.TriggerBot.Delay then
        return
    end
    lastShootTime = currentTime
    pcall(function()
        mouse1click()
    end)
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool and tool:FindFirstChild("Activated") then
                tool:Activate()
            end
        end
    end)
end

local function isTargetVisible(targetHead, targetCharacter)
    if not _G.AimLock.WallCheck then
        return true
    end
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Head") then
        return false
    end
    
    local origin = Camera.CFrame.Position
    local direction = (targetHead.Position - origin).Unit * (targetHead.Position - origin).Magnitude
    
    local raycastParams = RaycastParams.new()
    local filterList = {LocalPlayer.Character, targetCharacter}
    
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(filterList, player.Character)
        end
    end
    
    raycastParams.FilterDescendantsInstances = filterList
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local rayResult = workspace:Raycast(origin, direction, raycastParams)
    
    return rayResult == nil
end

local function getClosestPlayerInFOV()
    local closestPlayer = nil
    local shortestDistance = math.huge
    local mousePos = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isPlayerAlive(player) then
            if _G.AimLock.TeamCheck and player.Team == LocalPlayer.Team then
                continue
            end
            
            local character = player.Character
            if not character then continue end
            
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            
            local distance3D = (hrp.Position - Camera.CFrame.Position).Magnitude
            
            -- Max distance check
            if distance3D > _G.AimLock.MaxLockDistance then
                continue
            end
            
            local targetPart = GetTargetPart(character, distance3D)
            if not targetPart then continue end
            
            local targetPos = targetPart.Position
            local screenPos, onScreen = Camera:WorldToScreenPoint(targetPos)
            
            if onScreen then
                local screenPosVec = Vector2.new(screenPos.X, screenPos.Y)
                local distanceFromMouse = (mousePos - screenPosVec).Magnitude
                
                if distanceFromMouse <= _G.AimLock.FOVSize then
                    if isTargetVisible(targetPart, character) then
                        if distanceFromMouse < shortestDistance then
                            shortestDistance = distanceFromMouse
                            closestPlayer = player
                        end
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

-- ====== UI SETUP ======

Combat:Section('Aim Lock')
local AimLockToggle = Combat:Toggle({
	Title = 'Aim Lock Enabled',
	Value = false,
	Config = true,
	CallBack = function(v)
		_G.AimLock.Enabled = v
		if not v then
			targetPlayer = nil
			_G.AimLock.TargetPlayer = nil
		else
			syde:Notify({
				Title = 'Aim Lock',
				Content = 'Enabled - Press Q to toggle FOV visibility',
				Duration = 2
			})
		end
	end,
	Flag = 'AimLockEnabled'
})

Combat:Toggle({
	Title = 'Show FOV Circle',
	Value = true,
	Config = true,
	CallBack = function(v)
		_G.AimLock.FOVEnabled = v
	end,
	Flag = 'AimLockFOVEnabled'
})

Combat:Toggle({
	Title = 'Team Check',
	Value = true,
	Config = true,
	CallBack = function(v)
		_G.AimLock.TeamCheck = v
	end,
	Flag = 'AimLockTeamCheck'
})

Combat:Toggle({
	Title = 'Wall Check',
	Value = true,
	Config = true,
	CallBack = function(v)
		_G.AimLock.WallCheck = v
	end,
	Flag = 'AimLockWallCheck'
})

Combat:Toggle({
	Title = 'Knocked Check',
	Value = true,
	Config = true,
	CallBack = function(v)
		_G.AimLock.KnockedCheck = v
	end,
	Flag = 'AimLockKnockedCheck'
})

Combat:Toggle({
	Title = 'FOV Filled',
	Value = false,
	Config = true,
	CallBack = function(v)
		_G.AimLock.FOVFilled = v
	end,
	Flag = 'AimLockFOVFilled'
})

Combat:Toggle({
	Title = 'Sticky Lock',
	Value = false,
	Config = true,
	CallBack = function(v)
		_G.AimLock.StickyLock = v
	end,
	Flag = 'AimLockSticky'
})

Combat:Toggle({
	Title = 'Adaptive Smoothing',
	Value = true,
	Config = true,
	CallBack = function(v)
		_G.AimLock.AdaptiveSmoothing = v
	end,
	Flag = 'AimLockAdaptiveSmooth'
})

Combat:Section('Aim Lock - Target Settings')

Combat:Dropdown({
	Title = 'Target Body Part',
	List = {'Head', 'UpperTorso', 'HumanoidRootPart', 'Auto'},
	Value = 'Head',
	Multi = false,
	CallBack = function(v)
		_G.AimLock.TargetPart = v
	end,
	Flag = 'AimLockTargetPart'
})

Combat:Toggle({
	Title = 'Smart Part Selection',
	Value = false,
	Config = true,
	CallBack = function(v)
		_G.AimLock.SmartPartSelection = v
	end,
	Flag = 'AimLockSmartPart'
})

Combat:CreateSlider({
	Title = 'Target Settings',
	Description = '',
	Sliders = {
		{
			Title = 'Hit Chance (%)',
			Range = {0, 100},
			Increment = 1,
			StarterValue = 100,
			CallBack = function(v)
				_G.AimLock.HitChance = v
			end,
			Flag = 'AimLockHitChance'
		},
		{
			Title = 'Max Lock Distance',
			Range = {100, 1000},
			Increment = 50,
			StarterValue = 500,
			CallBack = function(v)
				_G.AimLock.MaxLockDistance = v
			end,
			Flag = 'AimLockMaxDistance'
		},
	}
})

Combat:Section('Aim Lock - Smoothness')

Combat:Dropdown({
	Title = 'Smoothing Style',
	List = {'Linear', 'Exponential', 'Sine', 'Bezier'},
	Value = 'Exponential',
	Multi = false,
	CallBack = function(v)
		_G.AimLock.SmoothingStyle = v
	end,
	Flag = 'AimLockSmoothStyle'
})

Combat:CreateSlider({
	Title = 'Smoothness Settings',
	Description = '',
	Sliders = {
		{
			Title = 'Smoothness',
			Range = {0, 1},
			Increment = 0.01,
			StarterValue = 0.2,
			CallBack = function(v)
				_G.AimLock.Smoothness = v
			end,
			Flag = 'AimLockSmoothness'
		},
		{
			Title = 'Shake Reduction',
			Range = {0, 100},
			Increment = 1,
			StarterValue = 0,
			CallBack = function(v)
				_G.AimLock.ShakeReduction = v
			end,
			Flag = 'AimLockShakeReduce'
		},
	}
})

Combat:Section('Aim Lock - Prediction')

Combat:Toggle({
	Title = 'Enable Prediction',
	Value = true,
	Config = true,
	CallBack = function(v)
		_G.AimLock.PredictionEnabled = v
	end,
	Flag = 'AimLockPredictionEnabled'
})

Combat:Toggle({
	Title = 'Auto Prediction',
	Value = false,
	Config = true,
	CallBack = function(v)
		_G.AimLock.AutoPrediction = v
		if v then
			syde:Notify({
				Title = 'Auto Prediction',
				Content = 'Will auto-adjust based on your ping',
				Duration = 2
			})
		end
	end,
	Flag = 'AimLockAutoPrediction'
})

Combat:Toggle({
	Title = 'Use Velocity',
	Value = true,
	Config = true,
	CallBack = function(v)
		_G.AimLock.UseVelocity = v
	end,
	Flag = 'AimLockUseVelocity'
})

Combat:Toggle({
	Title = 'Use Acceleration',
	Value = false,
	Config = true,
	CallBack = function(v)
		_G.AimLock.UseAcceleration = v
	end,
	Flag = 'AimLockUseAccel'
})

Combat:Toggle({
	Title = 'Horizontal Only',
	Value = false,
	Config = true,
	CallBack = function(v)
		_G.AimLock.HorizontalPredictionOnly = v
	end,
	Flag = 'AimLockHorizontalOnly'
})

Combat:CreateSlider({
	Title = 'Prediction Settings',
	Description = '',
	Sliders = {
		{
			Title = 'Prediction Strength',
			Range = {0, 1},
			Increment = 0.001,
			StarterValue = 0.133,
			CallBack = function(v)
				_G.AimLock.PredictionStrength = v
			end,
			Flag = 'AimLockPrediction'
		},
	}
})

Combat:Section('Aim Lock - FOV')

Combat:CreateSlider({
	Title = 'FOV Settings',
	Description = '',
	Sliders = {
		{
			Title = 'FOV Size',
			Range = {20, 400},
			Increment = 5,
			StarterValue = 100,
			CallBack = function(v)
				_G.AimLock.FOVSize = v
			end,
			Flag = 'AimLockFOVSize'
		},
	}
})

Combat:ColorPicker({
	Title = 'FOV Color',
	Linkable = false,
	Color = Color3.fromRGB(255, 255, 255);
	CallBack = function(v)
		_G.AimLock.FOVColor = v
	end,
	Flag = 'AimLockFOVColor'
})

Combat:Keybind({
	Title = 'Toggle FOV Visibility',
	Key = Enum.KeyCode.Q;
	CallBack = function(key)
		_G.AimLock.Keybind = key
	end,
})

Combat:Section('Trigger Bot')
local TriggerBotToggle = Combat:Toggle({
	Title = 'Trigger Bot Enabled',
	Value = false,
	Config = true,
	CallBack = function(v)
		Config.TriggerBot.Enabled = v
		triggerBotActive = v
		if v then
			syde:Notify({
				Title = 'Trigger Bot',
				Content = 'Enabled - Aim at enemies to auto-shoot',
				Duration = 2
			})
		else
			syde:Notify({
				Title = 'Trigger Bot',
				Content = 'Disabled',
				Duration = 1.5
			})
		end
	end,
	Flag = 'TriggerBotEnabled'
})

Combat:Toggle({
	Title = 'Team Check',
	Value = true,
	Config = true,
	CallBack = function(v)
		Config.TriggerBot.TeamCheck = v
	end,
	Flag = 'TriggerBotTeamCheck'
})

Combat:Toggle({
	Title = 'Wall Check',
	Value = true,
	Config = true,
	CallBack = function(v)
		Config.TriggerBot.WallCheck = v
	end,
	Flag = 'TriggerBotWallCheck'
})

Combat:Toggle({
	Title = 'Auto Shoot',
	Value = true,
	Config = true,
	CallBack = function(v)
		Config.TriggerBot.AutoShoot = v
	end,
	Flag = 'TriggerBotAutoShoot'
})

Combat:CreateSlider({
	Title = 'Trigger Bot Options',
	Description = '',
	Sliders = {
		{
			Title = 'Shoot Delay (ms)',
			Range = {0, 500},
			Increment = 10,
			StarterValue = 0,
			CallBack = function(v)
				Config.TriggerBot.Delay = v / 1000
			end,
			Flag = 'TriggerBotDelay'
		},
		{
			Title = 'Hit Chance (%)',
			Range = {1, 100},
			Increment = 1,
			StarterValue = 100,
			CallBack = function(v)
				Config.TriggerBot.HitChance = v
			end,
			Flag = 'TriggerBotHitChance'
		},
	}
})

Combat:Keybind({
	Title = 'Trigger Bot Toggle',
	Key = Enum.KeyCode.T;
	CallBack = function()
		Config.TriggerBot.Enabled = not Config.TriggerBot.Enabled
		triggerBotActive = Config.TriggerBot.Enabled
		TriggerBotToggle:Set(Config.TriggerBot.Enabled)
	end,
})

-- ====== ESP SETTINGS ======

Visuals:Section('ESP - General')
local EspToggle = Visuals:Toggle({
	Title = 'ESP Enabled',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.enabled = v
			syde:Notify({
				Title = 'ESP',
				Content = v and 'Enabled' or 'Disabled',
				Duration = 1.5
			})
		end
	end,
	Flag = 'EspEnabled'
})

Visuals:Toggle({
	Title = 'Team Color',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.sharedSettings.useTeamColor = v
		end
	end,
	Flag = 'EspTeamColor'
})

Visuals:Toggle({
	Title = 'Limit Distance',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.sharedSettings.limitDistance = v
		end
	end,
	Flag = 'EspLimitDistance'
})

Visuals:CreateSlider({
	Title = 'ESP General Settings',
	Description = '',
	Sliders = {
		{
			Title = 'Max Distance',
			Range = {100, 1000},
			Increment = 50,
			StarterValue = 500,
			CallBack = function(v)
				if VenexEsp then
					VenexEsp.sharedSettings.maxDistance = v
				end
			end,
			Flag = 'EspMaxDistance'
		},
	}
})

Visuals:Section('ESP - Enemy Box')
Visuals:Toggle({
	Title = 'Box',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.box = v
		end
	end,
	Flag = 'EspEnemyBox'
})

Visuals:Toggle({
	Title = 'Box Outline',
	Value = true,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.boxOutline = v
		end
	end,
	Flag = 'EspEnemyBoxOutline'
})

Visuals:Toggle({
	Title = 'Box Fill',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.boxFill = v
		end
	end,
	Flag = 'EspEnemyBoxFill'
})

Visuals:Toggle({
	Title = '3D Box',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.box3d = v
		end
	end,
	Flag = 'EspEnemy3DBox'
})

Visuals:ColorPicker({
	Title = 'Box Color',
	Linkable = false,
	Color = Color3.fromRGB(255, 0, 0);
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.boxColor[1] = v
		end
	end,
	Flag = 'EspEnemyBoxColor'
})

Visuals:ColorPicker({
	Title = 'Box Fill Color',
	Linkable = false,
	Color = Color3.fromRGB(255, 0, 0);
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.boxFillColor[1] = v
		end
	end,
	Flag = 'EspEnemyBoxFillColor'
})

Visuals:Section('ESP - Enemy Health')
Visuals:Toggle({
	Title = 'Health Bar',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.healthBar = v
		end
	end,
	Flag = 'EspEnemyHealthBar'
})

Visuals:Toggle({
	Title = 'Health Bar Outline',
	Value = true,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.healthBarOutline = v
		end
	end,
	Flag = 'EspEnemyHealthBarOutline'
})

Visuals:Toggle({
	Title = 'Health Text',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.healthText = v
		end
	end,
	Flag = 'EspEnemyHealthText'
})

Visuals:ColorPicker({
	Title = 'Healthy Color',
	Linkable = false,
	Color = Color3.fromRGB(0, 255, 0);
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.healthyColor = v
		end
	end,
	Flag = 'EspEnemyHealthyColor'
})

Visuals:ColorPicker({
	Title = 'Dying Color',
	Linkable = false,
	Color = Color3.fromRGB(255, 0, 0);
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.dyingColor = v
		end
	end,
	Flag = 'EspEnemyDyingColor'
})

Visuals:Section('ESP - Enemy Text')
Visuals:Toggle({
	Title = 'Name',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.name = v
		end
	end,
	Flag = 'EspEnemyName'
})

Visuals:Toggle({
	Title = 'Distance',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.distance = v
		end
	end,
	Flag = 'EspEnemyDistance'
})

Visuals:Toggle({
	Title = 'Weapon',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.weapon = v
		end
	end,
	Flag = 'EspEnemyWeapon'
})

Visuals:ColorPicker({
	Title = 'Name Color',
	Linkable = false,
	Color = Color3.fromRGB(255, 255, 255);
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.nameColor[1] = v
		end
	end,
	Flag = 'EspEnemyNameColor'
})

Visuals:Section('ESP - Enemy Tracer')
Visuals:Toggle({
	Title = 'Tracer',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.tracer = v
		end
	end,
	Flag = 'EspEnemyTracer'
})

Visuals:Toggle({
	Title = 'Tracer Outline',
	Value = true,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.tracerOutline = v
		end
	end,
	Flag = 'EspEnemyTracerOutline'
})

Visuals:Dropdown({
	Title = 'Tracer Origin',
	List = {'Top', 'Middle', 'Bottom'},
	Value = 'Bottom',
	Multi = false,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.tracerOrigin = v
		end
	end,
	Flag = 'EspEnemyTracerOrigin'
})

Visuals:ColorPicker({
	Title = 'Tracer Color',
	Linkable = false,
	Color = Color3.fromRGB(255, 0, 0);
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.tracerColor[1] = v
		end
	end,
	Flag = 'EspEnemyTracerColor'
})

Visuals:Section('ESP - Enemy Skeleton')
Visuals:Toggle({
	Title = 'Skeleton',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.skeleton = v
		end
	end,
	Flag = 'EspEnemySkeleton'
})

Visuals:Toggle({
	Title = 'Skeleton Outline',
	Value = true,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.skeletonOutline = v
		end
	end,
	Flag = 'EspEnemySkeletonOutline'
})

Visuals:ColorPicker({
	Title = 'Skeleton Color',
	Linkable = false,
	Color = Color3.fromRGB(255, 255, 255);
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.skeletonColor[1] = v
		end
	end,
	Flag = 'EspEnemySkeletonColor'
})

Visuals:Section('ESP - Enemy Chams')
Visuals:Toggle({
	Title = 'Chams',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.chams = v
		end
	end,
	Flag = 'EspEnemyChams'
})

Visuals:Toggle({
	Title = 'Chams Visible Only',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.chamsVisibleOnly = v
		end
	end,
	Flag = 'EspEnemyChamsVisibleOnly'
})

Visuals:ColorPicker({
	Title = 'Chams Fill Color',
	Linkable = false,
	Color = Color3.fromRGB(51, 51, 51);
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.chamsFillColor[1] = v
		end
	end,
	Flag = 'EspEnemyChamsFillColor'
})

Visuals:ColorPicker({
	Title = 'Chams Outline Color',
	Linkable = false,
	Color = Color3.fromRGB(255, 0, 0);
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.enemy.chamsOutlineColor[1] = v
		end
	end,
	Flag = 'EspEnemyChamsOutlineColor'
})

Visuals:Section('ESP - Friendly Settings')
Visuals:Toggle({
	Title = 'Show Friendly ESP',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.friendly.enabled = v
		end
	end,
	Flag = 'EspFriendlyEnabled'
})

Visuals:Toggle({
	Title = 'Friendly Box',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.friendly.box = v
		end
	end,
	Flag = 'EspFriendlyBox'
})

Visuals:Toggle({
	Title = 'Friendly Name',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.friendly.name = v
		end
	end,
	Flag = 'EspFriendlyName'
})

Visuals:Toggle({
	Title = 'Friendly Health Bar',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.friendly.healthBar = v
		end
	end,
	Flag = 'EspFriendlyHealthBar'
})

Visuals:Toggle({
	Title = 'Friendly Chams',
	Value = false,
	Config = true,
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.friendly.chams = v
		end
	end,
	Flag = 'EspFriendlyChams'
})

Visuals:ColorPicker({
	Title = 'Friendly Box Color',
	Linkable = false,
	Color = Color3.fromRGB(0, 255, 0);
	CallBack = function(v)
		if VenexEsp then
			VenexEsp.teamSettings.friendly.boxColor[1] = v
		end
	end,
	Flag = 'EspFriendlyBoxColor'
})

Player:Section('Movement')
local CFrameSpeedToggle = Player:Toggle({
	Title = 'CFrame Speed Enabled',
	Value = false,
	Config = true,
	CallBack = function(v)
		Config.CFrameSpeed.Enabled = v
	end,
	Flag = 'CFrameSpeedEnabled'
})

Player:CreateSlider({
	Title = 'CFrame Speed',
	Description = '',
	Sliders = {
		{
			Title = 'Speed',
			Range = {0, 10},
			Increment = 1,
			StarterValue = 1,
			CallBack = function(v)
				Config.CFrameSpeed.Speed = v
			end,
			Flag = 'CFrameSpeed'
		},
	}
})

Player:Keybind({
	Title = 'CFrame Speed KeyBind',
	Key = Enum.KeyCode.B;
	CallBack = function()
		Config.CFrameSpeed.Enabled = not Config.CFrameSpeed.Enabled
        CFrameSpeedToggle:Set(Config.CFrameSpeed.Enabled)
	end,
})

World:Section('Visual Enhancements')
World:Toggle({
	Title = 'Fullbright',
	Value = false,
	Config = true,
	CallBack = function(v)
		Config.World.Fullbright = v
		ApplyFullbright(v)
		syde:Notify({
			Title = 'Fullbright',
			Content = v and 'Enabled' or 'Disabled',
			Duration = 1.5
		})
	end,
	Flag = 'WorldFullbright'
})

World:Toggle({
	Title = 'No Shadows',
	Value = false,
	Config = true,
	CallBack = function(v)
		Config.World.NoShadows = v
		ApplyNoShadows(v)
		syde:Notify({
			Title = 'No Shadows',
			Content = v and 'Enabled' or 'Disabled',
			Duration = 1.5
		})
	end,
	Flag = 'WorldNoShadows'
})

World:Button({
	Title = 'Reset Lighting',
	Description = 'Restore Original Lighting Settings',
	Type = 'Default',
	HoldTime = 1,
	CallBack = function()
		Config.World.Fullbright = false
		Config.World.NoShadows = false
		ApplyFullbright(false)
		ApplyNoShadows(false)
		syde:Notify({
			Title = 'Lighting Reset',
			Content = 'All world settings restored',
			Duration = 2
		})
	end,
})

Misc:Section('Server')
Misc:Button({
	Title = 'Rejoin Server',
	Description = 'Rejoins Current Server',
	Type = 'Default',
	HoldTime = 2,
	CallBack = function()
        syde:Notify({
            Title = 'Rejoin Server',
            Content = 'Rejoining current server...',
            Duration = 5
        })
        task.wait(0.7)
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end,
})

Misc:Button({
	Title = 'Server Hop',
	Description = 'Hops to a Different Server',
	Type = 'Default',
	HoldTime = 2,
	CallBack = function()
        syde:Notify({
            Title = 'Server Hop',
            Content = 'Searching for another server...',
            Duration = 5
        })
        local ok, res = pcall(function()
            local s = HttpGet(string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", game.PlaceId))
            return s and HttpService:JSONDecode(s) or nil
        end)
        if ok and res and res.data then
            for _, server in ipairs(res.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    syde:Notify({
                        Title = 'Server Hop',
                        Content = 'Joining a new server...',
                        Duration = 3
                    })
                    task.wait(0.5)
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                    return
                end
            end
            syde:Notify({
                Title = 'Server Hop',
                Content = 'No other servers found.',
                Duration = 3
            })
        else
            syde:Notify({
                Title = 'Server Hop',
                Content = 'Failed to fetch server list.',
                Duration = 5
            })
        end
	end,
})

-- ====== CONNECTION HANDLERS ======

connections.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == _G.AimLock.Keybind and not gameProcessed then
        _G.AimLock.FOVEnabled = not _G.AimLock.FOVEnabled
        local status = _G.AimLock.FOVEnabled and 'Visible' or 'Hidden'
        syde:Notify({
            Title = 'FOV Circle',
            Content = status,
            Duration = 1
        })
    end
end)

-- Main Aimlock Logic with Enhanced Prediction and Smoothing
connections.RenderStepped = RunService.RenderStepped:Connect(function(deltaTime)
    UpdateFOVCircle()
    
    if not isPlayerAlive(LocalPlayer) then
        targetPlayer = nil
        _G.AimLock.TargetPlayer = nil
        return
    end
    
    if _G.AimLock.Enabled then
        -- Find new target if we don't have one or sticky lock is disabled
        if not targetPlayer or not _G.AimLock.StickyLock then
            local newTarget = getClosestPlayerInFOV()
            if newTarget then
                targetPlayer = newTarget
                _G.AimLock.TargetPlayer = newTarget
            end
        end
        
        -- Sticky lock validation
        if targetPlayer and _G.AimLock.StickyLock then
            if not isPlayerAlive(targetPlayer) then
                targetPlayer = nil
                _G.AimLock.TargetPlayer = nil
                return
            end
            
            -- Check if target is still in FOV for sticky lock
            local character = targetPlayer.Character
            if character then
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local distance3D = (hrp.Position - Camera.CFrame.Position).Magnitude
                    if distance3D > _G.AimLock.MaxLockDistance then
                        targetPlayer = nil
                        _G.AimLock.TargetPlayer = nil
                        return
                    end
                end
            end
        end
        
        if targetPlayer and targetPlayer.Character then
            local character = targetPlayer.Character
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            
            local distance3D = (hrp.Position - Camera.CFrame.Position).Magnitude
            local targetPart = GetTargetPart(character, distance3D)
            
            if targetPart then
                -- Calculate predicted position
                local predictedPos = CalculatePrediction(targetPart, character)
                
                local screenPos, onScreen = Camera:WorldToScreenPoint(predictedPos)
                
                if onScreen then
                    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
                    local targetPos = Vector2.new(screenPos.X, screenPos.Y)
                    local delta = targetPos - mousePos
                    
                    -- Adaptive smoothing based on distance
                    local smoothness = _G.AimLock.Smoothness
                    if _G.AimLock.AdaptiveSmoothing then
                        local distanceFactor = math.clamp(distance3D / 200, 0.3, 1)
                        smoothness = smoothness * distanceFactor
                    end
                    
                    -- Apply smoothing style
                    local smoothingFunc = SmoothingFunctions[_G.AimLock.SmoothingStyle] or SmoothingFunctions.Exponential
                    local smoothDelta = smoothingFunc(delta, smoothness)
                    
                    -- Apply shake reduction
                    if _G.AimLock.ShakeReduction > 0 then
                        local shakeReductionFactor = 1 - (_G.AimLock.ShakeReduction / 100)
                        local magnitude = smoothDelta.Magnitude
                        if magnitude < 50 * shakeReductionFactor then
                            smoothDelta = smoothDelta * (magnitude / (50 * shakeReductionFactor))
                        end
                    end
                    
                    -- Move mouse
                    pcall(function()
                        mousemoverel(smoothDelta.X, smoothDelta.Y)
                    end)
                else
                    if _G.AimLock.AutoUnlock then
                        targetPlayer = nil
                        _G.AimLock.TargetPlayer = nil
                    end
                end
            end
        else
            targetPlayer = nil
            _G.AimLock.TargetPlayer = nil
        end
    end
end)

connections.TriggerBot = RunService.RenderStepped:Connect(function()
    if triggerBotActive and Config.TriggerBot.Enabled then
        local hasTarget, target = isPlayerInCrosshair()
        if hasTarget then
            TriggerShoot()
        end
    end
end)

-- CFrame Speed Loop
local MainLoop = RunService.RenderStepped:Connect(function(dt)
    if Config.CFrameSpeed.Enabled then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hum and hrp then
            local dir = hum.MoveDirection
            if dir.Magnitude > 0 then
                hrp.CFrame = hrp.CFrame + (dir * Config.CFrameSpeed.Speed)
            end
        end
    end
end)

-- Unload Function
_G.UnloadVantage = function()
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    if MainLoop then
        MainLoop:Disconnect()
    end
    
    if FOVCircle then
        FOVCircle:Remove()
    end
    
    connections = {}
    targetPlayer = nil
    triggerBotActive = false
    _G.AimLock.Enabled = false
    _G.AimLock.TargetPlayer = nil
    Config.TriggerBot.Enabled = false
    
    ApplyFullbright(false)
    ApplyNoShadows(false)
    
    if VenexEsp and VenexEsp.Unload then
        VenexEsp.Unload()
    end
    
    _G.VantageExecuted = false
    
    print("[Vantage] Successfully unloaded")
end

-- Initialize ESP
if VenexEsp then
    pcall(function()
        VenexEsp.Load()
    end)
else
    warn("[Vantage] ESP Library failed to load")
end

_G.VantageExecuted = true

syde:Notify({
    Title = 'Vantage Internal',
    Content = 'Successfully loaded with enhanced features!',
    Duration = 4
})