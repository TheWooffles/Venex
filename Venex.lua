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
local Misc    = Window:InitTab({ Title = 'Misc' })

_G.AimLock = _G.AimLock or {
    Enabled = false,
    TargetPlayer = nil,
    Smoothness = 0.2,
    PredictionStrength = 0,
    MaxDistance = 500,
    WallCheck = true,
    TeamCheck = true,
    Keybind = Enum.KeyCode.Q,
}

local isLocking = false
local targetPlayer = nil
local connections = {}

Combat:Section('Aim Lock')
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
Combat:CreateSlider({
	Title = 'Aim Lock Options',
	Description = '',
	Sliders = {
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
        {
			Title = 'Max Distance',
			Range = {0, 700},
			Increment = 10,
			StarterValue = 500,
			CallBack = function(v)
				_G.AimLock.MaxDistance = v
			end,
			Flag = 'AimLockMaxDistance'
		},
	}
})
Combat:Keybind({
	Title = 'Aim Lock Keybind',
	Key = Enum.KeyCode.Q;
	CallBack = function(key)
		_G.AimLock.Keybind = key
	end,
})

Visuals:Section('Enemy Esp')
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

local function isTargetVisible(targetHead)
    if not _G.AimLock.WallCheck then
        return true
    end
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Head") then
        return false
    end
    
    local origin = Camera.CFrame.Position
    local direction = (targetHead.Position - origin).Unit * (targetHead.Position - origin).Magnitude
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, targetPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local rayResult = workspace:Raycast(origin, direction, raycastParams)
    
    return rayResult == nil
end

local function getClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
            if _G.AimLock.TeamCheck and player.Team == LocalPlayer.Team then
                continue
            end
            
            local head = player.Character.Head
            local headPos = head.Position
            local distance = (LocalPlayer.Character.Head.Position - headPos).Magnitude
            
            if distance <= _G.AimLock.MaxDistance then
                local screenPos, onScreen = Camera:WorldToScreenPoint(headPos)
                
                if onScreen then
                    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
                    local screenDistance = (mousePos - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
                    
                    if screenDistance < shortestDistance then
                        shortestDistance = screenDistance
                        closestPlayer = player
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

connections.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == _G.AimLock.Keybind and not gameProcessed then
        isLocking = not isLocking
        _G.AimLock.Enabled = isLocking
        
        if isLocking then
            targetPlayer = getClosestPlayer()
            _G.AimLock.TargetPlayer = targetPlayer
            if targetPlayer then
                syde:Notify({
                    Title = '🎯 Aim Lock',
                    Content = "Locked → " .. targetPlayer.Name,
                    Duration = 2
                })
            else
                syde:Notify({
                    Title = '⚠️ Aim Lock',
                    Content = 'No valid targets found',
                    Duration = 2
                })
                isLocking = false
                _G.AimLock.Enabled = false
            end
        else
            syde:Notify({
                Title = '🎯 Aim Lock',
                Content = 'Disabled',
                Duration = 1.5
            })
            targetPlayer = nil
            _G.AimLock.TargetPlayer = nil
        end
    end
end)

connections.RenderStepped = RunService.RenderStepped:Connect(function()
    if isLocking and targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Head") then
        local head = targetPlayer.Character.Head
        local headPos = head.Position
        
        if targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = targetPlayer.Character.HumanoidRootPart
            local velocity = hrp.Velocity or hrp.AssemblyLinearVelocity or Vector3.new(0, 0, 0)
            headPos = headPos + (velocity * _G.AimLock.PredictionStrength)
        end
        
        local screenPos, onScreen = Camera:WorldToScreenPoint(headPos)
        
        if onScreen and isTargetVisible(head) then
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
        elseif not onScreen then
            isLocking = false
            targetPlayer = nil
            _G.AimLock.Enabled = false
            _G.AimLock.TargetPlayer = nil
            syde:Notify({
                Title = '❌ Aim Lock',
                Content = 'Target lost',
                Duration = 1.5
            })
        end
    end
end)

_G.UnloadAimLock = function()
    for _, connection in pairs(connections) do
        connection:Disconnect()
    end
    connections = {}
    isLocking = false
    targetPlayer = nil
    _G.AimLock.Enabled = false
    _G.AimLock.TargetPlayer = nil
    print("Aim lock unloaded")
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
end);

VenexEsp:Load()
_G.VantageExecuted = true
syde:Notify({
    Title = 'Vantage Internal',
    Content = 'Vantage Internal Executed!',
    Duration = 4
})