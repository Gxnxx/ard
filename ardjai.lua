local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local espObjects = {}      -- player -> esp drawings
local linkedModels = {}    -- player -> model

local DISTANCE_THRESHOLD = 10
local MAX_MODEL_DISTANCE = 100

local ESPEnabled = true -- ESP toggle state

local skeletonJoints = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LowerTorso", "RightUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
    {"UpperTorso", "LeftUpperArm"},
    {"UpperTorso", "RightUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
}

local function NewLine()
    local line = Drawing.new("Line")
    line.Color = Color3.fromRGB(255, 255, 255)
    line.Thickness = 2
    line.Transparency = 1
    line.Visible = false
    return line
end

local function createESP(player)
    local nameDrawing = Drawing.new("Text")
    nameDrawing.Size = 14
    nameDrawing.Center = true
    nameDrawing.Outline = true
    nameDrawing.Font = 2
    nameDrawing.Color = Color3.fromRGB(255, 255, 255)
    nameDrawing.Visible = false

    local skeletonLines = {}
    espObjects[player] = {
        name = nameDrawing,
        skeleton = skeletonLines
    }
end

local function project(pos)
    local vec, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(vec.X, vec.Y), onScreen
end

local function findClosestModel(player)
    local playerChar = player.Character
    if not playerChar then return nil end
    local playerHRP = playerChar:FindFirstChild("HumanoidRootPart")
    if not playerHRP then return nil end

    local closestModel = nil
    local shortestDistance = math.huge

    for _, model in pairs(Workspace:WaitForChild("Characters"):GetChildren()) do
        if model:IsA("Model") then
            local modelHRP = model:FindFirstChild("HumanoidRootPart")
            if modelHRP then
                local dist = (modelHRP.Position - playerHRP.Position).Magnitude
                if dist < shortestDistance then
                    shortestDistance = dist
                    closestModel = model
                end
            end
        end
    end

    return closestModel, shortestDistance
end

local function clearSkeleton(skeletonLines)
    for _, line in ipairs(skeletonLines) do
        line.Visible = false
    end
end

local function getLinkedModel(player)
    local cachedModel = linkedModels[player]
    local cachedDist = math.huge

    if cachedModel and cachedModel.Parent then
        local hrp = cachedModel:FindFirstChild("HumanoidRootPart")
        local playerHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if hrp and playerHRP then
            cachedDist = (hrp.Position - playerHRP.Position).Magnitude
            if cachedDist > MAX_MODEL_DISTANCE then
                linkedModels[player] = nil
                cachedModel = nil
            end
        else
            linkedModels[player] = nil
            cachedModel = nil
        end
    else
        linkedModels[player] = nil
        cachedModel = nil
    end

    local closestModel, closestDist = findClosestModel(player)

    if closestModel then
        if not cachedModel then
            linkedModels[player] = closestModel
            return closestModel
        else
            if closestDist + DISTANCE_THRESHOLD < cachedDist then
                linkedModels[player] = closestModel
                return closestModel
            else
                return cachedModel
            end
        end
    end

    return cachedModel
end

local function updateESP()
    if not ESPEnabled then
        -- Hide all ESP drawings when disabled
        for player, drawings in pairs(espObjects) do
            drawings.name.Visible = false
            clearSkeleton(drawings.skeleton)
        end
        return
    end

    for player, drawings in pairs(espObjects) do
        local model = getLinkedModel(player)
        if not model then
            drawings.name.Visible = false
            clearSkeleton(drawings.skeleton)
            continue
        end

        local head = model:FindFirstChild("Head")
        local hrp = model:FindFirstChild("HumanoidRootPart")
        if not head or not hrp or not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            drawings.name.Visible = false
            clearSkeleton(drawings.skeleton)
            continue
        end

        local dist = (hrp.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude

        local namePos, nameOnScreen = project(head.Position + Vector3.new(0, 1.5, 0))
        if nameOnScreen then
            drawings.name.Position = namePos
            drawings.name.Text = string.format("%s [%.1f]", player.Name, dist)
            drawings.name.Visible = true
        else
            drawings.name.Visible = false
        end

        local neededLines = #skeletonJoints
        while #drawings.skeleton < neededLines do
            table.insert(drawings.skeleton, NewLine())
        end

        for i, jointPair in ipairs(skeletonJoints) do
            local partA = model:FindFirstChild(jointPair[1])
            local partB = model:FindFirstChild(jointPair[2])
            local line = drawings.skeleton[i]

            if partA and partB then
                local posA, onScreenA = project(partA.Position)
                local posB, onScreenB = project(partB.Position)

                if onScreenA and onScreenB then
                    line.From = posA
                    line.To = posB
                    line.Visible = true
                else
                    line.Visible = false
                end
            else
                line.Visible = false
            end
        end
    end
end

-- Toggle ESP on/off with F1 key
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F1 then
        ESPEnabled = not ESPEnabled
    end
end)

-- Initialize ESP for existing players
for _, player in pairs(Players:GetPlayers()) do
    createESP(player)
end

Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(function(player)
    if espObjects[player] then
        espObjects[player].name.Visible = false
        clearSkeleton(espObjects[player].skeleton)
        espObjects[player] = nil
        linkedModels[player] = nil
    end
end)

RunService.RenderStepped:Connect(updateESP)
