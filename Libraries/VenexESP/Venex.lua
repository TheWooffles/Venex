-- services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- variables
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Container = Instance.new("Folder", (gethui and gethui() or game:GetService("CoreGui")))

-- locals / cached functions
local floor = math.floor
local round = math.round
local sin = math.sin
local cos = math.cos
local clear = table.clear
local unpack = table.unpack
local find = table.find
local create = table.create

-- safe wrappers for instance methods (fixes previous bugs where methods were bound incorrectly)
local function IsA(inst, class) return inst and inst:IsA(class) end
local function FindFirstChild(parent, name) return parent and parent:FindFirstChild(name) end
local function FindFirstChildOfClass(parent, class) return parent and parent:FindFirstChildOfClass(class) end
local function GetChildren(parent) return parent and parent:GetChildren() or {} end

-- helpers
local function safeGetPivot(instance)
	-- prefer GetPivot if available (roblox newer API), otherwise try PrimaryPart, otherwise try Model:GetModelCFrame or fallback to instance:GetBoundingBox
	if not instance then return CFrame.new() end
	if instance.GetPivot then
		local ok, pivot = pcall(function() return instance:GetPivot() end)
		if ok and typeof(pivot) == "CFrame" then return pivot end
	end
	-- Model
	if instance:IsA("Model") then
		local primary = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart")
		if primary then return primary.CFrame end
		if instance.GetModelCFrame then
			local ok, mcf = pcall(function() return instance:GetModelCFrame() end)
			if ok and typeof(mcf) == "CFrame" then return mcf end
		end
	end
	-- Instance is a BasePart
	if instance:IsA("BasePart") then
		return instance.CFrame
	end
	-- fallback
	return CFrame.new()
end

-- frequently used camera function (we'll call it with camera param to keep it fast)
local WorldToViewportPoint = Camera.WorldToViewportPoint

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

-- small math helpers
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

-- world -> screen helper
local function worldToScreen(world)
	local screenX, onScreen, depth = WorldToViewportPoint(Camera, world)
	-- WorldToViewportPoint returns Vector3 (x,y,z) when called as Camera:WorldToViewportPoint,
	-- but when retrieving raw function we called it as Camera.WorldToViewportPoint(Camera, world) which returns the same.
	-- We'll account for both possibilities
	if typeof(screenX) == "Vector3" then
		local v3 = screenX
		return Vector2.new(v3.X, v3.Y), onScreen ~= false, depth or v3.Z
	elseif typeof(screenX) == "Vector2" then
		-- unlikely, but handle gracefully
		return screenX, onScreen ~= false, depth or 0
	end
	-- fallback: try calling method-style
	local v3 = Camera:WorldToViewportPoint(world)
	return Vector2.new(v3.X, v3.Y), v3.Z > 0, v3.Z
end

-- bounding box calculation that handles rotated parts reliably
local function getBoundingBox(parts)
	local minV, maxV
	for i = 1, #parts do
		local part = parts[i]
		if part and part:IsA("BasePart") then
			local cframe = part.CFrame
			local size = part.Size
			local half = size * 0.5

			-- compute 8 world-space corners for this part and expand min/max
			for vi = 1, #VERTICES do
				local offset = VERTICES[vi] * half
				local worldPos = (cframe * CFrame.new(offset)).Position
				if not minV then
					minV = Vector3.new(worldPos.X, worldPos.Y, worldPos.Z)
					maxV = Vector3.new(worldPos.X, worldPos.Y, worldPos.Z)
				else
					minV = Vector3.new(
						math.min(minV.X, worldPos.X),
						math.min(minV.Y, worldPos.Y),
						math.min(minV.Z, worldPos.Z)
					)
					maxV = Vector3.new(
						math.max(maxV.X, worldPos.X),
						math.max(maxV.Y, worldPos.Y),
						math.max(maxV.Z, worldPos.Z)
					)
				end
			end
		end
	end

	if not minV then
		return CFrame.new(), Vector3.new(0, 0, 0)
	end

	local center = (minV + maxV) * 0.5
	-- front point for orientation (pointing toward maximum Z)
	local front = Vector3.new(center.X, center.Y, maxV.Z)
	return CFrame.new(center, front), (maxV - minV)
end

-- calculate 2D corners for a bounding box
local function calculateCorners(cframe, size)
	-- produce 8 projected corners
	local corners = {}
	local half = size * 0.5
	for i = 1, #VERTICES do
		local worldPos = (cframe * CFrame.new(VERTICES[i] * half)).Position
		corners[i] = worldToScreen(worldPos)
	end

	-- compute min/max on X,Y for the projected points (ignore points off-screen but still include them in box)
	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	for i = 1, #corners do
		local v2 = corners[i]
		if v2 then
			minX = math.min(minX, v2.X)
			minY = math.min(minY, v2.Y)
			maxX = math.max(maxX, v2.X)
			maxY = math.max(maxY, v2.Y)
		end
	end

	-- clamp to viewport
	local vp = Camera.ViewportSize
	local topLeft = Vector2.new(floor(math.max(0, minX)), floor(math.max(0, minY)))
	local bottomRight = Vector2.new(floor(math.min(vp.X, maxX)), floor(math.min(vp.Y, maxY)))
	local topRight = Vector2.new(bottomRight.X, topLeft.Y)
	local bottomLeft = Vector2.new(topLeft.X, bottomRight.Y)

	return {
		corners = corners,
		topLeft = topLeft,
		topRight = topRight,
		bottomLeft = bottomLeft,
		bottomRight = bottomRight
	}
end

-- ESP object
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
			{ self:_create("Line", { Thickness = 1, Visible = false }), self:_create("Line", { Thickness = 1, Visible = false }), self:_create("Line", { Thickness = 1, Visible = false }) },
			{ self:_create("Line", { Thickness = 1, Visible = false }), self:_create("Line", { Thickness = 1, Visible = false }), self:_create("Line", { Thickness = 1, Visible = false }) },
			{ self:_create("Line", { Thickness = 1, Visible = false }), self:_create("Line", { Thickness = 1, Visible = false }), self:_create("Line", { Thickness = 1, Visible = false }) },
			{ self:_create("Line", { Thickness = 1, Visible = false }), self:_create("Line", { Thickness = 1, Visible = false }), self:_create("Line", { Thickness = 1, Visible = false }) }
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
			name = self:_create("Text", { Text = self.player.DisplayName, Center = true, Visible = false }),
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
	if self.renderConnection and self.renderConnection.Disconnect then
		self.renderConnection:Disconnect()
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

	local head = self.enabled and FindFirstChild(self.character, "Head")
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
		local children = GetChildren(self.character)
		if not cache[1] or self.childCount ~= #children then
			clear(cache)
			for i = 1, #children do
				local part = children[i]
				if IsA(part, "BasePart") and (part.Name == "Head" or part.Name:find("Torso") or part.Name:find("Leg") or part.Name:find("Arm")) then
					cache[#cache + 1] = part
				end
			end
			self.childCount = #children
		end

		self.corners = calculateCorners(getBoundingBox(cache))
	elseif self.options.offScreenArrow then
		local cframe = Camera.CFrame
		local flat = CFrame.fromMatrix(cframe.Position, cframe.RightVector, Vector3.yAxis)
		local objectSpace = (flat:PointToObjectSpace and flat:PointToObjectSpace(head.Position)) or head.Position
		local dir = Vector2.new(objectSpace.X, objectSpace.Z)
		if dir.Magnitude > 0 then
			self.direction = dir.Unit
		else
			self.direction = nil
		end
	end
end

function EspObject:Render()
	local onScreen = self.onScreen or false
	local enabled = self.enabled or false
	local visible = self.drawings.visible
	local hidden = self.drawings.hidden
	local box3d = self.drawings.box3d
	local options = self.options
	local corners = self.corners

	-- Box
	visible.box.Visible = enabled and onScreen and options.box
	visible.boxOutline.Visible = visible.box.Visible and options.boxOutline
	if visible.box.Visible and corners then
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

	-- Fill
	visible.boxFill.Visible = enabled and onScreen and options.boxFill
	if visible.boxFill.Visible and corners then
		local boxFill = visible.boxFill
		boxFill.Position = corners.topLeft
		boxFill.Size = corners.bottomRight - corners.topLeft
		boxFill.Color = parseColor(self, options.boxFillColor[1])
		boxFill.Transparency = options.boxFillColor[2]
	end

	-- Health bar
	visible.healthBar.Visible = enabled and onScreen and options.healthBar
	visible.healthBarOutline.Visible = visible.healthBar.Visible and options.healthBarOutline
	if visible.healthBar.Visible and corners and self.health and self.maxHealth then
		local barFrom = corners.topLeft - HEALTH_BAR_OFFSET
		local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET

		local healthBar = visible.healthBar
		healthBar.To = barTo
		healthBar.From = barTo:Lerp(barFrom, self.health / self.maxHealth)
		healthBar.Color = options.dyingColor:Lerp(options.healthyColor, self.health / self.maxHealth)

		local healthBarOutline = visible.healthBarOutline
		healthBarOutline.To = barTo + HEALTH_BAR_OUTLINE_OFFSET
		healthBarOutline.From = barFrom - HEALTH_BAR_OUTLINE_OFFSET
		healthBarOutline.Color = parseColor(self, options.healthBarOutlineColor[1], true)
		healthBarOutline.Transparency = options.healthBarOutlineColor[2]
	end

	-- Health text
	visible.healthText.Visible = enabled and onScreen and options.healthText
	if visible.healthText.Visible and corners and self.health and self.maxHealth then
		local barFrom = corners.topLeft - HEALTH_BAR_OFFSET
		local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET

		local healthText = visible.healthText
		healthText.Text = round(self.health) .. "hp"
		healthText.Size = self.interface.sharedSettings.textSize
		healthText.Font = self.interface.sharedSettings.textFont
		healthText.Color = parseColor(self, options.healthTextColor[1])
		healthText.Transparency = options.healthTextColor[2]
		healthText.Outline = options.healthTextOutline
		healthText.OutlineColor = parseColor(self, options.healthTextOutlineColor, true)
		healthText.Position = barTo:Lerp(barFrom, self.health / self.maxHealth) - healthText.TextBounds * 0.5 - HEALTH_TEXT_OFFSET
	end

	-- Name
	visible.name.Visible = enabled and onScreen and options.name
	if visible.name.Visible and corners then
		local name = visible.name
		name.Size = self.interface.sharedSettings.textSize
		name.Font = self.interface.sharedSettings.textFont
		name.Color = parseColor(self, options.nameColor[1])
		name.Transparency = options.nameColor[2]
		name.Outline = options.nameOutline
		name.OutlineColor = parseColor(self, options.nameOutlineColor, true)
		name.Position = (corners.topLeft + corners.topRight) * 0.5 - Vector2.yAxis * name.TextBounds.Y - NAME_OFFSET
	end

	-- Distance
	visible.distance.Visible = enabled and onScreen and self.distance and options.distance
	if visible.distance.Visible and corners then
		local distance = visible.distance
		distance.Text = round(self.distance) .. " studs"
		distance.Size = self.interface.sharedSettings.textSize
		distance.Font = self.interface.sharedSettings.textFont
		distance.Color = parseColor(self, options.distanceColor[1])
		distance.Transparency = options.distanceColor[2]
		distance.Outline = options.distanceOutline
		distance.OutlineColor = parseColor(self, options.distanceOutlineColor, true)
		distance.Position = (corners.bottomLeft + corners.bottomRight) * 0.5 + DISTANCE_OFFSET
	end

	-- Weapon
	visible.weapon.Visible = enabled and onScreen and options.weapon
	if visible.weapon.Visible and corners then
		local weapon = visible.weapon
		weapon.Text = self.weapon
		weapon.Size = self.interface.sharedSettings.textSize
		weapon.Font = self.interface.sharedSettings.textFont
		weapon.Color = parseColor(self, options.weaponColor[1])
		weapon.Transparency = options.weaponColor[2]
		weapon.Outline = options.weaponOutline
		weapon.OutlineColor = parseColor(self, options.weaponOutlineColor, true)
		weapon.Position = (corners.bottomLeft + corners.bottomRight) * 0.5 +
			(visible.distance.Visible and DISTANCE_OFFSET + Vector2.yAxis * visible.distance.TextBounds.Y or Vector2.zero)
	end

	-- Tracer
	visible.tracer.Visible = enabled and onScreen and options.tracer
	visible.tracerOutline.Visible = visible.tracer.Visible and options.tracerOutline
	if visible.tracer.Visible and corners then
		local tracer = visible.tracer
		tracer.Color = parseColor(self, options.tracerColor[1])
		tracer.Transparency = options.tracerColor[2]
		tracer.To = (corners.bottomLeft + corners.bottomRight) * 0.5
		local vp = Camera.ViewportSize
		tracer.From = (options.tracerOrigin == "Middle" and vp * 0.5) or
			(options.tracerOrigin == "Top" and vp * Vector2.new(0.5, 0)) or
			(options.tracerOrigin == "Bottom" and vp * Vector2.new(0.5, 1))

		local tracerOutline = visible.tracerOutline
		tracerOutline.Color = parseColor(self, options.tracerOutlineColor[1], true)
		tracerOutline.Transparency = options.tracerOutlineColor[2]
		tracerOutline.To = tracer.To
		tracerOutline.From = tracer.From
	end

	-- Off-screen arrow
	hidden.arrow.Visible = enabled and (not onScreen) and options.offScreenArrow
	hidden.arrowOutline.Visible = hidden.arrow.Visible and options.offScreenArrowOutline
	if hidden.arrow.Visible and self.direction then
		local arrow = hidden.arrow
		local vp = Camera.ViewportSize
		local clamped = Vector2.new(
			math.clamp(vp.X * 0.5 + self.direction.X * options.offScreenArrowRadius, 25, vp.X - 25),
			math.clamp(vp.Y * 0.5 + self.direction.Y * options.offScreenArrowRadius, 25, vp.Y - 25)
		)
		arrow.PointA = clamped
		arrow.PointB = arrow.PointA - rotateVector(self.direction, 0.45) * options.offScreenArrowSize
		arrow.PointC = arrow.PointA - rotateVector(self.direction, -0.45) * options.offScreenArrowSize
		arrow.Color = parseColor(self, options.offScreenArrowColor[1])
		arrow.Transparency = options.offScreenArrowColor[2]

		local arrowOutline = hidden.arrowOutline
		arrowOutline.PointA = arrow.PointA
		arrowOutline.PointB = arrow.PointB
		arrowOutline.PointC = arrow.PointC
		arrowOutline.Color = parseColor(self, options.offScreenArrowOutlineColor[1], true)
		arrowOutline.Transparency = options.offScreenArrowOutlineColor[2]
	end

	-- box3d
	local box3dEnabled = enabled and onScreen and options.box3d
	for fi = 1, #box3d do
		local face = box3d[fi]
		for li = 1, #face do
			local line = face[li]
			line.Visible = box3dEnabled
			line.Color = parseColor(self, options.box3dColor[1])
			line.Transparency = options.box3dColor[2]
		end

		if box3dEnabled and corners and corners.corners then
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

-- Cham object
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
	self.highlight = Instance.new("Highlight", Container)
	self.updateConnection = RunService.Heartbeat:Connect(function()
		self:Update()
	end)
end

function ChamObject:Destruct()
	if self.updateConnection and self.updateConnection.Disconnect then
		self.updateConnection:Disconnect()
	end
	if self.highlight then
		self.highlight:Destroy()
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

-- Instance object (for labeling Instances in world)
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
	options.textColor = options.textColor or { Color3.new(1, 1, 1), 1 }
	options.textOutline = options.textOutline == nil and true or options.textOutline
	options.textOutlineColor = options.textOutlineColor or Color3.new()
	options.textSize = options.textSize or 13
	options.textFont = options.textFont or 2
	options.limitDistance = options.limitDistance or false
	options.maxDistance = options.maxDistance or 150

	self.text = Drawing.new("Text")
	self.text.Center = true

	self.renderConnection = RunService.Heartbeat:Connect(function()
		self:Render()
	end)
end

function InstanceObject:Destruct()
	if self.renderConnection and self.renderConnection.Disconnect then
		self.renderConnection:Disconnect()
	end
	if self.text then
		self.text:Remove()
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

	local pivot = safeGetPivot(instance)
	local world = pivot.Position
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

-- Interface (exposed)
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
			boxColor = { Color3.new(1, 0, 0), 1 },
			boxOutline = true,
			boxOutlineColor = { Color3.new(), 1 },
			boxFill = false,
			boxFillColor = { Color3.new(1, 0, 0), 0.5 },
			healthBar = false,
			healthyColor = Color3.new(0, 1, 0),
			dyingColor = Color3.new(1, 0, 0),
			healthBarOutline = true,
			healthBarOutlineColor = { Color3.new(), 0.5 },
			healthText = false,
			healthTextColor = { Color3.new(1, 1, 1), 1 },
			healthTextOutline = true,
			healthTextOutlineColor = Color3.new(),
			box3d = false,
			box3dColor = { Color3.new(1, 0, 0), 1 },
			name = false,
			nameColor = { Color3.new(1, 1, 1), 1 },
			nameOutline = true,
			nameOutlineColor = Color3.new(),
			weapon = false,
			weaponColor = { Color3.new(1, 1, 1), 1 },
			weaponOutline = true,
			weaponOutlineColor = { Color3.new(), 1 },
			distance = false,
			distanceColor = { Color3.new(1, 1, 1), 1 },
			distanceOutline = true,
			distanceOutlineColor = { Color3.new(), 1 },
			tracer = false,
			tracerOrigin = "Bottom",
			tracerColor = { Color3.new(1, 0, 0), 1 },
			tracerOutline = true,
			tracerOutlineColor = { Color3.new(), 1 },
			offScreenArrow = false,
			offScreenArrowColor = { Color3.new(1, 1, 1), 1 },
			offScreenArrowSize = 15,
			offScreenArrowRadius = 150,
			offScreenArrowOutline = true,
			offScreenArrowOutlineColor = { Color3.new(), 1 },
			chams = false,
			chamsVisibleOnly = false,
			chamsFillColor = { Color3.new(0.2, 0.2, 0.2), 0.5 },
			chamsOutlineColor = { Color3.new(1, 0, 0), 0 }
		},
		friendly = {
			enabled = false,
			box = false,
			boxColor = { Color3.new(0, 1, 0), 1 },
			boxOutline = true,
			boxOutlineColor = { Color3.new(), 1 },
			boxFill = false,
			boxFillColor = { Color3.new(0, 1, 0), 0.5 },
			healthBar = false,
			healthyColor = Color3.new(0, 1, 0),
			dyingColor = Color3.new(1, 0, 0),
			healthBarOutline = true,
			healthBarOutlineColor = { Color3.new(), 0.5 },
			healthText = false,
			healthTextColor = { Color3.new(1, 1, 1), 1 },
			healthTextOutline = true,
			healthTextOutlineColor = Color3.new(),
			box3d = false,
			box3dColor = { Color3.new(0, 1, 0), 1 },
			name = false,
			nameColor = { Color3.new(1, 1, 1), 1 },
			nameOutline = true,
			nameOutlineColor = Color3.new(),
			weapon = false,
			weaponColor = { Color3.new(1, 1, 1), 1 },
			weaponOutline = true,
			weaponOutlineColor = { Color3.new(), 1 },
			distance = false,
			distanceColor = { Color3.new(1, 1, 1), 1 },
			distanceOutline = true,
			distanceOutlineColor = { Color3.new(), 1 },
			tracer = false,
			tracerOrigin = "Bottom",
			tracerColor = { Color3.new(0, 1, 0), 1 },
			tracerOutline = true,
			tracerOutlineColor = { Color3.new(), 1 },
			offScreenArrow = false,
			offScreenArrowColor = { Color3.new(1, 1, 1), 1 },
			offScreenArrowSize = 15,
			offScreenArrowRadius = 150,
			offScreenArrowOutline = true,
			offScreenArrowOutlineColor = { Color3.new(), 1 },
			chams = false,
			chamsVisibleOnly = false,
			chamsFillColor = { Color3.new(0.2, 0.2, 0.2), 0.5 },
			chamsOutlineColor = { Color3.new(0, 1, 0), 0 }
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
	return cache[instance] and cache[instance][1] or nil
end

function EspInterface.Load()
	assert(not EspInterface._hasLoaded, "Esp has already been loaded.")

	local function createObject(player)
		-- ignore local player
		if player == LocalPlayer then return end
		EspInterface._objectCache[player] = {
			EspObject.new(player, EspInterface),
			ChamObject.new(player, EspInterface)
		}
	end

	local function removeObject(player)
		local object = EspInterface._objectCache[player]
		if object then
			for i = 1, #object do
				object[i]:Destruct()
			end
			EspInterface._objectCache[player] = nil
		end
	end

	local plrs = Players:GetPlayers()
	for i = 1, #plrs do
		local p = plrs[i]
		if p ~= LocalPlayer then createObject(p) end
	end

	EspInterface.playerAdded = Players.PlayerAdded:Connect(createObject)
	EspInterface.playerRemoving = Players.PlayerRemoving:Connect(removeObject)
	EspInterface._hasLoaded = true
end

function EspInterface.Unload()
	assert(EspInterface._hasLoaded, "Esp has not been loaded yet.")

	for index, object in next, EspInterface._objectCache do
		for i = 1, #object do
			object[i]:Destruct()
		end
		EspInterface._objectCache[index] = nil
	end

	if EspInterface.playerAdded then EspInterface.playerAdded:Disconnect() end
	if EspInterface.playerRemoving then EspInterface.playerRemoving:Disconnect() end
	EspInterface._hasLoaded = false
end

-- game specific functions (small improvements / safe defaults)
function EspInterface.getWeapon(player) return "Unknown" end
function EspInterface.isFriendly(player) return player and LocalPlayer and player.Team and player.Team == LocalPlayer.Team end
function EspInterface.getTeamColor(player) return player and player.Team and player.Team.TeamColor and player.Team.TeamColor.Color end
function EspInterface.getCharacter(player) return player and player.Character end
function EspInterface.getHealth(player)
	local character = player and EspInterface.getCharacter(player)
	local humanoid = character and FindFirstChildOfClass(character, "Humanoid")
	if humanoid then
		return humanoid.Health, humanoid.MaxHealth
	end
	return 100, 100
end

return EspInterface
