-- AimbotLib.lua (updated: adds executor GUI protection via protectgui)
-- Reusable Aimbot library. Creates a ScreenGui and calls protectgui() when available.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local DrawingAvailable = (typeof(Drawing) == "table")
local LocalPlayer = Players.LocalPlayer

local Aimbot = {}
Aimbot.__index = Aimbot

local DEFAULTS = {
    Enabled = false,
    Radius = 50,
    TargetPart = "Head",
    TeamCheck = true,
    WallCheck = true,
    AutoPrediction = false,
    Prediction = 0.143,
    Smoothness = 0.2,
    Offset = Vector2.new(0,0),
    FovVisible = true,
    FovFilled = false,
    FovColor = Color3.fromRGB(100,70,200),
    DrawZIndex = 0,
    -- NEW GUI options
    UseGui = true,             -- create a ScreenGui for status/indicator
    GuiVisible = true,         -- whether the gui is visible
    GuiParent = nil,           -- optional parent (defaults to gethui() or CoreGui)
}

-- Helper to safely call protectgui if present
local function tryProtectGui(gui)
    if not gui then return false end
    local ok, err = pcall(function()
        if typeof(protectgui) == "function" then
            protectgui(gui)
        elseif typeof(protect_gui) == "function" then
            protect_gui(gui)
        end
    end)
    return ok
end

-- Helper: choose parent for protected UI (executor-friendly)
local function chooseGuiParent(custom)
    if custom and typeof(custom) == "Instance" and custom.Parent then
        return custom
    end
    if typeof(gethui) == "function" then
        local ok, gh = pcall(gethui)
        if ok and typeof(gh) == "Instance" and gh.Parent then
            return gh
        end
    end
    return game:GetService("CoreGui")
end

function Aimbot.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Aimbot)

    self.Config = {}
    for k,v in pairs(DEFAULTS) do
        self.Config[k] = (opts[k] ~= nil) and opts[k] or v
    end

    -- allow user to override GuiParent by passing an Instance in opts.GuiParent
    self._guiParent = chooseGuiParent(opts.GuiParent)

    self.Camera = Workspace.CurrentCamera
    self._screenCenter = Vector2.new(self.Camera.ViewportSize.X/2, self.Camera.ViewportSize.Y/2)
    self._targetCache = nil
    self._conn = nil
    self._draw = {}
    self._lastViewport = self.Camera.ViewportSize
    self._screenGui = nil
    self._statusLabel = nil
    self._indicatorFrame = nil

    -- create Drawing visuals if available (unchanged)
    if DrawingAvailable then
        local circle = Drawing.new("Circle")
        circle.Visible = false
        circle.Radius = self.Config.Radius
        circle.Position = self:calculateFovPosition()
        circle.Color = self.Config.FovColor
        circle.Filled = self.Config.FovFilled
        circle.Thickness = 1
        circle.ZIndex = self.Config.DrawZIndex

        local indicator = Drawing.new("Circle")
        indicator.Visible = false
        indicator.Radius = 4
        indicator.Filled = true
        indicator.Transparency = 0.6
        indicator.Color = self.Config.FovColor
        indicator.ZIndex = self.Config.DrawZIndex

        self._draw.fov = circle
        self._draw.indicator = indicator
    end

    -- create protected ScreenGui if requested
    if self.Config.UseGui then
        local success, gui = pcall(function()
            local sg = Instance.new("ScreenGui")
            sg.Name = "AimbotUI_" .. tostring(math.random(1000,9999))
            sg.ResetOnSpawn = false
            sg.Parent = self._guiParent

            -- status label (top-left small)
            local lbl = Instance.new("TextLabel")
            lbl.Name = "AimbotStatus"
            lbl.Size = UDim2.new(0,140,0,28)
            lbl.Position = UDim2.new(0,12,0,12)
            lbl.BackgroundTransparency = 0.4
            lbl.BackgroundColor3 = Color3.fromRGB(20,20,20)
            lbl.BorderSizePixel = 0
            lbl.TextColor3 = Color3.fromRGB(255,255,255)
            lbl.TextSize = 14
            lbl.Font = Enum.Font.SourceSansSemibold
            lbl.Text = self.Config.Enabled and "Aimbot: ON" or "Aimbot: OFF"
            lbl.Parent = sg
            lbl.Visible = self.Config.GuiVisible

            -- small indicator frame (center of screen) - used as UI fallback or extra visible element
            local ind = Instance.new("Frame")
            ind.Name = "AimbotIndicator"
            ind.Size = UDim2.new(0,8,0,8)
            ind.AnchorPoint = Vector2.new(0.5,0.5)
            ind.Position = UDim2.new(0.5,0,0.5,0)
            ind.BorderSizePixel = 0
            ind.BackgroundColor3 = self.Config.FovColor
            ind.BackgroundTransparency = 0.2
            ind.Visible = self.Config.GuiVisible
            ind.Parent = sg

            -- small rounding using UICorner if available
            if pcall(function() return Instance.new("UICorner") end) then
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(1,0)
                corner.Parent = ind
            end

            return sg, lbl, ind
        end)
        if success and type(gui) == "table" then
            self._screenGui = gui[1]
            self._statusLabel = gui[2]
            self._indicatorFrame = gui[3]
        elseif success and typeof(gui) == "Instance" then
            -- in case pcall returned single Instance (older branch)
            self._screenGui = gui
        end

        -- attempt to protect the created GUI using executor API (silently ignore failure)
        pcall(function() tryProtectGui(self._screenGui) end)
    end

    self._onRender = function(dt) self:_renderStep(dt) end

    self.Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        self._lastViewport = self.Camera.ViewportSize
    end)

    return self
end

-- new helpers: toggle gui visibility and update status label safely
function Aimbot:_setGuiVisible(v)
    if not self._screenGui then return end
    local vis = not not v
    if self._statusLabel then self._statusLabel.Visible = vis end
    if self._indicatorFrame then self._indicatorFrame.Visible = vis end
end

function Aimbot:_updateGuiStatus(enabled)
    if not self._screenGui then return end
    if self._statusLabel then
        local ok = pcall(function()
            self._statusLabel.Text = enabled and "Aimbot: ON" or "Aimbot: OFF"
        end)
    end
end

-- Public API additions (GUI control)
function Aimbot:SetUseGui(enabled)
    self.Config.UseGui = not not enabled
    if self.Config.UseGui and not self._screenGui then
        -- create minimal GUI now
        -- (reuse constructor code - simple recreation)
        local parent = self._guiParent
        local sg = Instance.new("ScreenGui")
        sg.Name = "AimbotUI_" .. tostring(math.random(1000,9999))
        sg.ResetOnSpawn = false
        sg.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Name = "AimbotStatus"
        lbl.Size = UDim2.new(0,140,0,28)
        lbl.Position = UDim2.new(0,12,0,12)
        lbl.BackgroundTransparency = 0.4
        lbl.BackgroundColor3 = Color3.fromRGB(20,20,20)
        lbl.BorderSizePixel = 0
        lbl.TextColor3 = Color3.fromRGB(255,255,255)
        lbl.TextSize = 14
        lbl.Font = Enum.Font.SourceSansSemibold
        lbl.Text = self.Config.Enabled and "Aimbot: ON" or "Aimbot: OFF"
        lbl.Parent = sg

        local ind = Instance.new("Frame")
        ind.Name = "AimbotIndicator"
        ind.Size = UDim2.new(0,8,0,8)
        ind.AnchorPoint = Vector2.new(0.5,0.5)
        ind.Position = UDim2.new(0.5,0,0.5,0)
        ind.BorderSizePixel = 0
        ind.BackgroundColor3 = self.Config.FovColor
        ind.BackgroundTransparency = 0.2
        ind.Parent = sg

        if pcall(function() return Instance.new("UICorner") end) then
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1,0)
            corner.Parent = ind
        end

        self._screenGui = sg
        self._statusLabel = lbl
        self._indicatorFrame = ind

        pcall(function() tryProtectGui(self._screenGui) end)
    elseif not self.Config.UseGui and self._screenGui then
        pcall(function() self._screenGui:Destroy() end)
        self._screenGui = nil
        self._statusLabel = nil
        self._indicatorFrame = nil
    end
end

function Aimbot:SetGuiVisible(v)
    self.Config.GuiVisible = not not v
    self:_setGuiVisible(self.Config.GuiVisible)
end

-- rest of previously provided API unchanged (SetEnabled, SetRadius, etc.)
function Aimbot:SetEnabled(v)
    v = not not v
    if v == self.Config.Enabled then return end
    self.Config.Enabled = v
    if v then
        self:_start()
    else
        self:_stop()
    end
    -- update GUI indicator
    self:_updateGuiStatus(v)
end

function Aimbot:SetRadius(px)
    self.Config.Radius = math.max(0, px or 0)
    if self._draw.fov then self._draw.fov.Radius = self.Config.Radius end
end

function Aimbot:SetTargetPart(name)
    self.Config.TargetPart = tostring(name or "Head")
end

function Aimbot:SetSmoothness(v)
    self.Config.Smoothness = math.clamp(tonumber(v) or 0, 0, 1)
end

function Aimbot:SetPrediction(v)
    self.Config.Prediction = tonumber(v) or 0
end

function Aimbot:SetTeamCheck(enabled)
    self.Config.TeamCheck = not not enabled
end

function Aimbot:SetWallCheck(enabled)
    self.Config.WallCheck = not not enabled
end

function Aimbot:SetFovVisibility(visible)
    self.Config.FovVisible = not not visible
    if self._draw.fov then self._draw.fov.Visible = visible and self.Config.Enabled end
    if self._screenGui and self._indicatorFrame then
        self._indicatorFrame.Visible = visible and self.Config.Enabled and self.Config.GuiVisible
    end
end

function Aimbot:SetFovColor(col)
    self.Config.FovColor = col or self.Config.FovColor
    if self._draw.fov then self._draw.fov.Color = self.Config.FovColor end
    if self._draw.indicator then self._draw.indicator.Color = self.Config.FovColor end
    if self._indicatorFrame then
        pcall(function() self._indicatorFrame.BackgroundColor3 = self.Config.FovColor end)
    end
end

function Aimbot:SetOffset(vec2)
    if typeof(vec2) == "Vector2" then
        self.Config.Offset = vec2
    end
end

function Aimbot:GetClosestTarget()
    return self:_getClosestTarget()
end

function Aimbot:ForceAimAt(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local part = targetPlayer.Character:FindFirstChild(self.Config.TargetPart)
    if part then
        self:_visualAim(part)
    end
end

function Aimbot:Destroy()
    self:_stop()
    if self._draw.fov then
        pcall(function() self._draw.fov:Remove() end)
    end
    if self._draw.indicator then
        pcall(function() self._draw.indicator:Remove() end)
    end
    if self._screenGui then
        pcall(function() self._screenGui:Destroy() end)
    end
    self._draw = {}
end

-- internal helper functions (same as before)
function Aimbot:_start()
    if self._conn then return end
    self._conn = RunService.RenderStepped:Connect(self._onRender)
    if self._draw.fov then
        self._draw.fov.Visible = self.Config.FovVisible and self.Config.Enabled
    end
    if self._screenGui then
        self._screenGui.Enabled = true
        self:_setGuiVisible(self.Config.GuiVisible)
    end
end

function Aimbot:_stop()
    if self._conn then
        self._conn:Disconnect()
        self._conn = nil
    end
    if self._draw.fov then
        self._draw.fov.Visible = false
    end
    if self._draw.indicator then
        self._draw.indicator.Visible = false
    end
    if self._screenGui then
        -- keep the GUI present but hidden so it's still protected; simply hide elements
        self:_setGuiVisible(false)
    end
end

function Aimbot:_buildRaycastParams()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.IgnoreWater = true
    local list = {}
    if LocalPlayer.Character then
        table.insert(list, LocalPlayer.Character)
        for _, item in ipairs(LocalPlayer.Character:GetChildren()) do
            if item:IsA("Tool") or item:IsA("Accessory") or item:IsA("Hat") or item:IsA("Shirt") or item:IsA("Pants") then
                table.insert(list, item)
            end
        end
    end
    for _, c in ipairs(Workspace:GetChildren()) do
        if c == self.Camera or c.Parent == self.Camera then
            table.insert(list, c)
        end
    end
    params.FilterDescendantsInstances = list
    return params
end

function Aimbot:_predict(pos, vel, dist)
    if self.Config.AutoPrediction and dist and dist > 0 then
        return pos + (vel * (dist / 500))
    elseif self.Config.Prediction and self.Config.Prediction > 0 then
        return pos + (vel * self.Config.Prediction)
    end
    return pos
end

function Aimbot:_aimCFrameFor(part)
    local camPos = self.Camera.CFrame.Position
    local pos = part.Position
    local dist = (camPos - pos).Magnitude
    local lookAt = self:_predict(pos, (part.Velocity or Vector3.new()), dist)
    return CFrame.lookAt(camPos, lookAt)
end

function Aimbot:_visualAim(part)
    if not (part and part.Parent) then return end
    local cf = self:_aimCFrameFor(part)
    local s = math.clamp(self.Config.Smoothness or 0.2, 0, 1)
    pcall(function()
        self.Camera.CFrame = self.Camera.CFrame:Lerp(cf, s)
    end)
end

function Aimbot:_isAlive(plr)
    if not plr then return false end
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

function Aimbot:_sameTeam(plr)
    if not self.Config.TeamCheck then return false end
    if not LocalPlayer then return false end
    local lt, pt = LocalPlayer.Team, plr.Team
    return lt and pt and (lt == pt)
end

function Aimbot:_canSee(part)
    if not part or not part.Parent then return false end
    local origin = self.Camera.CFrame.Position
    local dir = (part.Position - origin)
    local params = self:_buildRaycastParams()
    local ok, res = pcall(function()
        return Workspace:Raycast(origin, dir, params)
    end)
    if not ok then return false end
    return (not res) or res.Instance:IsDescendantOf(part.Parent)
end

function Aimbot:calculateFovPosition()
    local vp = self.Camera.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    return center + self.Config.Offset
end

function Aimbot:_getClosestTarget()
    local best = nil
    local bestD2 = (self.Config.Radius * self.Config.Radius)
    local cam = self.Camera
    local fovPos = self:calculateFovPosition()
    local list = Players:GetPlayers()
    for i = 1, #list do
        local plr = list[i]
        if plr ~= LocalPlayer and self:_isAlive(plr) and (not self:_sameTeam(plr)) then
            local char = plr.Character
            local part = char and char:FindFirstChild(self.Config.TargetPart)
            if part then
                if (not self.Config.WallCheck) or self:_canSee(part) then
                    local sp, onScreen = cam:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local delta = Vector2.new(sp.X, sp.Y) - fovPos
                        local d2 = delta.X * delta.X + delta.Y * delta.Y
                        if d2 < bestD2 then
                            bestD2 = d2
                            best = plr
                        end
                    end
                end
            end
        end
    end
    return best
end

function Aimbot:_updateDraws(target)
    if self._draw.fov then
        self._draw.fov.Position = self:calculateFovPosition()
        self._draw.fov.Radius = self.Config.Radius
        self._draw.fov.Color = self.Config.FovColor
        self._draw.fov.Filled = self.Config.FovFilled
        self._draw.fov.Visible = (self.Config.Enabled and self.Config.FovVisible)
    end
    if self._draw.indicator then
        self._draw.indicator.Visible = false
        if target and target.Character then
            local part = target.Character:FindFirstChild(self.Config.TargetPart)
            if part then
                local sp, onScreen = self.Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    self._draw.indicator.Visible = true
                    self._draw.indicator.Position = Vector2.new(sp.X, sp.Y)
                end
            end
        end
    end

    -- update GUI indicator (center) and status label
    if self._screenGui and self._indicatorFrame then
        pcall(function()
            if target and target.Character then
                local part = target.Character:FindFirstChild(self.Config.TargetPart)
                if part then
                    local sp, onScreen = self.Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        -- place Frame at screen X/Y (roblox UI uses scale+offset; convert)
                        local x = math.clamp(sp.X, 0, self.Camera.ViewportSize.X)
                        local y = math.clamp(sp.Y, 0, self.Camera.ViewportSize.Y)
                        self._indicatorFrame.Position = UDim2.new(0, x, 0, y)
                        self._indicatorFrame.Visible = true and self.Config.GuiVisible
                    else
                        self._indicatorFrame.Visible = false
                    end
                end
            else
                -- no target: place indicator at center if FOV visible, otherwise hide
                if self.Config.FovVisible then
                    local center = self:calculateFovPosition()
                    self._indicatorFrame.Position = UDim2.new(0, center.X, 0, center.Y)
                    self._indicatorFrame.Visible = self.Config.GuiVisible
                else
                    self._indicatorFrame.Visible = false
                end
            end
        end)
    end
end

function Aimbot:_renderStep(dt)
    self.Camera = Workspace.CurrentCamera
    local vp = self.Camera.ViewportSize
    if vp ~= self._lastViewport then
        self._lastViewport = vp
    end

    if not self.Config.Enabled then
        self:_updateDraws(nil)
        return
    end

    local closest = self:_getClosestTarget()
    if closest and closest.Character then
        local part = closest.Character:FindFirstChild(self.Config.TargetPart)
        if part then
            self:_visualAim(part)
        end
    end

    if closest ~= self._targetCache then
        self._targetCache = closest
    end

    self:_updateDraws(closest)
end

return Aimbot
