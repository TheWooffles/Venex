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
local abs = math.abs
local round = math.round or floor
local sin = math.sin
local cos = math.cos
local clear = table.clear or function(t) for k in pairs(t) do t[k] = nil end end
local unpack = table.unpack
local find = table.find
local insert = table.insert

-- pre-allocated tables for reuse
local tempParts = {}
local tempCorners = {}

-- optimized instance methods
local function isA(instance, className)
	return instance and instance:IsA(className)
end

local function findFirstChild(parent, name)
	return parent and parent:FindFirstChild(name)
end

local function findFirstChildOfClass(parent, className)
	return parent and parent:FindFirstChildOfClass(className)
end

local function getPivotSafe(inst)
	if not inst then return CFrame.new() end
	if inst.GetPivot then
		local ok, v = pcall(inst.GetPivot, inst)
		if ok and v then return v end
	end
	if inst.PrimaryPart then
		return inst.PrimaryPart.CFrame
	end
	if inst:IsA("BasePart") then
		return inst.CFrame
	end
	return CFrame.new()
end

-- CFrame/Vector helpers (optimized)
local function lerpColor(a, b, t)
	if not a or not b then return a or b or COLOR3_WHITE end
	return a:Lerp(b, t)
end

local function min2(corners, count)
	local minx, miny = math.huge, math.huge
	for i = 1, count do
		local v = corners[i]
		if v then
			if v.X < minx then minx = v.X end
			if v.Y < miny then miny = v.Y end
		end
	end
	return Vector2.new(minx, miny)
end

local function max2(corners, count)
	local maxx, maxy = -math.huge, -math.huge
	for i = 1, count do
		local v = corners[i]
		if v then
			if v.X > maxx then maxx = v.X end
			if v.Y > maxy then maxy = v.Y end
		end
	end
	return Vector2.new(maxx, maxy)
end

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

local function isBodyPart(name)
	return BODY_PARTS[name] == true
end

-- Optimized bounding box calculation
local function getBoundingBox(parts)
	local minx, miny, minz = math.huge, math.huge, math.huge
	local maxx, maxy, maxz = -math.huge, -math.huge, -math.huge
	
	for i = 1, #parts do
		local part = parts[i]
		if part and part:IsA("BasePart") then
			local pos = part.Position
			local size = part.Size
			local halfSize = size * 0.5
			
			local ax, ay, az = pos.X - halfSize.X, pos.Y - halfSize.Y, pos.Z - halfSize.Z
			local bx, by, bz = pos.X + halfSize.X, pos.Y + halfSize.Y, pos.Z + halfSize.Z
			
			if ax < minx then minx = ax end
			if ay < miny then miny = ay end
			if az < minz then minz = az end
			if bx > maxx then maxx = bx end
			if by > maxy then maxy = by end
			if bz > maxz then maxz = bz end
		end
	end

	if minx == math.huge then
		return CFrame.new(), VECTOR3_ZERO
	end

	local centerX, centerY, centerZ = (minx + maxx) * 0.5, (miny + maxy) * 0.5, (minz + maxz) * 0.5
	return CFrame.new(centerX, centerY, centerZ, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	       Vector3.new(maxx - minx, maxy - miny, maxz - minz)
end

-- Cache viewport size updates
local viewportSize = Vector2.new(1920, 1080)
RunService.Heartbeat:Connect(function()
	if camera then
		viewportSize = camera.ViewportSize
	end
end)

local function worldToScreen(world)
	if not camera then return VECTOR2_ZERO, false, math.huge end
	local screenPoint, onScreen = camera:WorldToViewportPoint(world)
	return Vector2.new(screenPoint.X, screenPoint.Y), onScreen, screenPoint.Z
end

-- Optimized corner calculation with reusable table
local function calculateCorners(cframe, size)
	local halfSize = size * 0.5
	local cornerCount = 0
	
	for i = 1, 8 do
		local vertex = VERTICES[i]
		local worldPos = cframe:PointToWorldSpace(halfSize * vertex)
		cornerCount = cornerCount + 1
		tempCorners[cornerCount] = worldToScreen(worldPos)
	end

	local mins = min2(tempCorners, cornerCount)
	local maxs = max2(tempCorners, cornerCount)
	
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

local function rotateVector(vector, radians)
	local x, y = vector.X, vector.Y
	local c, s = cos(radians), sin(radians)
	return Vector2.new(x * c - y * s, x * s + y * c)
end

local function parseColor(self, color, isOutline)
	if color == "Team Color" or (self.interface.sharedSettings.useTeamColor and not isOutline) then
		return self.teamColor or COLOR3_WHITE
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
	self:Construct()
	return self
end

function EspObject:_create(class, properties)
	local drawing = Drawing.new(class)
	drawing.ZIndex = 0  -- Set display order to 0
	for property, value in next, properties do
		pcall(function() drawing[property] = value end)
	end
	self.bin[#self.bin + 1] = drawing
	return drawing
end

function EspObject:Construct()
	self.charCache = {}
	self.childCount = 0
	self.bin = {}
	self.drawings = {
		box3d = {
			{
				self:_create("Line", { Thickness = 1, Visible = false, ZIndex = 0 }),
				self:_create("Line", { Thickness = 1, Visible = false, ZIndex = 0 }),
				self:_create("Line", { Thickness = 1, Visible = false, ZIndex = 0 })
			},
			{
				self:_create("Line", { Thickness = 1, Visible = false, ZIndex = 0 }),
				self:_create("Line", { Thickness = 1, Visible = false, ZIndex = 0 }),
				self:_create("Line", { Thickness = 1, Visible = false, ZIndex = 0 })
			},
			{
				self:_create("Line", { Thickness = 1, Visible = false, ZIndex = 0 }),
				self:_create("Line", { Thickness = 1, Visible = false, ZIndex = 0 }),
				self:_create("Line", { Thickness = 1, Visible = false, ZIndex = 0 })
			},
			{
				self:_create("Line", { Thickness = 1, Visible = false, ZIndex = 0 }),
				self:_create("Line", { Thickness = 1, Visible = false, ZIndex = 0 }),
				self:_create("Line", { Thickness = 1, Visible = false, ZIndex = 0 })
			}
		},
		visible = {
			tracerOutline = self:_create("Line", { Thickness = 3, Visible = false, ZIndex = 0 }),
			tracer = self:_create("Line", { Thickness = 1, Visible = false, ZIndex = 0 }),
			boxFill = self:_create("Square", { Filled = true, Visible = false, ZIndex = 0 }),
			boxOutline = self:_create("Square", { Thickness = 3, Visible = false, ZIndex = 0 }),
			box = self:_create("Square", { Thickness = 1, Visible = false, ZIndex = 0 }),
			healthBarOutline = self:_create("Line", { Thickness = 3, Visible = false, ZIndex = 0 }),
			healthBar = self:_create("Line", { Thickness = 1, Visible = false, ZIndex = 0 }),
			healthText = self:_create("Text", { Center = true, Visible = false, ZIndex = 0 }),
			name = self:_create("Text", { Text = self.player.DisplayName or self.player.Name, Center = true, Visible = false, ZIndex = 0 }),
			distance = self:_create("Text", { Center = true, Visible = false, ZIndex = 0 }),
			weapon = self:_create("Text", { Center = true, Visible = false, ZIndex = 0 })
		},
		hidden = {
			arrowOutline = self:_create("Triangle", { Thickness = 3, Visible = false, ZIndex = 0 }),
			arrow = self:_create("Triangle", { Filled = true, Visible = false, ZIndex = 0 })
		}
	}

	self.renderConnection = RunService.Heartbeat:Connect(function(deltaTime)
		self:Update(deltaTime)
		self:Render(deltaTime)
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
	
	-- Cache team color once per update
	self.teamColor = interface.getTeamColor(player) or COLOR3_WHITE
	
	local isFriendly = interface.isFriendly(player)
	self.options = interface.teamSettings[isFriendly and "friendly" or "enemy"]
	self.character = interface.getCharacter(player)
	self.health, self.maxHealth = interface.getHealth(player)
	self.weapon = interface.getWeapon(player)
	
	local whitelist = interface.whitelist
	self.enabled = self.options.enabled and self.character and not
		(#whitelist > 0 and not find(whitelist, player.UserId))

	local head = self.enabled and findFirstChild(self.character, "Head")
	if not head then
		self.charCache = {}
		self.onScreen = false
		return
	end

	local _, onScreen, depth = worldToScreen(head.Position)
	self.onScreen = onScreen
	self.distance = depth

	if interface.sharedSettings.limitDistance and depth > interface.sharedSettings.maxDistance then
		self.onScreen = false
	end

	if self.onScreen then
		local cache = self.charCache
		local character = self.character
		local children = character:GetChildren()
		local childrenCount = #children
		
		if not cache[1] or self.childCount ~= childrenCount then
			clear(cache)
			local cacheIndex = 0

			for i = 1, childrenCount do
				local part = children[i]
				if part and part:IsA("BasePart") and isBodyPart(part.Name) then
					cacheIndex = cacheIndex + 1
					cache[cacheIndex] = part
				end
			end

			self.childCount = childrenCount
		end

		local cframe, size = getBoundingBox(cache)
		self.corners = calculateCorners(cframe, size)
	elseif self.options.offScreenArrow then
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
	local onScreen = self.onScreen
	local enabled = self.enabled
	local visible = self.drawings.visible
	local hidden = self.drawings.hidden
	local box3d = self.drawings.box3d
	local options = self.options
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
	local boxVisible = enabled and onScreen and options.box
	visible.box.Visible = boxVisible
	visible.boxOutline.Visible = boxVisible and options.boxOutline
	if boxVisible then
		local box = visible.box
		local topLeft = corners.topLeft
		box.Position = topLeft
		box.Size = corners.bottomRight - topLeft
		box.Color = parseColor(self, options.boxColor[1])
		box.Transparency = options.boxColor[2]

		if visible.boxOutline.Visible then
			local boxOutline = visible.boxOutline
			boxOutline.Position = topLeft
			boxOutline.Size = box.Size
			boxOutline.Color = parseColor(self, options.boxOutlineColor[1], true)
			boxOutline.Transparency = options.boxOutlineColor[2]
		end
	end

	-- Box fill
	local boxFillVisible = enabled and onScreen and options.boxFill
	visible.boxFill.Visible = boxFillVisible
	if boxFillVisible then
		local boxFill = visible.boxFill
		local topLeft = corners.topLeft
		boxFill.Position = topLeft
		boxFill.Size = corners.bottomRight - topLeft
		boxFill.Color = parseColor(self, options.boxFillColor[1])
		boxFill.Transparency = options.boxFillColor[2]
	end

	-- Health bar
	local healthBarVisible = enabled and onScreen and options.healthBar
	visible.healthBar.Visible = healthBarVisible
	visible.healthBarOutline.Visible = healthBarVisible and options.healthBarOutline
	if healthBarVisible then
		local barFrom = corners.topLeft - HEALTH_BAR_OFFSET
		local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET
		local healthRatio = (self.health or 0) / (self.maxHealth or 1)

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
	local healthTextVisible = enabled and onScreen and options.healthText
	visible.healthText.Visible = healthTextVisible
	if healthTextVisible then
		local healthText = visible.healthText
		healthText.Text = round(self.health or 0) .. "hp"
		healthText.Size = self.interface.sharedSettings.textSize
		healthText.Font = self.interface.sharedSettings.textFont
		healthText.Color = parseColor(self, options.healthTextColor[1])
		healthText.Transparency = options.healthTextColor[2]
		healthText.Outline = options.healthTextOutline
		healthText.OutlineColor = parseColor(self, options.healthTextOutlineColor, true)
		
		local barFrom = corners.topLeft - HEALTH_BAR_OFFSET
		local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET
		local healthRatio = (self.health or 0) / (self.maxHealth or 1)
		local textBounds = healthText.TextBounds
		local offset = textBounds and Vector2.new(textBounds.X, textBounds.Y) * 0.5 or VECTOR2_ZERO
		healthText.Position = barFrom:Lerp(barTo, 1 - healthRatio) - offset - HEALTH_TEXT_OFFSET
	end

	-- Name
	local nameVisible = enabled and onScreen and options.name
	visible.name.Visible = nameVisible
	if nameVisible then
		local name = visible.name
		name.Size = self.interface.sharedSettings.textSize
		name.Font = self.interface.sharedSettings.textFont
		name.Color = parseColor(self, options.nameColor[1])
		name.Transparency = options.nameColor[2]
		name.Outline = options.nameOutline
		name.OutlineColor = parseColor(self, options.nameOutlineColor, true)
		local textHeight = name.TextBounds and name.TextBounds.Y or 0
		name.Position = (corners.topLeft + corners.topRight) * 0.5 - Vector2.new(0, textHeight) - NAME_OFFSET
	end

	-- Distance
	local distanceVisible = enabled and onScreen and self.distance and options.distance
	visible.distance.Visible = distanceVisible
	if distanceVisible then
		local distance = visible.distance
		distance.Text = round(self.distance or 0) .. " studs"
		distance.Size = self.interface.sharedSettings.textSize
		distance.Font = self.interface.sharedSettings.textFont
		distance.Color = parseColor(self, options.distanceColor[1])
		distance.Transparency = options.distanceColor[2]
		distance.Outline = options.distanceOutline
		distance.OutlineColor = parseColor(self, options.distanceOutlineColor, true)
		distance.Position = (corners.bottomLeft + corners.bottomRight) * 0.5 + DISTANCE_OFFSET
	end

	-- Weapon
	local weaponVisible = enabled and onScreen and options.weapon
	visible.weapon.Visible = weaponVisible
	if weaponVisible then
		local weapon = visible.weapon
		weapon.Text = tostring(self.weapon or "Unknown")
		weapon.Size = self.interface.sharedSettings.textSize
		weapon.Font = self.interface.sharedSettings.textFont
		weapon.Color = parseColor(self, options.weaponColor[1])
		weapon.Transparency = options.weaponColor[2]
		weapon.Outline = options.weaponOutline
		weapon.OutlineColor = parseColor(self, options.weaponOutlineColor, true)
		
		local yOffset = 0
		if distanceVisible then
			local distanceText = visible.distance
			yOffset = distanceText.TextBounds and distanceText.TextBounds.Y or 0
		end
		weapon.Position = (corners.bottomLeft + corners.bottomRight) * 0.5 + DISTANCE_OFFSET + Vector2.new(0, yOffset)
	end

	-- Tracer
	local tracerVisible = enabled and onScreen and options.tracer
	visible.tracer.Visible = tracerVisible
	visible.tracerOutline.Visible = tracerVisible and options.tracerOutline
	if tracerVisible then
		local tracerOrigin = options.tracerOrigin
		local from
		if tracerOrigin == "Middle" then
			from = viewportSize * 0.5
		elseif tracerOrigin == "Top" then
			from = viewportSize * Vector2.new(0.5, 0)
		elseif tracerOrigin == "Bottom" then
			from = viewportSize * Vector2.new(0.5, 1)
		else
			from = viewportSize * 0.5
		end
		
		local to = (corners.bottomLeft + corners.bottomRight) * 0.5
		
		local tracer = visible.tracer
		tracer.Color = parseColor(self, options.tracerColor[1])
		tracer.Transparency = options.tracerColor[2]
		tracer.To = to
		tracer.From = from

		if visible.tracerOutline.Visible then
			local tracerOutline = visible.tracerOutline
			tracerOutline.Color = parseColor(self, options.tracerOutlineColor[1], true)
			tracerOutline.Transparency = options.tracerOutlineColor[2]
			tracerOutline.To = to
			tracerOutline.From = from
		end
	end

	-- 3D box faces
	local box3dEnabled = enabled and onScreen and options.box3d
	if box3dEnabled then
		local cornersTable = corners.corners
		for fi = 1, 4 do
			local face = box3d[fi]
			local nextIndex = fi == 4 and 1 or fi + 1
			local farIndex = fi + 4
			local farNextIndex = fi == 4 and 5 or fi + 5
			
			for i = 1, 3 do
				local line = face[i]
				line.Visible = true
				line.Color = parseColor(self, options.box3dColor[1])
				line.Transparency = options.box3dColor[2]
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
			local face = box3d[fi]
			for i = 1, 3 do
				face[i].Visible = false
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
	local highlight = self.highlight
	local interface = self.interface
	local player = self.player
	local character = interface.getCharacter(player)
	
	-- Cache team color
	self.teamColor = interface.getTeamColor(player) or COLOR3_WHITE
	
	local isFriendly = interface.isFriendly(player)
	local options = interface.teamSettings[isFriendly and "friendly" or "enemy"]
	local whitelist = interface.whitelist
	local enabled = options.enabled and character and not
		(#whitelist > 0 and not find(whitelist, player.UserId))

	highlight.Enabled = enabled and options.chams
	if highlight.Enabled then
		highlight.Adornee = character
		highlight.FillColor = parseColor(self, options.chamsFillColor[1])
		highlight.FillTransparency = options.chamsFillColor[2]
		highlight.OutlineColor = parseColor(self, options.chamsOutlineColor[1], true)
		highlight.OutlineTransparency = options.chamsOutlineColor[2]
		highlight.DepthMode = options.chamsVisibleOnly and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
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

	self.renderConnection = RunService.Heartbeat:Connect(function(deltaTime)
		self:Render(deltaTime)
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

	local text = self.text
	local options = self.options
	if not options.enabled then
		text.Visible = false
		return
	end

	local worldCFrame = getPivotSafe(instance)
	local world = worldCFrame.Position
	local position, visible, depth = worldToScreen(world)
	if options.limitDistance and depth > options.maxDistance then
		visible = false
	end

	text.Visible = visible
	if visible then
		text.Position = position
		text.Color = options.textColor[1]
		text.Transparency = options.textColor[2]
		text.Outline = options.textOutline
		text.OutlineColor = options.textOutlineColor
		text.Size = options.textSize
		text.Font = options.textFont
		text.Text = options.text
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

-- Game-specific functions (optimized with caching)
function EspInterface.getWeapon(player)
	local char = player and player.Character
	if char then
		local children = char:GetChildren()
		for i = 1, #children do
			local child = children[i]
			if child:IsA("Tool") then
				return child.Name
			end
		end
	end
	local backpack = player and player:FindFirstChildOfClass("Backpack")
	if backpack then
		local tools = backpack:GetChildren()
		for i = 1, #tools do
			local tool = tools[i]
			if tool:IsA("Tool") then
				return "[Backpack] " .. tool.Name
			end
		end
	end
	return "Unknown"
end

function EspInterface.isFriendly(player)
	return player.Team and localPlayer and player.Team == localPlayer.Team
end

function EspInterface.getTeamColor(player)
	return player.Team and player.Team.TeamColor and player.Team.TeamColor.Color
end

function EspInterface.getCharacter(player)
	return player and player.Character
end

function EspInterface.getHealth(player)
	local character = player and EspInterface.getCharacter(player)
	local humanoid = character and findFirstChildOfClass(character, "Humanoid")
	if humanoid then
		return humanoid.Health, humanoid.MaxHealth
	end
	return 100, 100
end

return EspInterface