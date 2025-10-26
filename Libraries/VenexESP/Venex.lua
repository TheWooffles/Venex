-- services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- variables
local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local container = Instance.new("Folder")
container.Name = "ESPContainer"
container.Parent = (gethui and gethui() or game:GetService("CoreGui"))

-- cache commonly used values
local VECTOR2_ZERO = Vector2.new(0, 0)
local VECTOR3_ZERO = Vector3.new(0, 0, 0)
local COLOR3_WHITE = Color3.new(1, 1, 1)
local COLOR3_BLACK = Color3.new(0, 0, 0)

-- locals / helpers (optimized)
local floor = math.floor
local min = math.min
local max = math.max
local round = math.round or floor
local sin = math.sin
local cos = math.cos
local clear = table.clear or function(t) for k in pairs(t) do t[k] = nil end end
local unpack = table.unpack
local find = table.find

-- pre-allocated tables for reuse
local tempCorners = {}

-- constants (optimized)
local HEALTH_BAR_OFFSET = Vector2.new(5, 0)
local HEALTH_TEXT_OFFSET = Vector2.new(3, 0)
local HEALTH_BAR_OUTLINE_OFFSET = Vector2.new(0, 1)
local NAME_OFFSET = Vector2.new(0, 2)
local DISTANCE_OFFSET = Vector2.new(0, 2)

-- Pre-calculate vertices once
local VERTICES = {
	Vector3.new(-1, -1, -1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(-1, -1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, 1, 1),
	Vector3.new(1, -1, 1)
}

-- Body part lookup table (faster than string operations)
local BODY_PARTS = {
	Head = true,
	UpperTorso = true,
	LowerTorso = true,
	Torso = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true
}

-- Cache viewport size updates
local viewportSize = Vector2.new(1920, 1080)
local viewportCenter = viewportSize * 0.5

-- CFrame/Vector helpers (optimized)
local function lerpColor(a, b, t)
	return Color3.new(
		a.R + (b.R - a.R) * t,
		a.G + (b.G - a.G) * t,
		a.B + (b.B - a.B) * t
	)
end

local function min2(corners, count)
	local minx, miny = math.huge, math.huge
	for i = 1, count do
		local v = corners[i]
		if v.X < minx then minx = v.X end
		if v.Y < miny then miny = v.Y end
	end
	return Vector2.new(minx, miny)
end

local function max2(corners, count)
	local maxx, maxy = -math.huge, -math.huge
	for i = 1, count do
		local v = corners[i]
		if v.X > maxx then maxx = v.X end
		if v.Y > maxy then maxy = v.Y end
	end
	return Vector2.new(maxx, maxy)
end

-- Optimized bounding box calculation
local function getBoundingBox(parts, count)
	local minx, miny, minz = math.huge, math.huge, math.huge
	local maxx, maxy, maxz = -math.huge, -math.huge, -math.huge
	
	for i = 1, count do
		local part = parts[i]
		local pos = part.Position
		local size = part.Size
		local hx, hy, hz = size.X * 0.5, size.Y * 0.5, size.Z * 0.5
		
		local ax, ay, az = pos.X - hx, pos.Y - hy, pos.Z - hz
		local bx, by, bz = pos.X + hx, pos.Y + hy, pos.Z + hz
		
		if ax < minx then minx = ax end
		if ay < miny then miny = ay end
		if az < minz then minz = az end
		if bx > maxx then maxx = bx end
		if by > maxy then maxy = by end
		if bz > maxz then maxz = bz end
	end

	if minx == math.huge then
		return CFrame.new(), VECTOR3_ZERO
	end

	local cx, cy, cz = (minx + maxx) * 0.5, (miny + maxy) * 0.5, (minz + maxz) * 0.5
	return CFrame.new(cx, cy, cz),
	       Vector3.new(maxx - minx, maxy - miny, maxz - minz)
end

local function worldToScreen(world)
	local screenPoint, onScreen = camera:WorldToViewportPoint(world)
	return Vector2.new(screenPoint.X, screenPoint.Y), onScreen, screenPoint.Z
end

-- Optimized corner calculation with reusable table
local function calculateCorners(cframe, size)
	local hx, hy, hz = size.X * 0.5, size.Y * 0.5, size.Z * 0.5
	local cf = cframe
	
	-- Calculate all 8 corners directly
	tempCorners[1] = worldToScreen((cf * CFrame.new(-hx, -hy, -hz)).Position)
	tempCorners[2] = worldToScreen((cf * CFrame.new(-hx, hy, -hz)).Position)
	tempCorners[3] = worldToScreen((cf * CFrame.new(-hx, hy, hz)).Position)
	tempCorners[4] = worldToScreen((cf * CFrame.new(-hx, -hy, hz)).Position)
	tempCorners[5] = worldToScreen((cf * CFrame.new(hx, -hy, -hz)).Position)
	tempCorners[6] = worldToScreen((cf * CFrame.new(hx, hy, -hz)).Position)
	tempCorners[7] = worldToScreen((cf * CFrame.new(hx, hy, hz)).Position)
	tempCorners[8] = worldToScreen((cf * CFrame.new(hx, -hy, hz)).Position)

	local mins = min2(tempCorners, 8)
	local maxs = max2(tempCorners, 8)
	
	-- Clamp to viewport
	local topLeftX = max(0, min(viewportSize.X, floor(mins.X)))
	local topLeftY = max(0, min(viewportSize.Y, floor(mins.Y)))
	local bottomRightX = max(0, min(viewportSize.X, floor(maxs.X)))
	local bottomRightY = max(0, min(viewportSize.Y, floor(maxs.Y)))
	
	return {
		corners = {unpack(tempCorners, 1, 8)},
		topLeft = Vector2.new(topLeftX, topLeftY),
		topRight = Vector2.new(bottomRightX, topLeftY),
		bottomLeft = Vector2.new(topLeftX, bottomRightY),
		bottomRight = Vector2.new(bottomRightX, bottomRightY)
	}
end

local function parseColor(self, color, isOutline)
	if color == "Team Color" or (self.interface.sharedSettings.useTeamColor and not isOutline) then
		return self.teamColor
	end
	return color
end

-- esp object (optimized)
local EspObject = {}
EspObject.__index = EspObject

function EspObject.new(player, interface)
	local self = setmetatable({}, EspObject)
	self.player = player
	self.interface = interface
	self.teamColor = COLOR3_WHITE
	self.enabled = false
	self:Construct()
	return self
end

function EspObject:_create(class, properties)
	local drawing = Drawing.new(class)
	drawing.Visible = false
	drawing.ZIndex = 0
	for property, value in pairs(properties) do
		drawing[property] = value
	end
	self.bin[#self.bin + 1] = drawing
	return drawing
end

function EspObject:Construct()
	self.charCache = {}
	self.cacheCount = 0
	self.childCount = 0
	self.bin = {}
	self.drawings = {
		box3d = {
			{
				self:_create("Line", { Thickness = 1 }),
				self:_create("Line", { Thickness = 1 }),
				self:_create("Line", { Thickness = 1 })
			},
			{
				self:_create("Line", { Thickness = 1 }),
				self:_create("Line", { Thickness = 1 }),
				self:_create("Line", { Thickness = 1 })
			},
			{
				self:_create("Line", { Thickness = 1 }),
				self:_create("Line", { Thickness = 1 }),
				self:_create("Line", { Thickness = 1 })
			},
			{
				self:_create("Line", { Thickness = 1 }),
				self:_create("Line", { Thickness = 1 }),
				self:_create("Line", { Thickness = 1 })
			}
		},
		visible = {
			tracerOutline = self:_create("Line", { Thickness = 3 }),
			tracer = self:_create("Line", { Thickness = 1 }),
			boxFill = self:_create("Square", { Filled = true }),
			boxOutline = self:_create("Square", { Thickness = 3 }),
			box = self:_create("Square", { Thickness = 1 }),
			healthBarOutline = self:_create("Line", { Thickness = 3 }),
			healthBar = self:_create("Line", { Thickness = 1 }),
			healthText = self:_create("Text", { Center = true, Size = 13, Font = 2, Outline = true }),
			name = self:_create("Text", { Text = self.player.DisplayName or self.player.Name, Center = true, Size = 13, Font = 2, Outline = true }),
			distance = self:_create("Text", { Center = true, Size = 13, Font = 2, Outline = true }),
			weapon = self:_create("Text", { Center = true, Size = 13, Font = 2, Outline = true })
		},
		hidden = {
			arrowOutline = self:_create("Triangle", { Thickness = 3 }),
			arrow = self:_create("Triangle", { Filled = true })
		}
	}

	self.renderConnection = RunService.Heartbeat:Connect(function()
		self:Update()
		self:Render()
	end)
end

function EspObject:Destruct()
	if self.renderConnection then
		self.renderConnection:Disconnect()
		self.renderConnection = nil
	end

	for i = 1, #self.bin do
		pcall(function() self.bin[i]:Remove() end)
	end

	clear(self)
end

function EspObject:Update()
	local interface = self.interface
	local player = self.player
	
	-- Check master enable switch first
	local isFriendly = player.Team and localPlayer.Team and player.Team == localPlayer.Team
	local options = interface.teamSettings[isFriendly and "friendly" or "enemy"]
	
	-- Early exit if disabled
	if not options.enabled then
		self.enabled = false
		return
	end
	
	self.options = options
	self.teamColor = (player.Team and player.Team.TeamColor and player.Team.TeamColor.Color) or COLOR3_WHITE
	
	local character = player.Character
	if not character then
		self.enabled = false
		return
	end
	
	self.character = character
	
	-- Whitelist check
	local whitelist = interface.whitelist
	if #whitelist > 0 and not find(whitelist, player.UserId) then
		self.enabled = false
		return
	end
	
	-- Get health
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		self.health = humanoid.Health
		self.maxHealth = humanoid.MaxHealth
	else
		self.health = 100
		self.maxHealth = 100
	end
	
	-- Get weapon
	local tool = character:FindFirstChildOfClass("Tool")
	self.weapon = tool and tool.Name or "Unknown"
	
	local head = character:FindFirstChild("Head")
	if not head then
		self.enabled = false
		return
	end

	local _, onScreen, depth = worldToScreen(head.Position)
	self.onScreen = onScreen
	self.distance = depth
	self.enabled = true

	if interface.sharedSettings.limitDistance and depth > interface.sharedSettings.maxDistance then
		self.onScreen = false
		self.enabled = false
		return
	end

	if onScreen then
		-- Cache body parts
		local cache = self.charCache
		local children = character:GetChildren()
		local childrenCount = #children
		
		if self.childCount ~= childrenCount then
			local cacheIndex = 0
			for i = 1, childrenCount do
				local part = children[i]
				if part:IsA("BasePart") and BODY_PARTS[part.Name] then
					cacheIndex = cacheIndex + 1
					cache[cacheIndex] = part
				end
			end
			self.cacheCount = cacheIndex
			self.childCount = childrenCount
		end

		if self.cacheCount > 0 then
			local cframe, size = getBoundingBox(cache, self.cacheCount)
			self.corners = calculateCorners(cframe, size)
		end
	elseif options.offScreenArrow then
		local cframe = camera.CFrame
		local headPos = head.Position
		local objectSpace = cframe:PointToObjectSpace(headPos)
		local magnitude = objectSpace.Magnitude
		
		if magnitude > 0 then
			self.direction = Vector2.new(objectSpace.X, objectSpace.Z) / magnitude
		else
			self.direction = Vector2.new(0, -1)
		end
	end
end

function EspObject:Render()
	local enabled = self.enabled
	local onScreen = self.onScreen
	local visible = self.drawings.visible
	local box3d = self.drawings.box3d
	local options = self.options
	
	-- Early exit if not enabled
	if not enabled then
		for _, drawing in pairs(visible) do
			drawing.Visible = false
		end
		for i = 1, 4 do
			for j = 1, 3 do
				box3d[i][j].Visible = false
			end
		end
		return
	end
	
	local corners = self.corners
	if not corners then
		corners = {
			topLeft = VECTOR2_ZERO,
			topRight = VECTOR2_ZERO,
			bottomLeft = VECTOR2_ZERO,
			bottomRight = VECTOR2_ZERO,
			corners = {}
		}
	end

	-- Box
	local boxVisible = onScreen and options.box
	visible.box.Visible = boxVisible
	visible.boxOutline.Visible = boxVisible and options.boxOutline
	if boxVisible then
		local box = visible.box
		local topLeft = corners.topLeft
		local size = corners.bottomRight - topLeft
		box.Position = topLeft
		box.Size = size
		box.Color = parseColor(self, options.boxColor[1])
		box.Transparency = options.boxColor[2]

		if visible.boxOutline.Visible then
			local boxOutline = visible.boxOutline
			boxOutline.Position = topLeft
			boxOutline.Size = size
			boxOutline.Color = parseColor(self, options.boxOutlineColor[1], true)
			boxOutline.Transparency = options.boxOutlineColor[2]
		end
	end

	-- Box fill
	visible.boxFill.Visible = onScreen and options.boxFill
	if visible.boxFill.Visible then
		local boxFill = visible.boxFill
		local topLeft = corners.topLeft
		boxFill.Position = topLeft
		boxFill.Size = corners.bottomRight - topLeft
		boxFill.Color = parseColor(self, options.boxFillColor[1])
		boxFill.Transparency = options.boxFillColor[2]
	end

	-- Health bar
	local healthBarVisible = onScreen and options.healthBar
	visible.healthBar.Visible = healthBarVisible
	visible.healthBarOutline.Visible = healthBarVisible and options.healthBarOutline
	if healthBarVisible then
		local barFrom = corners.topLeft - HEALTH_BAR_OFFSET
		local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET
		local healthRatio = self.health / self.maxHealth

		local healthBar = visible.healthBar
		healthBar.To = barTo
		healthBar.From = barFrom:Lerp(barTo, 1 - healthRatio)
		healthBar.Color = lerpColor(options.dyingColor, options.healthyColor, healthRatio)

		if visible.healthBarOutline.Visible then
			local healthBarOutline = visible.healthBarOutline
			healthBarOutline.To = barTo + HEALTH_BAR_OUTLINE_OFFSET
			healthBarOutline.From = barFrom - HEALTH_BAR_OUTLINE_OFFSET
			healthBarOutline.Color = parseColor(self, options.healthBarOutlineColor[1], true)
			healthBarOutline.Transparency = options.healthBarOutlineColor[2]
		end
	end

	-- Health text
	visible.healthText.Visible = onScreen and options.healthText
	if visible.healthText.Visible then
		local healthText = visible.healthText
		healthText.Text = round(self.health) .. "hp"
		healthText.Color = parseColor(self, options.healthTextColor[1])
		healthText.Transparency = options.healthTextColor[2]
		healthText.OutlineColor = parseColor(self, options.healthTextOutlineColor, true)
		
		local barFrom = corners.topLeft - HEALTH_BAR_OFFSET
		local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET
		local healthRatio = self.health / self.maxHealth
		local textBounds = healthText.TextBounds
		local offset = textBounds and Vector2.new(textBounds.X * 0.5, textBounds.Y * 0.5) or VECTOR2_ZERO
		healthText.Position = barFrom:Lerp(barTo, 1 - healthRatio) - offset - HEALTH_TEXT_OFFSET
	end

	-- Name
	visible.name.Visible = onScreen and options.name
	if visible.name.Visible then
		local name = visible.name
		name.Color = parseColor(self, options.nameColor[1])
		name.Transparency = options.nameColor[2]
		name.OutlineColor = parseColor(self, options.nameOutlineColor, true)
		local textHeight = name.TextBounds and name.TextBounds.Y or 0
		name.Position = (corners.topLeft + corners.topRight) * 0.5 - Vector2.new(0, textHeight) - NAME_OFFSET
	end

	-- Distance
	visible.distance.Visible = onScreen and self.distance and options.distance
	if visible.distance.Visible then
		local distance = visible.distance
		distance.Text = round(self.distance) .. " studs"
		distance.Color = parseColor(self, options.distanceColor[1])
		distance.Transparency = options.distanceColor[2]
		-- distance.OutlineColor = parseColor(self, options.distanceOutlineColor, true)
		distance.Position = (corners.bottomLeft + corners.bottomRight) * 0.5 + DISTANCE_OFFSET
	end

	-- Weapon
	visible.weapon.Visible = onScreen and options.weapon
	if visible.weapon.Visible then
		local weapon = visible.weapon
		weapon.Text = self.weapon
		weapon.Color = parseColor(self, options.weaponColor[1])
		weapon.Transparency = options.weaponColor[2]
		weapon.OutlineColor = parseColor(self, options.weaponOutlineColor, true)
		
		local yOffset = 0
		if visible.distance.Visible then
			yOffset = visible.distance.TextBounds and visible.distance.TextBounds.Y or 0
		end
		weapon.Position = (corners.bottomLeft + corners.bottomRight) * 0.5 + DISTANCE_OFFSET + Vector2.new(0, yOffset)
	end

	-- Tracer
	local tracerVisible = onScreen and options.tracer
	visible.tracer.Visible = tracerVisible
	visible.tracerOutline.Visible = tracerVisible and options.tracerOutline
	if tracerVisible then
		local tracerOrigin = options.tracerOrigin
		local from = tracerOrigin == "Middle" and viewportCenter or
		             tracerOrigin == "Top" and Vector2.new(viewportCenter.X, 0) or
		             Vector2.new(viewportCenter.X, viewportSize.Y)
		
		local to = (corners.bottomLeft + corners.bottomRight) * 0.5
		
		visible.tracer.Color = parseColor(self, options.tracerColor[1])
		visible.tracer.Transparency = options.tracerColor[2]
		visible.tracer.To = to
		visible.tracer.From = from

		if visible.tracerOutline.Visible then
			visible.tracerOutline.Color = parseColor(self, options.tracerOutlineColor[1], true)
			visible.tracerOutline.Transparency = options.tracerOutlineColor[2]
			visible.tracerOutline.To = to
			visible.tracerOutline.From = from
		end
	end

	-- 3D box
	local box3dEnabled = onScreen and options.box3d
	if box3dEnabled then
		local cornersTable = corners.corners
		for fi = 1, 4 do
			local face = box3d[fi]
			local nextIndex = fi % 4 + 1
			local farIndex = fi + 4
			local farNextIndex = (fi % 4) + 5
			
			for i = 1, 3 do
				face[i].Visible = true
				face[i].Color = parseColor(self, options.box3dColor[1])
				face[i].Transparency = options.box3dColor[2]
			end
			
			face[1].From = cornersTable[fi]
			face[1].To = cornersTable[nextIndex]
			face[2].From = cornersTable[nextIndex]
			face[2].To = cornersTable[farNextIndex]
			face[3].From = cornersTable[farNextIndex]
			face[3].To = cornersTable[farIndex]
		end
	else
		for fi = 1, 4 do
			for i = 1, 3 do
				box3d[fi][i].Visible = false
			end
		end
	end
end

-- cham object (optimized)
local ChamObject = {}
ChamObject.__index = ChamObject

function ChamObject.new(player, interface)
	local self = setmetatable({}, ChamObject)
	self.player = player
	self.interface = interface
	self.teamColor = COLOR3_WHITE
	self:Construct()
	return self
end

function ChamObject:Construct()
	self.highlight = Instance.new("Highlight", container)
	self.highlight.Enabled = false
	self.updateConnection = RunService.Heartbeat:Connect(function()
		self:Update()
	end)
end

function ChamObject:Destruct()
	if self.updateConnection then
		self.updateConnection:Disconnect()
		self.updateConnection = nil
	end
	if self.highlight then
		self.highlight:Destroy()
		self.highlight = nil
	end
	clear(self)
end

function ChamObject:Update()
	local interface = self.interface
	local player = self.player
	local character = player.Character
	
	if not character then
		self.highlight.Enabled = false
		return
	end
	
	local isFriendly = player.Team and localPlayer.Team and player.Team == localPlayer.Team
	local options = interface.teamSettings[isFriendly and "friendly" or "enemy"]
	
	-- Check master enable switch
	if not options.enabled then
		self.highlight.Enabled = false
		return
	end
	
	local whitelist = interface.whitelist
	local enabled = not (#whitelist > 0 and not find(whitelist, player.UserId))

	self.highlight.Enabled = enabled and options.chams
	if self.highlight.Enabled then
		self.teamColor = (player.Team and player.Team.TeamColor and player.Team.TeamColor.Color) or COLOR3_WHITE
		self.highlight.Adornee = character
		self.highlight.FillColor = parseColor(self, options.chamsFillColor[1])
		self.highlight.FillTransparency = options.chamsFillColor[2]
		self.highlight.OutlineColor = parseColor(self, options.chamsOutlineColor[1], true)
		self.highlight.OutlineTransparency = options.chamsOutlineColor[2]
		self.highlight.DepthMode = options.chamsVisibleOnly and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
	end
end

-- instance class (optimized)
local InstanceObject = {}
InstanceObject.__index = InstanceObject

function InstanceObject.new(instance, options)
	local self = setmetatable({}, InstanceObject)
	self.instance = instance
	self.options = options
	self:Construct()
	return self
end

function InstanceObject:Construct()
	local options = self.options
	options.enabled = options.enabled == nil and true or options.enabled
	options.text = options.text or "{name}"
	options.textColor = options.textColor or { COLOR3_WHITE, 1 }
	options.textOutline = options.textOutline == nil and true or options.textOutline
	options.textOutlineColor = options.textOutlineColor or COLOR3_BLACK
	options.textSize = options.textSize or 13
	options.textFont = options.textFont or 2
	options.limitDistance = options.limitDistance or false
	options.maxDistance = options.maxDistance or 150

	self.text = Drawing.new("Text")
	self.text.Center = true
	self.text.ZIndex = 0
	self.text.Visible = false

	self.renderConnection = RunService.Heartbeat:Connect(function()
		self:Render()
	end)
end

function InstanceObject:Destruct()
	if self.renderConnection then
		self.renderConnection:Disconnect()
		self.renderConnection = nil
	end
	if self.text then
		pcall(function() self.text:Remove() end)
		self.text = nil
	end
end

function InstanceObject:Render()
	local instance = self.instance
	if not instance or not instance.Parent then
		return self:Destruct()
	end

	local options = self.options
	if not options.enabled then
		self.text.Visible = false
		return
	end

	local cf = instance:IsA("Model") and instance:GetPivot() or instance:IsA("BasePart") and instance.CFrame or CFrame.new()
	local world = cf.Position
	local position, visible, depth = worldToScreen(world)
	
	if options.limitDistance and depth > options.maxDistance then
		visible = false
	end

	self.text.Visible = visible
	if visible then
		self.text.Position = position
		self.text.Color = options.textColor[1]
		self.text.Transparency = options.textColor[2]
		self.text.Outline = options.textOutline
		self.text.OutlineColor = options.textOutlineColor
		self.text.Size = options.textSize
		self.text.Font = options.textFont
		self.text.Text = options.text
			:gsub("{name}", instance.Name)
			:gsub("{distance}", tostring(round(depth)))
			:gsub("{position}", tostring(world))
	end
end

-- interface (optimized)
local EspInterface = {
	_hasLoaded = false,
	_objectCache = {},
	whitelist = {},
	sharedSettings = {
		textSize = 13,
		textFont = 2,
		limitDistance = false,
		maxDistance = 150,
		useTeamColor = false
	},
	teamSettings = {
		enemy = {
			enabled = true,
			box = true,
			boxColor = { Color3.new(1,0,0), 1 },
			boxOutline = true,
			boxOutlineColor = { COLOR3_BLACK, 1 },
			boxFill = false,
			boxFillColor = { Color3.new(1,0,0), 0.5 },
			healthBar = true,
			healthyColor = Color3.new(0,1,0),
			dyingColor = Color3.new(1,0,0),
			healthBarOutline = true,
			healthBarOutlineColor = { COLOR3_BLACK, 0.5 },
			healthText = false,
			healthTextColor = { COLOR3_WHITE, 1 },
			healthTextOutline = true,
			healthTextOutlineColor = COLOR3_BLACK,
			box3d = false,
			box3dColor = { Color3.new(1,0,0), 1 },
			name = true,
			nameColor = { COLOR3_WHITE, 1 },
			nameOutline = true,
			nameOutlineColor = COLOR3_BLACK,
			weapon = false,
			weaponColor = { COLOR3_WHITE, 1 },
			weaponOutline = true,
			weaponOutlineColor = { COLOR3_BLACK, 1 },
			distance = true,
			distanceColor = { COLOR3_WHITE, 1 },
			distanceOutline = true,
			distanceOutlineColor = { COLOR3_BLACK, 1 },
			tracer = false,
			tracerOrigin = "Bottom",
			tracerColor = { Color3.new(1,0,0), 1 },
			tracerOutline = true,
			tracerOutlineColor = { COLOR3_BLACK, 1 },
			offScreenArrow = false,
			offScreenArrowColor = { COLOR3_WHITE, 1 },
			offScreenArrowSize = 15,
			offScreenArrowRadius = 150,
			offScreenArrowOutline = true,
			offScreenArrowOutlineColor = { COLOR3_BLACK, 1 },
			chams = false,
			chamsVisibleOnly = false,
			chamsFillColor = { Color3.new(0.2, 0.2, 0.2), 0.5 },
			chamsOutlineColor = { Color3.new(1,0,0), 0 }
		},
		friendly = {
			enabled = false,
			box = false,
			boxColor = { Color3.new(0,1,0), 1 },
			boxOutline = true,
			boxOutlineColor = { COLOR3_BLACK, 1 },
			boxFill = false,
			boxFillColor = { Color3.new(0,1,0), 0.5 },
			healthBar = false,
			healthyColor = Color3.new(0,1,0),
			dyingColor = Color3.new(1,0,0),
			healthBarOutline = true,
			healthBarOutlineColor = { COLOR3_BLACK, 0.5 },
			healthText = false,
			healthTextColor = { COLOR3_WHITE, 1 },
			healthTextOutline = true,
			healthTextOutlineColor = COLOR3_BLACK,
			box3d = false,
			box3dColor = { Color3.new(0,1,0), 1 },
			name = false,
			nameColor = { COLOR3_WHITE, 1 },
			nameOutline = true,
			nameOutlineColor = COLOR3_BLACK,
			weapon = false,
			weaponColor = { COLOR3_WHITE, 1 },
			weaponOutline = true,
			weaponOutlineColor = { COLOR3_BLACK, 1 },
			distance = false,
			distanceColor = { COLOR3_WHITE, 1 },
			distanceOutline = true,
			distanceOutlineColor = { COLOR3_BLACK, 1 },
			tracer = false,
			tracerOrigin = "Bottom",
			tracerColor = { Color3.new(0,1,0), 1 },
			tracerOutline = true,
			tracerOutlineColor = { COLOR3_BLACK, 1 },
			offScreenArrow = false,
			offScreenArrowColor = { COLOR3_WHITE, 1 },
			offScreenArrowSize = 15,
			offScreenArrowRadius = 150,
			offScreenArrowOutline = true,
			offScreenArrowOutlineColor = { COLOR3_BLACK, 1 },
			chams = false,
			chamsVisibleOnly = false,
			chamsFillColor = { Color3.new(0.2, 0.2, 0.2), 0.5 },
			chamsOutlineColor = { Color3.new(0,1,0), 0 }
		}
	}
}

-- Update viewport on camera changes
RunService.Heartbeat:Connect(function()
	if camera then
		viewportSize = camera.ViewportSize
		viewportCenter = viewportSize * 0.5
	end
end)

function EspInterface.AddInstance(instance, options)
	local cache = EspInterface._objectCache
	if cache[instance] then
		warn("Instance handler already exists.")
	else
		cache[instance] = { InstanceObject.new(instance, options) }
	end
	return cache[instance][1]
end

function EspInterface.Load()
	assert(not EspInterface._hasLoaded, "Esp has already been loaded.")

	local function createObject(player)
		if player == localPlayer then return end
		EspInterface._objectCache[player] = {
			EspObject.new(player, EspInterface),
			ChamObject.new(player, EspInterface)
		}
	end

	local function removeObject(player)
		local object = EspInterface._objectCache[player]
		if object then
			for i = 1, #object do
				if object[i] and object[i].Destruct then
					pcall(function() object[i]:Destruct() end)
				end
			end
			EspInterface._objectCache[player] = nil
		end
	end

	local plrs = Players:GetPlayers()
	for i = 1, #plrs do
		createObject(plrs[i])
	end

	EspInterface.playerAdded = Players.PlayerAdded:Connect(createObject)
	EspInterface.playerRemoving = Players.PlayerRemoving:Connect(removeObject)
	EspInterface._hasLoaded = true
end

function EspInterface.Unload()
	assert(EspInterface._hasLoaded, "Esp has not been loaded yet.")

	for index, object in next, EspInterface._objectCache do
		for i = 1, #object do
			if object[i] and object[i].Destruct then
				pcall(function() object[i]:Destruct() end)
			end
		end
		EspInterface._objectCache[index] = nil
	end

	if EspInterface.playerAdded then EspInterface.playerAdded:Disconnect() EspInterface.playerAdded = nil end
	if EspInterface.playerRemoving then EspInterface.playerRemoving:Disconnect() EspInterface.playerRemoving = nil end
	EspInterface._hasLoaded = false
end

return EspInterface