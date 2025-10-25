--// Services
local Players             = game:GetService("Players")
local TeleportService     = game:GetService("TeleportService")

--// Variables
local LocalPlayer          = Players.LocalPlayer

local syde = loadstring(game:HttpGet("https://raw.githubusercontent.com/essencejs/syde/refs/heads/main/source",true))()

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
			CopyToClip = true -- Copy To Clip (coming very soon)
		},
		{
			Name = 'GitHub';
			Style = 'GitHub';
			Size = "Small";
			CopyToClip = true
		}
	},
	ConfigurationSaving = { -- Allows Config Saving
		Enabled = true,
		FolderName = 'since',
		FileName = "hot"
	},
	AutoJoinDiscord = { 
		Enabled = true, -- Prompt the user to join your Discord server if their executor supports it
		Invite = "CZRZBwPz", -- The Discord invite code, do not include discord.gg/. E.g. discord.gg/ ABCD would be ABCD
		RememberJoins = false -- Set this to false to make them join the discord every time they load it up
	},
})

local Window = syde:Init({
	Title = 'Vantage'; -- Set Title
	SubText = 'Made With 💓 By @Cncspt' -- Set Subtitle
})

local Combat = Window:InitTab({ Title = 'Combat' })
local Misc   = Window:InitTab({ Title = 'Misc' })
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
        task.wait(0.5)
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end,
})