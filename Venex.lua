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

_G.AimLock = _G.AimLock or {
    Enabled = false,
    FOVEnabled = false,
    TargetPlayer = nil,
    Smoothness = 0.2,
    PredictionStrength = 0,
    FOVSize = 100,
    FOVColor = Color3.fromRGB(255, 255, 255),
    FOVTransparency = 0.5,
    FOVFilled = false,
    WallCheck = true,
    TeamCheck = true,
    Keybind = Enum.KeyCode.Q,
}

local targetPlayer = nil
local connections = {}
local FOVCircle = nil

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
        FOVCircle.Visible = false
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

-- No Shadows Function
local function ApplyNoShadows(enabled)
    Lighting.GlobalShadows = not enabled
end

local function isPlayerAlive(player)
    if not player or not player.Character then return false end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
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
                
                -- Hit chance check
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
        if player ~= LocalPlayer and isPlayerAlive(player) and player.Character:FindFirstChild("Head") then
            if _G.AimLock.TeamCheck and player.Team == LocalPlayer.Team then
                continue
            end
            
            local head = player.Character.Head
            local headPos = head.Position
            
            local screenPos, onScreen = Camera:WorldToScreenPoint(headPos)
            
            if onScreen then
                local screenPosVec = Vector2.new(screenPos.X, screenPos.Y)
                local distanceFromMouse = (mousePos - screenPosVec).Magnitude
                
                if distanceFromMouse <= _G.AimLock.FOVSize then
                    if isTargetVisible(head, player.Character) then
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
				Content = 'FOV Circle Enabled - Press Q to toggle visibility',
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
	Title = 'FOV Filled',
	Value = false,
	Config = true,
	CallBack = function(v)
		_G.AimLock.FOVFilled = v
	end,
	Flag = 'AimLockFOVFilled'
})
Combat:CreateSlider({
	Title = 'Aim Lock Options',
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
		{
			Title = 'Prediction',
			Range = {0, 10},
			Increment = 0.1,
			StarterValue = 0,
			CallBack = function(v)
				_G.AimLock.PredictionStrength = v
			end,
			Flag = 'AimLockPrediction'
		},
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

Visuals:Section('Enemy Esp')
Visuals:Toggle({
	Title = 'Enabled',
	Value = false,
	Config = true,
	CallBack = function(v)
		VenexEsp.enabled = v
	end,
	Flag = 'EspEnabled'
})
Visuals:Toggle({
	Title = 'Enemy Box',
	Value = false,
	Config = true,
	CallBack = function(v)
		VenexEsp.teamSettings.enemy.box = v
	end,
	Flag = 'EspEnemyBox'
})
Visuals:Toggle({
	Title = 'Enemy Name',
	Value = false,
	Config = true,
	CallBack = function(v)
		VenexEsp.teamSettings.enemy.name = v
	end,
	Flag = 'EspEnemyName'
})
Visuals:Toggle({
	Title = 'Enemy Health Bar',
	Value = false,
	Config = true,
	CallBack = function(v)
		VenexEsp.teamSettings.enemy.healthBar = v
	end,
	Flag = 'EspEnemyHealthBar'
})
Visuals:ColorPicker({
	Title = 'Box Color',
	Linkable = false,
	Color = Color3.fromRGB(255,255,255);
	CallBack = function(v)
		VenexEsp.teamSettings.enemy.boxColor[1] = v
	end,
	Flag = 'EspEnemyBoxColor'
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

connections.RenderStepped = RunService.RenderStepped:Connect(function()
    UpdateFOVCircle()
    
    if not isPlayerAlive(LocalPlayer) then
        targetPlayer = nil
        _G.AimLock.TargetPlayer = nil
        return
    end
    
    if _G.AimLock.Enabled then
        local newTarget = getClosestPlayerInFOV()
        
        if newTarget then
            targetPlayer = newTarget
            _G.AimLock.TargetPlayer = newTarget
            
            local head = targetPlayer.Character.Head
            local headPos = head.Position
            
            if targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = targetPlayer.Character.HumanoidRootPart
                local velocity = hrp.Velocity or hrp.AssemblyLinearVelocity or Vector3.new(0, 0, 0)
                headPos = headPos + (velocity * _G.AimLock.PredictionStrength)
            end
            
            local screenPos, onScreen = Camera:WorldToScreenPoint(headPos)
            
            if onScreen then
                local mousePos = Vector2.new(Mouse.X, Mouse.Y)
                local targetPos = Vector2.new(screenPos.X, screenPos.Y)
                local delta = targetPos - mousePos
                
                local smoothDelta
                if _G.AimLock.Smoothness >= 1 then
                    smoothDelta = delta
                else
                    smoothDelta = delta * _G.AimLock.Smoothness
                end
                
                mousemoverel(smoothDelta.X, smoothDelta.Y)
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

_G.UnloadVantage = function()
    for _, connection in pairs(connections) do
        connection:Disconnect()
    end
    for _, connection in pairs(textureConnections) do
        connection:Disconnect()
    end
    if FOVCircle then
        FOVCircle:Remove()
    end
    connections = {}
    textureConnections = {}
    targetPlayer = nil
    triggerBotActive = false
    _G.AimLock.Enabled = false
    _G.AimLock.TargetPlayer = nil
    Config.TriggerBot.Enabled = false
    
    ApplyFullbright(false)
    ApplyNoShadows(false)
    ApplyNoTextures(false)
    
    print("Vantage Internal unloaded")
end

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

VenexEsp.Load()
_G.VantageExecuted = true
syde:Notify({
    Title = 'Vantage Internal',
    Content = 'Vantage Internal Executed!',
    Duration = 4
})