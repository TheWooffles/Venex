-- services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- environment
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local ViewportSize = Camera.ViewportSize
local CoreGui = game:GetService("CoreGui")
local container = Instance.new("Folder", (gethui and gethui()) or CoreGui)
container.Name = "ESP_Container"

-- fast locals
local floor = math.floor
local round = math.round
local sin = math.sin
local cos = math.cos
local clear = table.clear
local fromMatrix = CFrame.fromMatrix

-- methods (bound usage avoided to reduce GC)
local function worldToScreen(world)
    local screenPos, onScreen = Camera:WorldToViewportPoint(world)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

-- constants
local HEALTH_BAR_OFFSET = Vector2.new(5, 0)
local HEALTH_TEXT_OFFSET = Vector2.new(3, 0)
local HEALTH_BAR_OUTLINE_OFFSET = Vector2.new(0, 1)
local NAME_OFFSET = Vector2.new(0, 2)
local DISTANCE_OFFSET = Vector2.new(0, 2)

local VERTICES = {
    Vector3.new(-1, -1, -1),
    Vector3.new(-1,  1, -1),
    Vector3.new(-1,  1,  1),
    Vector3.new(-1, -1,  1),
    Vector3.new( 1, -1, -1),
    Vector3.new( 1,  1, -1),
    Vector3.new( 1,  1,  1),
    Vector3.new( 1, -1,  1)
}

-- utils
local function isBodyPart(name)
    -- Keep generous matching but avoid false positives
    return name == "Head"
        or name:find("Torso", 1, true)
        or name:find("Leg", 1, true)
        or name:find("Arm", 1, true)
end

local function rotateVector(v, r)
    local x, y = v.X, v.Y
    local c, s = cos(r), sin(r)
    return Vector2.new(x * c - y * s, x * s + y * c)
end

local function parseColor(self, color, isOutline)
    if color == "Team Color" or (self.interface.sharedSettings.useTeamColor and not isOutline) then
        return self.interface.getTeamColor(self.player) or Color3.new(1, 1, 1)
    end
    return color
end

local function getBoundingBox(character, cachedParts)
    -- Prefer Model:GetBoundingBox for correctness/perf
    if character and character:IsA("Model") then
        local ok, cf, size = pcall(character.GetBoundingBox, character)
        if ok and cf and size then
            return cf, size
        end
    end

    -- Fallback: manual from body parts
    local minX, minY, minZ, maxX, maxY, maxZ
    for i = 1, #cachedParts do
        local part = cachedParts[i]
        local c = part.CFrame
        local s = part.Size * 0.5
        local p1 = (c.Position - s)
        local p2 = (c.Position + s)

        local x1, y1, z1 = p1.X, p1.Y, p1.Z
        local x2, y2, z2 = p2.X, p2.Y, p2.Z

        minX = (minX and ((x1 < minX) and x1 or minX)) or x1
        minY = (minY and ((y1 < minY) and y1 or minY)) or y1
        minZ = (minZ and ((z1 < minZ) and z1 or minZ)) or z1

        maxX = (maxX and ((x2 > maxX) and x2 or maxX)) or x2
        maxY = (maxY and ((y2 > maxY) and y2 or maxY)) or y2
        maxZ = (maxZ and ((z2 > maxZ) and z2 or maxZ)) or z2
    end

    if not minX then
        return CFrame.new(), Vector3.zero
    end

    local center = Vector3.new((minX + maxX) * 0.5, (minY + maxY) * 0.5, (minZ + maxZ) * 0.5)
    local front = Vector3.new(center.X, center.Y, maxZ)
    return CFrame.new(center, front), Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
end

local function calculateCorners(cf, size)
    -- Project 8 corners and compute tight 2D bounds without unpack
    local half = size * 0.5
    local corners2d = table.create(8)

    local minX, minY =  math.huge,  math.huge
    local maxX, maxY = -math.huge, -math.huge

    for i = 1, 8 do
        local world = (cf + Vector3.new(half.X * VERTICES[i].X, half.Y * VERTICES[i].Y, half.Z * VERTICES[i].Z)).Position
        local v2, _, _ = worldToScreen(world)
        corners2d[i] = v2

        local x, y = v2.X, v2.Y
        if x < minX then minX = x end
        if y < minY then minY = y end
        if x > maxX then maxX = x end
        if y > maxY then maxY = y end
    end

    local tl = Vector2.new(floor(minX), floor(minY))
    local tr = Vector2.new(floor(maxX), floor(minY))
    local bl = Vector2.new(floor(minX), floor(maxY))
    local br = Vector2.new(floor(maxX), floor(maxY))

    return corners2d, tl, tr, bl, br
end

-- esp object
local EspObject = {}
EspObject.__index = EspObject

function EspObject.new(player, interface)
    local self = setmetatable({}, EspObject)
    self.player = player
    self.interface = interface

    self.bin = {}
    self.drawings = {
        box3d = {
            { Drawing.new("Line"), Drawing.new("Line"), Drawing.new("Line") },
            { Drawing.new("Line"), Drawing.new("Line"), Drawing.new("Line") },
            { Drawing.new("Line"), Drawing.new("Line"), Drawing.new("Line") },
            { Drawing.new("Line"), Drawing.new("Line"), Drawing.new("Line") },
        },
        visible = {
            tracerOutline = Drawing.new("Line"),
            tracer        = Drawing.new("Line"),
            boxFill       = Drawing.new("Square"),
            boxOutline    = Drawing.new("Square"),
            box           = Drawing.new("Square"),
            healthBarOutline = Drawing.new("Line"),
            healthBar        = Drawing.new("Line"),
            healthText    = Drawing.new("Text"),
            name          = Drawing.new("Text"),
            distance      = Drawing.new("Text"),
            weapon        = Drawing.new("Text"),
        },
        hidden = {
            arrowOutline = Drawing.new("Triangle"),
            arrow        = Drawing.new("Triangle"),
        }
    }

    -- initialize default props once
    do
        -- shared toggles
        local vis = self.drawings.visible
        vis.tracerOutline.Thickness = 3; vis.tracerOutline.Visible = false
        vis.tracer.Thickness = 1;        vis.tracer.Visible = false
        vis.boxFill.Filled = true;       vis.boxFill.Visible = false
        vis.boxOutline.Thickness = 3;    vis.boxOutline.Visible = false
        vis.box.Thickness = 1;           vis.box.Visible = false
        vis.healthBarOutline.Thickness = 3; vis.healthBarOutline.Visible = false
        vis.healthBar.Thickness = 1;        vis.healthBar.Visible = false
        vis.healthText.Center = true;    vis.healthText.Visible = false
        vis.name.Center = true;          vis.name.Visible = false
        vis.distance.Center = true;      vis.distance.Visible = false
        vis.weapon.Center = true;        vis.weapon.Visible = false

        local hid = self.drawings.hidden
        hid.arrowOutline.Thickness = 3;  hid.arrowOutline.Visible = false
        hid.arrow.Filled = true;         hid.arrow.Visible = false

        for i = 1, #self.drawings.box3d do
            local face = self.drawings.box3d[i]
            for j = 1, #face do
                face[j].Thickness = 1
                face[j].Visible = false
                self.bin[#self.bin + 1] = face[j]
            end
        end

        -- collect into bin for cleanup
        for _, d in pairs(self.drawings.visible) do self.bin[#self.bin + 1] = d end
        for _, d in pairs(self.drawings.hidden) do self.bin[#self.bin + 1] = d end
    end

    -- cache
    self._char = nil
    self._hum = nil
    self._head = nil
    self._parts = {} -- body parts used for fallback bbox
    self._lastChildConn = {}
    self._lastHealthRounded = nil
    self._lastDistanceRounded = nil
    self._lastWeapon = nil
    self._lastName = nil
    self._healthTextBounds = Vector2.zero
    self._distanceTextBounds = Vector2.zero
    self._nameTextBounds = Vector2.zero
    self._weaponTextBounds = Vector2.zero

    -- bind character lifecycle
    self:_bindCharacter(player.Character)
    player.CharacterAdded:Connect(function(char)
        self:_bindCharacter(char)
    end)
    player.CharacterRemoving:Connect(function()
        self:_unbindCharacter()
    end)

    return self
end

function EspObject:_bindCharacter(char)
    self:_unbindCharacter()
    self._char = char
    if not char then return end

    -- find head/humanoid once
    self._hum = char:FindFirstChildOfClass("Humanoid")
    self._head = char:FindFirstChild("Head")

    -- build parts cache and set watchers
    self._parts = {}
    local function tryAdd(part)
        if part:IsA("BasePart") and isBodyPart(part.Name) then
            self._parts[#self._parts + 1] = part
        end
    end
    for _, child in ipairs(char:GetChildren()) do
        tryAdd(child)
    end
    self._lastChildConn[#self._lastChildConn + 1] = char.ChildAdded:Connect(function(c)
        tryAdd(c)
    end)
    self._lastChildConn[#self._lastChildConn + 1] = char.ChildRemoved:Connect(function(c)
        -- rebuild lazily to avoid O(n) remove; cheap and infrequent
        self._parts = {}
        for _, child in ipairs(char:GetChildren()) do
            tryAdd(child)
        end
        if c == self._head then self._head = char:FindFirstChild("Head") end
        if c == self._hum then self._hum = char:FindFirstChildOfClass("Humanoid") end
    end)
end

function EspObject:_unbindCharacter()
    for i = 1, #self._lastChildConn do
        self._lastChildConn[i]:Disconnect()
    end
    self._lastChildConn = {}
    self._char = nil
    self._hum = nil
    self._head = nil
    self._parts = {}
end

function EspObject:Destruct()
    -- remove drawings
    for i = 1, #self.bin do
        pcall(function() self.bin[i]:Remove() end)
    end
    self:_unbindCharacter()
    clear(self)
end

function EspObject:Update(dt)
    local interface = self.interface
    local options = interface.teamSettings[interface.isFriendly(self.player) and "friendly" or "enemy"]
    self.options = options

    local enabled = options.enabled and (self._char ~= nil) and not
        (#interface.whitelist > 0 and not table.find(interface.whitelist, self.player.UserId))

    self.enabled = enabled
    if not enabled then
        self.onScreen = false
        return
    end

    if not self._head or not self._head.Parent then
        self.onScreen = false
        return
    end

    local _, onScreen, depth = worldToScreen(self._head.Position)
    if interface.sharedSettings.limitDistance and depth > interface.sharedSettings.maxDistance then
        onScreen = false
    end
    self.onScreen = onScreen
    self.distance = depth

    if onScreen then
        local cf, size = getBoundingBox(self._char, self._parts)
        self._cornersList, self._topLeft, self._topRight, self._bottomLeft, self._bottomRight = calculateCorners(cf, size)
    elseif options.offScreenArrow then
        local cframe = Camera.CFrame
        local flat = fromMatrix(cframe.Position, cframe.RightVector, Vector3.yAxis)
        local objSpace = flat:PointToObjectSpace(self._head.Position)
        local dir = Vector2.new(objSpace.X, objSpace.Z)
        if dir.Magnitude > 0 then
            self.direction = dir.Unit
        else
            self.direction = nil
        end
    end

    -- cache combat display values
    local hum = self._hum
    if hum then
        self.health = hum.Health
        self.maxHealth = hum.MaxHealth
    else
        self.health = 100
        self.maxHealth = 100
    end

    -- weapon string, only when it changes
    local weapon = interface.getWeapon(self.player) or ""
    if weapon ~= self._lastWeapon then
        self._lastWeapon = weapon
    end
end

function EspObject:Render(dt)
    local enabled = self.enabled
    local onScreen = self.onScreen
    local options = self.options
    local interface = self.interface

    local visible = self.drawings.visible
    local hidden = self.drawings.hidden
    local box3d = self.drawings.box3d

    -- Fast color parsing per-frame
    local function C(c, outline)
        return parseColor(self, c, outline)
    end

    -- 2D box
    local tl, tr, bl, br = self._topLeft, self._topRight, self._bottomLeft, self._bottomRight
    local haveBox = enabled and onScreen and options.box and tl ~= nil

    visible.box.Visible = haveBox
    visible.boxOutline.Visible = haveBox and options.boxOutline
    if haveBox then
        local size = br - tl
        local box = visible.box
        box.Position = tl
        box.Size = size
        box.Color = C(options.boxColor[1])
        box.Transparency = options.boxColor[2]

        local bo = visible.boxOutline
        bo.Position = tl
        bo.Size = size
        bo.Color = C(options.boxOutlineColor[1], true)
        bo.Transparency = options.boxOutlineColor[2]
    end

    -- box fill
    local haveFill = enabled and onScreen and options.boxFill and tl ~= nil
    visible.boxFill.Visible = haveFill
    if haveFill then
        local bf = visible.boxFill
        bf.Position = tl
        bf.Size = br - tl
        bf.Color = C(options.boxFillColor[1])
        bf.Transparency = options.boxFillColor[2]
    end

    -- health bar + outline + text
    local haveHB = enabled and onScreen and options.healthBar and tl ~= nil
    visible.healthBar.Visible = haveHB
    visible.healthBarOutline.Visible = haveHB and options.healthBarOutline
    if haveHB then
        local barFrom = tl - HEALTH_BAR_OFFSET
        local barTo = bl - HEALTH_BAR_OFFSET
        local ratio = (self.maxHealth > 0) and (self.health / self.maxHealth) or 0

        local hb = visible.healthBar
        hb.To = barTo
        hb.From = barTo:Lerp(barFrom, ratio)
        hb.Color = options.dyingColor:Lerp(options.healthyColor, ratio)

        local hbo = visible.healthBarOutline
        hbo.To = barTo + HEALTH_BAR_OUTLINE_OFFSET
        hbo.From = barFrom - HEALTH_BAR_OUTLINE_OFFSET
        hbo.Color = C(options.healthBarOutlineColor[1], true)
        hbo.Transparency = options.healthBarOutlineColor[2]
    end

    local haveHT = enabled and onScreen and options.healthText and tl ~= nil
    visible.healthText.Visible = haveHT
    if haveHT then
        local barFrom = tl - HEALTH_BAR_OFFSET
        local barTo = bl - HEALTH_BAR_OFFSET
        local ratio = (self.maxHealth > 0) and (self.health / self.maxHealth) or 0
        local healthRounded = round(self.health)

        local ht = visible.healthText
        -- only update expensive props if text changes
        if healthRounded ~= self._lastHealthRounded then
            self._lastHealthRounded = healthRounded
            ht.Text = tostring(healthRounded) .. "hp"
            ht.Size = interface.sharedSettings.textSize
            ht.Font = interface.sharedSettings.textFont
            self._healthTextBounds = ht.TextBounds
        end
        ht.Color = C(options.healthTextColor[1])
        ht.Transparency = options.healthTextColor[2]
        ht.Outline = options.healthTextOutline
        ht.OutlineColor = C(options.healthTextOutlineColor, true)
        ht.Position = barTo:Lerp(barFrom, ratio) - self._healthTextBounds * 0.5 - HEALTH_TEXT_OFFSET
    end

    -- name
    local haveName = enabled and onScreen and options.name and tl ~= nil
    visible.name.Visible = haveName
    if haveName then
        local nm = visible.name
        local newName = self.player.DisplayName
        if newName ~= self._lastName then
            self._lastName = newName
            nm.Text = newName
            nm.Size = interface.sharedSettings.textSize
            nm.Font = interface.sharedSettings.textFont
            self._nameTextBounds = nm.TextBounds
        end
        nm.Color = C(options.nameColor[1])
        nm.Transparency = options.nameColor[2]
        nm.Outline = options.nameOutline
        nm.OutlineColor = C(options.nameOutlineColor, true)
        nm.Position = (tl + tr) * 0.5 - Vector2.yAxis * self._nameTextBounds.Y - NAME_OFFSET
    end

    -- distance
    local haveDist = enabled and onScreen and options.distance and tl ~= nil and self.distance
    visible.distance.Visible = haveDist
    if haveDist then
        local distRounded = round(self.distance)
        local txt = tostring(distRounded) .. " studs"
        local d = visible.distance
        if distRounded ~= self._lastDistanceRounded then
            self._lastDistanceRounded = distRounded
            d.Text = txt
            d.Size = interface.sharedSettings.textSize
            d.Font = interface.sharedSettings.textFont
            self._distanceTextBounds = d.TextBounds
        end
        d.Color = C(options.distanceColor[1])
        d.Transparency = options.distanceColor[2]
        d.Outline = options.distanceOutline
        d.OutlineColor = C(options.distanceOutlineColor, true)
        d.Position = (bl + br) * 0.5 + DISTANCE_OFFSET
    end

    -- weapon (skip entirely if empty)
    local weaponVisible = enabled and onScreen and options.weapon and tl ~= nil and self._lastWeapon ~= "" and self._lastWeapon ~= nil
    visible.weapon.Visible = weaponVisible
    if weaponVisible then
        local w = visible.weapon
        local txt = "[ " .. self._lastWeapon .. " ]"
        if w.Text ~= txt then
            w.Text = txt
            w.Size = interface.sharedSettings.textSize
            w.Font = interface.sharedSettings.textFont
            self._weaponTextBounds = w.TextBounds
        end
        w.Color = C(options.weaponColor[1])
        w.Transparency = options.weaponColor[2]
        w.Outline = options.weaponOutline
        w.OutlineColor = C(options.weaponOutlineColor, true)
        local basePos = (bl + br) * 0.5
        if visible.distance.Visible then
            w.Position = basePos + DISTANCE_OFFSET + Vector2.yAxis * self._distanceTextBounds.Y
        else
            w.Position = basePos + DISTANCE_OFFSET
        end
    end

    -- tracer
    local haveTracer = enabled and onScreen and options.tracer and tl ~= nil
    visible.tracer.Visible = haveTracer
    visible.tracerOutline.Visible = haveTracer and options.tracerOutline
    if haveTracer then
        local toPos = (bl + br) * 0.5
        local fromPos =
            (options.tracerOrigin == "Middle" and (ViewportSize * 0.5))
            or (options.tracerOrigin == "Top" and (ViewportSize * Vector2.new(0.5, 0)))
            or (ViewportSize * Vector2.new(0.5, 1))

        local t = visible.tracer
        t.Color = C(options.tracerColor[1])
        t.Transparency = options.tracerColor[2]
        t.To = toPos
        t.From = fromPos

        local to = visible.tracerOutline
        to.Color = C(options.tracerOutlineColor[1], true)
        to.Transparency = options.tracerOutlineColor[2]
        to.To = toPos
        to.From = fromPos
    end

    -- offscreen arrow
    local haveArrow = enabled and (not onScreen) and options.offScreenArrow and self.direction ~= nil
    hidden.arrow.Visible = haveArrow
    hidden.arrowOutline.Visible = haveArrow and options.offScreenArrowOutline
    if haveArrow then
        local dir = self.direction
        local radius = options.offScreenArrowRadius
        local center = ViewportSize * 0.5
        local pad = 25
        local raw = center + dir * radius
        local clamped = Vector2.new(
            math.clamp(raw.X, pad, ViewportSize.X - pad),
            math.clamp(raw.Y, pad, ViewportSize.Y - pad)
        )
        local a = clamped
        local b = a - rotateVector(dir, 0.45) * options.offScreenArrowSize
        local c = a - rotateVector(dir, -0.45) * options.offScreenArrowSize

        local arr = hidden.arrow
        arr.PointA = a; arr.PointB = b; arr.PointC = c
        arr.Color = C(options.offScreenArrowColor[1])
        arr.Transparency = options.offScreenArrowColor[2]

        local aro = hidden.arrowOutline
        aro.PointA = a; aro.PointB = b; aro.PointC = c
        aro.Color = C(options.offScreenArrowOutlineColor[1], true)
        aro.Transparency = options.offScreenArrowOutlineColor[2]
    end

    -- 3D box edges
    local show3D = enabled and onScreen and options.box3d and self._cornersList ~= nil
    for i = 1, 4 do
        local face = box3d[i]
        for j = 1, 3 do
            local line = face[j]
            line.Visible = show3D
            if show3D then
                line.Color = C(options.box3dColor[1])
                line.Transparency = options.box3dColor[2]
            end
        end
        if show3D then
            local c = self._cornersList
            -- face i traces three edges (same indexing as your original)
            local i1 = i
            local i2 = (i == 4) and 1 or (i + 1)
            local i3 = (i == 4) and 5 or (i + 5)
            local i4 = (i == 4) and 8 or (i + 4)

            local l1, l2, l3 = face[1], face[2], face[3]
            l1.From = c[i1]; l1.To = c[i2]
            l2.From = c[i2]; l2.To = c[i3]
            l3.From = c[i3]; l3.To = c[i4]
        end
    end
end

-- cham object
local ChamObject = {}
ChamObject.__index = ChamObject

function ChamObject.new(player, interface)
    local self = setmetatable({}, ChamObject)
    self.player = player
    self.interface = interface
    self.highlight = Instance.new("Highlight")
    self.highlight.Parent = container
    self._char = nil

    player.CharacterAdded:Connect(function(char)
        self._char = char
    end)
    player.CharacterRemoving:Connect(function()
        self._char = nil
    end)
    self._char = player.Character

    return self
end

function ChamObject:Destruct()
    if self.highlight then self.highlight:Destroy() end
    clear(self)
end

function ChamObject:Update(dt)
    local interface = self.interface
    local character = self._char
    local options = interface.teamSettings[interface.isFriendly(self.player) and "friendly" or "enemy"]

    local enabled = options.enabled and character and not
        (#interface.whitelist > 0 and not table.find(interface.whitelist, self.player.UserId))

    local hl = self.highlight
    hl.Enabled = enabled and options.chams
    if not hl.Enabled then return end

    hl.Adornee = character
    hl.FillColor = parseColor(self, options.chamsFillColor[1])
    hl.FillTransparency = options.chamsFillColor[2]
    hl.OutlineColor = parseColor(self, options.chamsOutlineColor[1], true)
    hl.OutlineTransparency = options.chamsOutlineColor[2]
    hl.DepthMode = options.chamsVisibleOnly and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
end

-- instance label object
local InstanceObject = {}
InstanceObject.__index = InstanceObject

function InstanceObject.new(instance, options)
    local self = setmetatable({}, InstanceObject)
    self.instance = instance
    self.options = options or {}
    self.options.enabled = (self.options.enabled == nil) and true or self.options.enabled
    self.options.text = self.options.text or "{name}"
    self.options.textColor = self.options.textColor or { Color3.new(1,1,1), 1 }
    self.options.textOutline = (self.options.textOutline == nil) and true or self.options.textOutline
    self.options.textOutlineColor = self.options.textOutlineColor or Color3.new()
    self.options.textSize = self.options.textSize or 13
    self.options.textFont = self.options.textFont or 2
    self.options.limitDistance = self.options.limitDistance or false
    self.options.maxDistance = self.options.maxDistance or 150

    self.text = Drawing.new("Text")
    self.text.Center = true
    self._lastString = nil
    self._lastBounds = Vector2.zero

    return self
end

function InstanceObject:Destruct()
    if self.text then pcall(function() self.text:Remove() end) end
    clear(self)
end

function InstanceObject:Render(dt)
    local instance = self.instance
    if not instance or not instance.Parent then
        return self:Destruct()
    end

    local opts = self.options
    local text = self.text

    if not opts.enabled then
        text.Visible = false
        return
    end

    local world = instance:GetPivot().Position
    local pos, vis, depth = worldToScreen(world)
    if opts.limitDistance and depth > opts.maxDistance then
        vis = false
    end

    text.Visible = vis
    if not vis then return end

    -- Build string once if changed
    local s = opts.text
        :gsub("{name}", instance.Name)
        :gsub("{distance}", tostring(round(depth)))
        :gsub("{position}", tostring(world))

    if s ~= self._lastString then
        self._lastString = s
        text.Text = s
        text.Size = opts.textSize
        text.Font = opts.textFont
        self._lastBounds = text.TextBounds
    end

    text.Position = pos
    text.Color = opts.textColor[1]
    text.Transparency = opts.textColor[2]
    text.Outline = opts.textOutline
    text.OutlineColor = opts.textOutlineColor
end

-- interface
local EspInterface = {
    _hasLoaded = false,
    _objects = {},         -- [player] = { esp, cham }
    _instances = {},       -- array of InstanceObject
    _stepConn = nil,
    _vpConn = nil,

    whitelist = {},
    sharedSettings = {
        textSize = 13,
        textFont = 2,
        limitDistance = false,
        maxDistance = 150,
        useTeamColor = false,
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
            weaponOutlineColor = Color3.new(),
            distance = false,
            distanceColor = { Color3.new(1,1,1), 1 },
            distanceOutline = true,
            distanceOutlineColor = Color3.new(),
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
            chamsOutlineColor = { Color3.new(1,0,0), 0 },
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
            weaponOutlineColor = Color3.new(),
            distance = false,
            distanceColor = { Color3.new(1,1,1), 1 },
            distanceOutline = true,
            distanceOutlineColor = Color3.new(),
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
            chamsOutlineColor = { Color3.new(0,1,0), 0 },
        }
    }
}

-- game specific functions (optimized)
function EspInterface.getWeapon(player)
    local char = player and player.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") then
                return child.Name
            end
        end
    end
    -- backpack fallback (first tool only, else empty)
    local backpack = player and player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                return "[Backpack] " .. tool.Name
            end
        end
    end
    return "" -- important: empty means do not draw
end

function EspInterface.isFriendly(player)
    return player.Team ~= nil and player.Team == LocalPlayer.Team
end

function EspInterface.getTeamColor(player)
    local team = player.Team
    return team and team.TeamColor and team.TeamColor.Color
end

function EspInterface.getCharacter(player)
    -- No waiting; purely read-only and fast
    return player.Character
end

function EspInterface.getHealth(player)
    local char = player and player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        return hum.Health, hum.MaxHealth
    end
    return 100, 100
end

-- Public API
function EspInterface.AddInstance(instance, options)
    local obj = InstanceObject.new(instance, options or {})
    EspInterface._instances[#EspInterface._instances + 1] = obj
    return obj
end

function EspInterface.Load()
    assert(not EspInterface._hasLoaded, "Esp has already been loaded.")

    local function createFor(player)
        if player == LocalPlayer then return end
        if EspInterface._objects[player] then return end
        EspInterface._objects[player] = {
            EspObject.new(player, EspInterface),
            ChamObject.new(player, EspInterface)
        }
    end

    local function removeFor(player)
        local pack = EspInterface._objects[player]
        if pack then
            for i = 1, #pack do
                pack[i]:Destruct()
            end
            EspInterface._objects[player] = nil
        end
    end

    -- existing players
    for _, p in ipairs(Players:GetPlayers()) do
        createFor(p)
    end

    EspInterface._playerAdded = Players.PlayerAdded:Connect(createFor)
    EspInterface._playerRemoving = Players.PlayerRemoving:Connect(removeFor)

    -- keep viewport up-to-date
    EspInterface._vpConn = Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        ViewportSize = Camera.ViewportSize
    end)

    -- single render step loop
    EspInterface._stepConn = RunService.RenderStepped:Connect(function(dt)
        -- update + render players
        for _, pair in pairs(EspInterface._objects) do
            local esp, cham = pair[1], pair[2]
            esp:Update(dt)
            cham:Update(dt)
            esp:Render(dt)
        end
        -- render instance labels
        for i = #EspInterface._instances, 1, -1 do
            local inst = EspInterface._instances[i]
            if inst and inst.Render then
                inst:Render(dt)
            else
                table.remove(EspInterface._instances, i)
            end
        end
    end)

    EspInterface._hasLoaded = true
end

function EspInterface.Unload()
    assert(EspInterface._hasLoaded, "Esp has not been loaded yet.")

    -- clean up all player objects
    for _, pack in pairs(EspInterface._objects) do
        for i = 1, #pack do
            pack[i]:Destruct()
        end
    end
    EspInterface._objects = {}

    -- clean up instance labels
    for _, inst in ipairs(EspInterface._instances) do
        inst:Destruct()
    end
    EspInterface._instances = {}

    -- disconnect listeners
    if EspInterface._playerAdded then
        EspInterface._playerAdded:Disconnect()
        EspInterface._playerAdded = nil
    end
    if EspInterface._playerRemoving then
        EspInterface._playerRemoving:Disconnect()
        EspInterface._playerRemoving = nil
    end
    if EspInterface._stepConn then
        EspInterface._stepConn:Disconnect()
        EspInterface._stepConn = nil
    end
    if EspInterface._vpConn then
        EspInterface._vpConn:Disconnect()
        EspInterface._vpConn = nil
    end

    EspInterface._hasLoaded = false
end

return EspInterface
