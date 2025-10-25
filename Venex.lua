if _G.VantageExecuted then
	Library:Notify('[Vantage] Error : Already Loaded!', 5)
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

--// Services
local Players             = game:GetService("Players")
local TeleportService     = game:GetService("TeleportService")
local TweenService        = game:GetService("TweenService")
local UserInputService    = game:GetService("UserInputService")
local RunService          = game:GetService("RunService")

--// Variables
local LocalPlayer          = Players.LocalPlayer

local syde         = Load("https://raw.githubusercontent.com/essencejs/syde/refs/heads/main/source",true)
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
	Status = 'Stable', -- {Stable, Unstable, Detected, Patched}
	Accent = Color3.fromRGB(251, 144, 255), -- Window Accent Theme
	HitBox = Color3.fromRGB(251, 144, 255), -- Window HitBox Theme (ex. Toggle Color)
	AutoLoad = false, -- Does Not Work !
	Socials = {    -- Allows 1 Large and 2 Small Blocks
		{
			Name = 'Syde';
			Style = 'Discord';
			Size = "Large";
			CopyToClip = false -- Copy To Clip (coming very soon)
		},
		{
			Name = 'GitHub';
			Style = 'GitHub';
			Size = "Small";
			CopyToClip = false
		}
	},
	ConfigurationSaving = { -- Allows Config Saving
		Enabled = true,
		FolderName = 'Vantage',
		FileName = "Config"
	},
	AutoJoinDiscord = { 
		Enabled = false, -- Prompt the user to join your Discord server if their executor supports it
		Invite = "CZRZBwPz", -- The Discord invite code, do not include discord.gg/. E.g. discord.gg/ ABCD would be ABCD
		RememberJoins = false -- Set this to false to make them join the discord every time they load it up
	},
})

local Window = syde:Init({
	Title = 'Vantage Internal'; -- Set Title
	SubText = 'Made With 💓 By @Cncspt' -- Set Subtitle
})

local Combat  = Window:InitTab({ Title = 'Combat' })
local Visuals = Window:InitTab({ Title = 'Visuals' })
local Player  = Window:InitTab({ Title = 'Player' })
local Misc    = Window:InitTab({ Title = 'Misc' })

Visuals:Section('Enemy Esp')
Visuals:Toggle({
	Title = 'Enable Enemy Esp',
	Value = false,
	Config = true,
	CallBack = function(v)
		VenexEsp.teamSettings.enemy.enabled = v
	end,
	Flag = 'EspEnemy'
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
	Title = 'Box Color', -- Set Title
	Linkable = false, -- Set if you want to link color to another colorpicker (Optional)
	Color = Color3.fromRGB(255,255,255); -- Set Default Color
	CallBack = function(v)
		VenexEsp.teamSettings.enemy.boxColor[1] = v
	end,
	Flag = 'EspEnemyBoxColor' -- Use if you are running config saving, make sure each element has a diffrent Flag name.
})

Player:Section('Movement')
Player:Toggle({
	Title = 'CFrame Speed Enabled',
	Value = false,
	Config = true,
	CallBack = function(v)
		Config.CFrameSpeed.Enabled = v
	end,
	Flag = 'CFrameSpeedEnabled'
})
Player:CreateSlider({
	Title = 'CFrame Speed', -- Set Title
	Description = '', -- Description (Optional)
	Sliders = { -- Initialize the sliders
		{
			Title = 'Speed', -- Set Title
			Range = {0, 10}, -- Set Range (Min, Max)
			Increment = 1, -- Set Increment
			StarterValue = 1, -- Set Starter Value
			CallBack = function(v)
				Config.CFrameSpeed.Speed = v
			end,
			Flag = 'CFrameSpeed' -- Use if you are running config saving, make sure each element has a diffrent Flag name.
		},
	}
})
Player:Keybind({
	Title = 'CFrame Speed KeyBind', -- Set Title
	Key = Enum.KeyCode.V; -- Default Bind
	CallBack = function(v)
		Config.CFrameSpeed.Enabled = v
	end,
})


Misc:Section('Server')
Misc:Button({
	Title = 'Rejoin', -- Set Title
	Description = 'Rejoins Current Server', -- Description (Optional)
	Type = 'Default', -- Type [ Default, Hold ] (Optional)
	HoldTime = 2, -- Hold Time When Type is *Hold
	CallBack = function()
        syde:Notify({
            Title = 'Server',
            Content = 'Rejoining current server...',
            Duration = 5
        })
        task.wait(0.7)
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end,
})

--// Main Loop
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