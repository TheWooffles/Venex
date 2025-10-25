-- Simple Head Lock Script using mousemoverel
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

-- Global aim lock options
getgenv().AimLock = getgenv().AimLock or {
    Enabled = false,
    TargetPlayer = nil,
    Smoothness = 0.15,  -- Lower = smoother (0.1-0.3 recommended)
    PredictionStrength = 0.1,  -- Velocity prediction
    MaxDistance = 500,  -- Maximum lock distance
}

local isLocking = false
local targetPlayer = nil

-- Function to check if target is behind a wall
local function isTargetVisible(targetHead)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Head") then
        return false
    end
    
    local origin = Camera.CFrame.Position
    local direction = (targetHead.Position - origin).Unit * (targetHead.Position - origin).Magnitude
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, targetPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local rayResult = workspace:Raycast(origin, direction, raycastParams)
    
    -- If raycast hits something, target is behind a wall
    return rayResult == nil
end

-- Function to get the closest player to the mouse
local function getClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
            local head = player.Character.Head
            local headPos = head.Position
            local distance = (LocalPlayer.Character.Head.Position - headPos).Magnitude
            
            -- Check if within max distance
            if distance <= getgenv().AimLock.MaxDistance then
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

-- Handle Q key toggle
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.Q and not gameProcessed then
        isLocking = not isLocking
        getgenv().AimLock.Enabled = isLocking
        
        if isLocking then
            targetPlayer = getClosestPlayer()
            getgenv().AimLock.TargetPlayer = targetPlayer
            if targetPlayer then
                print("Head lock ENABLED - Locked onto: " .. targetPlayer.Name)
            else
                print("Head lock ENABLED - No valid target found")
                isLocking = false
                getgenv().AimLock.Enabled = false
            end
        else
            print("Head lock DISABLED")
            targetPlayer = nil
            getgenv().AimLock.TargetPlayer = nil
        end
    end
end)

-- Main lock loop with smooth movement
RunService.RenderStepped:Connect(function()
    if isLocking and targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Head") then
        local head = targetPlayer.Character.Head
        local headPos = head.Position
        
        -- Predict movement based on velocity
        if targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = targetPlayer.Character.HumanoidRootPart
            local velocity = hrp.Velocity or hrp.AssemblyLinearVelocity or Vector3.new(0, 0, 0)
            headPos = headPos + (velocity * getgenv().AimLock.PredictionStrength)
        end
        
        local screenPos, onScreen = Camera:WorldToScreenPoint(headPos)
        
        -- Check if target is visible (not behind wall)
        if onScreen and isTargetVisible(head) then
            local mousePos = Vector2.new(Mouse.X, Mouse.Y)
            local targetPos = Vector2.new(screenPos.X, screenPos.Y)
            local delta = targetPos - mousePos
            
            -- Apply smoothness for natural movement
            local smoothDelta = delta * getgenv().AimLock.Smoothness
            
            -- Use mousemoverel with smoothed delta
            mousemoverel(smoothDelta.X, smoothDelta.Y)
        elseif not onScreen then
            -- If target goes off screen, stop locking
            isLocking = false
            targetPlayer = nil
            getgenv().AimLock.Enabled = false
            getgenv().AimLock.TargetPlayer = nil
            print("Target lost - Press Q to re-enable")
        end
    end
end)

print("Head lock script loaded. Press Q to toggle lock on/off.")
print("Customize settings: getgenv().AimLock.Smoothness, .PredictionStrength, .MaxDistance")