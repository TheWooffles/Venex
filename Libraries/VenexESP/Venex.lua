-- services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- variables
local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local viewportSize = camera and camera.ViewportSize or Vector2.new(1920, 1080)
local container = Instance.new("Folder", (gethui and gethui() or game:GetService("CoreGui")))

-- locals / helpers (safer wrappers)
local floor = math.floor
local round = math.round or math.floor -- fallback
local sin = math.sin
local cos = math.cos
local clear = table.clear or function(t) for k in pairs(t) do t[k] = nil end end
local unpack = table.unpack
local find = table.find
local create = table.create or function(n, val) local t = {}; for i=1,n do t[i] = val end; return t end

-- safer wrappers for instance methods (keeps original call style like isA(obj, "Class"))
local function isA(instance, className)
	return instance and instance:IsA(className)
end

local function getChildren(instance)
	return instance and instance:GetChildren() or {}
end

local function findFirstChild(parent, name)
	return parent and parent:FindFirstChild(name)
end

local function findFirstChildOfClass(parent, className)
	return parent and parent:FindFirstChildOfClass(className)
end

local function getPivotSafe(inst)
	-- prefer :GetPivot() if available (Model), else PrimaryPart, else try GetModelCFrame
	if not inst then return CFrame.new() end
	if inst.GetPivot then
		local ok, v = pcall(inst.GetPivot, inst)
		if ok and v then return v end
	end
	if inst.PrimaryPart then
		return inst.PrimaryPart.CFrame
	end
	if inst.GetModelCFrame then
		local ok, v = pcall(inst.GetModelCFrame, inst)
		if ok and v then return v end
	end
	-- fallback: use instance.Position if a BasePart (rare for models)
	if inst:IsA("BasePart") then
		return inst.CFrame
	end
	return CFrame.new()
end

-- CFrame/Vector helpers
local function pointToObjectSpace(cframe, point)
	return cframe:PointToObjectSpace(point)
end

local function lerpColor(a, b, t)
	-- a:Lerp(b, t)
	if not a or not b then return a or b or Color3.new(1,1,1) end
	return a:Lerp(b, t)
end

local function min2(first, ...)
	assert(first, "min2 requires at least one Vector2")
	local minx, miny = first.X, first.Y
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if v then
			if v.X < minx then minx = v.X end
			if v.Y < miny then miny = v.Y end
		end
	end
	return Vector2.new(minx, miny)
end

local function max2(first, ...)
	assert(first, "max2 requires at least one Vector2")
	local maxx, maxy = first.X, first.Y
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if v then
			if v.X > maxx then maxx = v.X end
			if v.Y > maxy then maxy = v.Y end
		end
	end
	return Vector2.new(maxx, maxy)
end

local function lerp2(a, b, t)
	return a:Lerp(b, t)
end

-- constants
local HEALTH_BAR_OFFSET = Vector2.new(5, 0)
local HEALTH_TEXT_OFFSET = Vector2.new(3, 0)
local HEALTH_BAR_OUTLINE_OFFSET = Vector2.new(0, 1)
local NAME_OFFSET = Vector2.new(0, 2)
local DISTANCE_OFFSET = Vector2.new(0, 2)
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

-- functions
local function isBodyPart(name)
	return name == "Head" or name:find("Torso") or name:find("Leg") or name:find("Arm")
end

local function getBoundingBox(parts)
	local minv, maxv
	for i = 1, #parts do
		local part = parts[i]
		if part and part:IsA("BasePart") then
			local cframe, size = part.CFrame, part.Size
			local a = (cframe - size * 0.5).Position
			local b = (cframe + size * 0.5).Position
			minv = minv and Vector3.new(math.min(minv.X, a.X), math.min(minv.Y, a.Y), math.min(minv.Z, a.Z)) or a
			maxv = maxv and Vector3.new(math.max(maxv.X, b.X), math.max(maxv.Y, b.Y), math.max(maxv.Z, b.Z)) or b
		end
	end

	if not minv or not maxv then
		-- fallback tiny box at origin
		return CFrame.new(), Vector3.new(0, 0, 0)
	end

	local center = (minv + maxv) * 0.5
	local front = Vector3.new(center.X, center.Y, maxv.Z)
	return CFrame.new(center, front), maxv - minv
end

local function worldToScreen(world)
	if not camera then return Vector2.new(0,0), false, math.huge end
	-- camera:WorldToViewportPoint returns Vector3 (x,y,z) and boolean visible
	local screenPoint, onScreen = camera:WorldToViewportPoint(world)
	return Vector2.new(screenPoint.X, screenPoint.Y), onScreen, screenPoint.Z
end

local function calculateCorners(cframe, size)
	local corners = {}
	for i = 1, #VERTICES do
		local worldPos = (cframe + size * 0.5 * VERTICES[i]).Position
		corners[i] = worldToScreen(worldPos)
	end

	local mins = min2(viewportSize, unpack(corners))
	local maxs = max2(Vector2.new(0, 0), unpack(corners))
	return {
		corners = corners,
		topLeft = Vector2.new(floor(mins.X), floor(mins.Y)),
		topRight = Vector2.new(floor(maxs.X), floor(mins.Y)),
		bottomLeft = Vector2.new(floor(mins.X), floor(maxs.Y)),
		bottomRight = Vector2.new(floor(maxs.X), floor(maxs.Y))
	}
end

local function rotateVector(vector, radians)
	local x, y = vector.X, vector.Y
	local c, s = cos(radians), sin(radians)
	return Vector2.new(x * c - y * s, x * s + y * c)
end

local function parseColor(self, color, isOutline)
	if color == "Team Color" or (self.interface.sharedSettings.useTeamColor and not isOutline) then
		return self.interface.getTeamColor(self.player) or Color3.new(1, 1, 1)
	end
	return color
end

-- esp object
local EspObject = {}
EspObject.__index = EspObject

function EspObject.new(player, interface)
	local self = setmetatable({}, EspObject)
	self.player = assert(player, "Missing argument #1 (Player expected)")
	self.interface = assert(interface, "Missing argument #2 (table expected)")
	self:Construct()
	return self
end

function EspObject:_create(class, properties)
	local drawing = Drawing.new(class)
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
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false })
			},
			{
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false })
			},
			{
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false })
			},
			{
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false })
			}
		},
		visible = {
			tracerOutline = self:_create("Line", { Thickness = 3, Visible = false }),
			tracer = self:_create("Line", { Thickness = 1, Visible = false }),
			boxFill = self:_create("Square", { Filled = true, Visible = false }),
			boxOutline = self:_create("Square", { Thickness = 3, Visible = false }),
			box = self:_create("Square", { Thickness = 1, Visible = false }),
			healthBarOutline = self:_create("Line", { Thickness = 3, Visible = false }),
			healthBar = self:_create("Line", { Thickness = 1, Visible = false }),
			healthText = self:_create("Text", { Center = true, Visible = false }),
			name = self:_create("Text", { Text = self.player.DisplayName or self.player.Name, Center = true, Visible = false }),
			distance = self:_create("Text", { Center = true, Visible = false }),
			weapon = self:_create("Text", { Center = true, Visible = false })
		},
		hidden = {
			arrowOutline = self:_create("Triangle", { Thickness = 3, Visible = false }),
			arrow = self:_create("Triangle", { Filled = true, Visible = false })
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

	self.options = interface.teamSettings[interface.isFriendly(self.player) and "friendly" or "enemy"]
	self.character = interface.getCharacter(self.player)
	self.health, self.maxHealth = interface.getHealth(self.player)
	self.weapon = interface.getWeapon(self.player)
	self.enabled = self.options.enabled and self.character and not
		(#interface.whitelist > 0 and not find(interface.whitelist, self.player.UserId))

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
		local children = getChildren(self.character)
		if not cache[1] or self.childCount ~= #children then
			clear(cache)

			for i = 1, #children do
				local part = children[i]
				if part and part:IsA("BasePart") and isBodyPart(part.Name) then
					cache[#cache + 1] = part
				end
			end

			self.childCount = #children
		end

		local cframe, size = getBoundingBox(cache)
        self.corners = calculateCorners(cframe, size)
	elseif self.options.offScreenArrow then
		local cframe = camera.CFrame
		local flat = CFrame.fromMatrix(cframe.Position, cframe.RightVector, Vector3.new(0, 1, 0))
		local objectSpace = pointToObjectSpace(flat, head.Position)
		if objectSpace.Magnitude > 0 then
			self.direction = Vector2.new(objectSpace.X, objectSpace.Z).Unit
		else
			self.direction = Vector2.new(0, -1)
		end
	end
end

function EspObject:Render()
	local onScreen = self.onScreen or false
	local enabled = self.enabled or false
	local visible = self.drawings.visible
	local hidden = self.drawings.hidden
	local box3d = self.drawings.box3d
	local interface = self.interface
	local options = self.options
	local corners = self.corners or {
		topLeft = Vector2.new(0,0),
		topRight = Vector2.new(0,0),
		bottomLeft = Vector2.new(0,0),
		bottomRight = Vector2.new(0,0),
		corners = {}
	}

	-- Box
	visible.box.Visible = enabled and onScreen and options.box
	visible.boxOutline.Visible = visible.box.Visible and options.boxOutline
	if visible.box.Visible then
		local box = visible.box
		box.Position = corners.topLeft
		box.Size = corners.bottomRight - corners.topLeft
		box.Color = parseColor(self, options.boxColor[1])
		box.Transparency = options.boxColor[2]

		local boxOutline = visible.boxOutline
		boxOutline.Position = box.Position
		boxOutline.Size = box.Size
		boxOutline.Color = parseColor(self, options.boxOutlineColor[1], true)
		boxOutline.Transparency = options.boxOutlineColor[2]
	end

	-- Box fill
	visible.boxFill.Visible = enabled and onScreen and options.boxFill
	if visible.boxFill.Visible then
		local boxFill = visible.boxFill
		boxFill.Position = corners.topLeft
		boxFill.Size = corners.bottomRight - corners.topLeft
		boxFill.Color = parseColor(self, options.boxFillColor[1])
		boxFill.Transparency = options.boxFillColor[2]
	end

	-- Health bar
	visible.healthBar.Visible = enabled and onScreen and options.healthBar
	visible.healthBarOutline.Visible = visible.healthBar.Visible and options.healthBarOutline
	if visible.healthBar.Visible then
		local barFrom = corners.topLeft - HEALTH_BAR_OFFSET
		local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET

		local healthBar = visible.healthBar
		healthBar.To = barTo
		healthBar.From = lerp2(barTo, barFrom, (self.health or 0) / (self.maxHealth or 1))
		healthBar.Color = lerpColor(options.dyingColor, options.healthyColor, (self.health or 0) / (self.maxHealth or 1))

		local healthBarOutline = visible.healthBarOutline
		healthBarOutline.To = barTo + HEALTH_BAR_OUTLINE_OFFSET
		healthBarOutline.From = barFrom - HEALTH_BAR_OUTLINE_OFFSET
		healthBarOutline.Color = parseColor(self, options.healthBarOutlineColor[1], true)
		healthBarOutline.Transparency = options.healthBarOutlineColor[2]
	end

	-- Health text
	visible.healthText.Visible = enabled and onScreen and options.healthText
	if visible.healthText.Visible then
		local barFrom = corners.topLeft - HEALTH_BAR_OFFSET
		local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET

		local healthText = visible.healthText
		healthText.Text = round(self.health or 0) .. "hp"
		healthText.Size = interface.sharedSettings.textSize
		healthText.Font = interface.sharedSettings.textFont
		healthText.Color = parseColor(self, options.healthTextColor[1])
		healthText.Transparency = options.healthTextColor[2]
		healthText.Outline = options.healthTextOutline
		healthText.OutlineColor = parseColor(self, options.healthTextOutlineColor, true)
		healthText.Position = lerp2(barTo, barFrom, (self.health or 0) / (self.maxHealth or 1)) - (healthText.TextBounds and Vector2.new(healthText.TextBounds.X, healthText.TextBounds.Y) * 0.5 or Vector2.new(0,0)) - HEALTH_TEXT_OFFSET
	end

	-- Name
	visible.name.Visible = enabled and onScreen and options.name
	if visible.name.Visible then
		local name = visible.name
		name.Size = interface.sharedSettings.textSize
		name.Font = interface.sharedSettings.textFont
		name.Color = parseColor(self, options.nameColor[1])
		name.Transparency = options.nameColor[2]
		name.Outline = options.nameOutline
		name.OutlineColor = parseColor(self, options.nameOutlineColor, true)
		name.Position = (corners.topLeft + corners.topRight) * 0.5 - Vector2.new(0, name.TextBounds and name.TextBounds.Y or 0) - NAME_OFFSET
	end

	-- Distance
	visible.distance.Visible = enabled and onScreen and self.distance and options.distance
	if visible.distance.Visible then
		local distance = visible.distance
		distance.Text = round(self.distance or 0) .. " studs"
		distance.Size = interface.sharedSettings.textSize
		distance.Font = interface.sharedSettings.textFont
		distance.Color = parseColor(self, options.distanceColor[1])
		distance.Transparency = options.distanceColor[2]
		distance.Outline = options.distanceOutline
		distance.OutlineColor = parseColor(self, options.distanceOutlineColor, true)
		distance.Position = (corners.bottomLeft + corners.bottomRight) * 0.5 + DISTANCE_OFFSET
	end

	-- Weapon
	visible.weapon.Visible = enabled and onScreen and options.weapon
	if visible.weapon.Visible then
		local weapon = visible.weapon
		weapon.Text = tostring(self.weapon or "Unknown")
		weapon.Size = interface.sharedSettings.textSize
		weapon.Font = interface.sharedSettings.textFont
		weapon.Color = parseColor(self, options.weaponColor[1])
		weapon.Transparency = options.weaponColor[2]
		weapon.Outline = options.weaponOutline
		weapon.OutlineColor = parseColor(self, options.weaponOutlineColor, true)
		weapon.Position =
			(corners.bottomLeft + corners.bottomRight) * 0.5 +
			(visible.distance.Visible and DISTANCE_OFFSET + Vector2.new(0, visible.distance.TextBounds and visible.distance.TextBounds.Y or 0) or Vector2.new(0,0))
	end

	-- Tracer
	visible.tracer.Visible = enabled and onScreen and options.tracer
	visible.tracerOutline.Visible = visible.tracer.Visible and options.tracerOutline
	if visible.tracer.Visible then
		local tracer = visible.tracer
		tracer.Color = parseColor(self, options.tracerColor[1])
		tracer.Transparency = options.tracerColor[2]
		tracer.To = (corners.bottomLeft + corners.bottomRight) * 0.5
		tracer.From =
			(options.tracerOrigin == "Middle" and viewportSize * 0.5) or
			(options.tracerOrigin == "Top" and viewportSize * Vector2.new(0.5, 0)) or
			(options.tracerOrigin == "Bottom" and viewportSize * Vector2.new(0.5, 1)) or
			viewportSize * 0.5

		local tracerOutline = visible.tracerOutline
		tracerOutline.Color = parseColor(self, options.tracerOutlineColor[1], true)
		tracerOutline.Transparency = options.tracerOutlineColor[2]
		tracerOutline.To = tracer.To
		tracerOutline.From = tracer.From
	end

	-- Off-screen arrow
	-- hidden.arrow.Visible = enabled and (not onScreen) and options.offScreenArrow
	-- hidden.arrowOutline.Visible = hidden.arrow.Visible and options.offScreenArrowOutline
	-- if hidden.arrow.Visible and self.direction then
	-- 	local arrow = hidden.arrow
	-- 	arrow.PointA = min2(max2(viewportSize * 0.5 + self.direction * options.offScreenArrowRadius, Vector2.new(25, 25)), viewportSize - Vector2.new(25, 25))
	-- 	arrow.PointB = arrow.PointA - rotateVector(self.direction, 0.45) * options.offScreenArrowSize
	-- 	arrow.PointC = arrow.PointA - rotateVector(self.direction, -0.45) * options.offScreenArrowSize
	-- 	arrow.Color = parseColor(self, options.offScreenArrowColor[1])
	-- 	arrow.Transparency = options.offScreenArrowColor[2]

	-- 	local arrowOutline = hidden.arrowOutline
	-- 	arrowOutline.PointA = arrow.PointA
	-- 	arrowOutline.PointB = arrow.PointB
	-- 	arrowOutline.PointC = arrow.PointC
	-- 	arrowOutline.Color = parseColor(self, options.offScreenArrowOutlineColor[1], true)
	-- 	arrowOutline.Transparency = options.offScreenArrowOutlineColor[2]
	-- end

	-- 3D box faces
	local box3dEnabled = enabled and onScreen and options.box3d
	for fi = 1, #box3d do
		local face = box3d[fi]
		for i2 = 1, #face do
			local line = face[i2]
			line.Visible = box3dEnabled
			line.Color = parseColor(self, options.box3dColor[1])
			line.Transparency = options.box3dColor[2]
		end

		if box3dEnabled then
			local line1 = face[1]
			line1.From = corners.corners[fi]
			line1.To = corners.corners[fi == 4 and 1 or fi + 1]

			local line2 = face[2]
			line2.From = corners.corners[fi == 4 and 1 or fi + 1]
			line2.To = corners.corners[fi == 4 and 5 or fi + 5]

			local line3 = face[3]
			line3.From = corners.corners[fi == 4 and 5 or fi + 5]
			line3.To = corners.corners[fi == 4 and 8 or fi + 4]
		end
	end
end

-- cham object
local ChamObject = {}
ChamObject.__index = ChamObject

function ChamObject.new(player, interface)
	local self = setmetatable({}, ChamObject)
	self.player = assert(player, "Missing argument #1 (Player expected)")
	self.interface = assert(interface, "Missing argument #2 (table expected)")
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
	local character = interface.getCharacter(self.player)
	local options = interface.teamSettings[interface.isFriendly(self.player) and "friendly" or "enemy"]
	local enabled = options.enabled and character and not
		(#interface.whitelist > 0 and not find(interface.whitelist, self.player.UserId))

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

-- instance class
local InstanceObject = {}
InstanceObject.__index = InstanceObject

function InstanceObject.new(instance, options)
	local self = setmetatable({}, InstanceObject)
	self.instance = assert(instance, "Missing argument #1 (Instance Expected)")
	self.options = assert(options, "Missing argument #2 (table expected)")
	self:Construct()
	return self
end

function InstanceObject:Construct()
	local options = self.options
	options.enabled = options.enabled == nil and true or options.enabled
	options.text = options.text or "{name}"
	options.textColor = options.textColor or { Color3.new(1,1,1), 1 }
	options.textOutline = options.textOutline == nil and true or options.textOutline
	options.textOutlineColor = options.textOutlineColor or Color3.new()
	options.textSize = options.textSize or 13
	options.textFont = options.textFont or 2
	options.limitDistance = options.limitDistance or false
	options.maxDistance = options.maxDistance or 150

	self.text = Drawing.new("Text")
	self.text.Center = true

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
	if text.Visible then
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

-- interface
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
			enabled = false,
			box = false,
			boxColor = { Color3.new(1,0,0), 1 },
			boxOutline = true,
			boxOutlineColor = { Color3.new(), 1 },
			boxFill = false,
			boxFillColor = { Color3.new(1,0,0), 0.5 },
			healthBar = false,
			healthyColor = Color3.new(0,1,0),
			dyingColor = Color3.new(1,0,0),
			healthBarOutline = true,
			healthBarOutlineColor = { Color3.new(), 0.5 },
			healthText = false,
			healthTextColor = { Color3.new(1,1,1), 1 },
			healthTextOutline = true,
			healthTextOutlineColor = Color3.new(),
			box3d = false,
			box3dColor = { Color3.new(1,0,0), 1 },
			name = false,
			nameColor = { Color3.new(1,1,1), 1 },
			nameOutline = true,
			nameOutlineColor = Color3.new(),
			weapon = false,
			weaponColor = { Color3.new(1,1,1), 1 },
			weaponOutline = true,
			weaponOutlineColor = { Color3.new(), 1 },
			distance = false,
			distanceColor = { Color3.new(1,1,1), 1 },
			distanceOutline = true,
			distanceOutlineColor = { Color3.new(), 1 },
			tracer = false,
			tracerOrigin = "Bottom",
			tracerColor = { Color3.new(1,0,0), 1 },
			tracerOutline = true,
			tracerOutlineColor = { Color3.new(), 1 },
			offScreenArrow = false,
			offScreenArrowColor = { Color3.new(1,1,1), 1 },
			offScreenArrowSize = 15,
			offScreenArrowRadius = 150,
			offScreenArrowOutline = true,
			offScreenArrowOutlineColor = { Color3.new(), 1 },
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
			boxOutlineColor = { Color3.new(), 1 },
			boxFill = false,
			boxFillColor = { Color3.new(0,1,0), 0.5 },
			healthBar = false,
			healthyColor = Color3.new(0,1,0),
			dyingColor = Color3.new(1,0,0),
			healthBarOutline = true,
			healthBarOutlineColor = { Color3.new(), 0.5 },
			healthText = false,
			healthTextColor = { Color3.new(1,1,1), 1 },
			healthTextOutline = true,
			healthTextOutlineColor = Color3.new(),
			box3d = false,
			box3dColor = { Color3.new(0,1,0), 1 },
			name = false,
			nameColor = { Color3.new(1,1,1), 1 },
			nameOutline = true,
			nameOutlineColor = Color3.new(),
			weapon = false,
			weaponColor = { Color3.new(1,1,1), 1 },
			weaponOutline = true,
			weaponOutlineColor = { Color3.new(), 1 },
			distance = false,
			distanceColor = { Color3.new(1,1,1), 1 },
			distanceOutline = true,
			distanceOutlineColor = { Color3.new(), 1 },
			tracer = false,
			tracerOrigin = "Bottom",
			tracerColor = { Color3.new(0,1,0), 1 },
			tracerOutline = true,
			tracerOutlineColor = { Color3.new(), 1 },
			offScreenArrow = false,
			offScreenArrowColor = { Color3.new(1,1,1), 1 },
			offScreenArrowSize = 15,
			offScreenArrowRadius = 150,
			offScreenArrowOutline = true,
			offScreenArrowOutlineColor = { Color3.new(), 1 },
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
		-- ignore local player if you want
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

-- game specific functions (override these as needed)
-- function EspInterface.getWeapon(player)
-- 	return "Unknown"
-- end
function EspInterface.getWeapon(player)
    local char = player and player.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") then
                return child.Name
            end
        end
    end
    local backpack = player and player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
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