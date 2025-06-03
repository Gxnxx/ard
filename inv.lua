local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Drawing objects
local drawings = {}
local backgroundBox

local function getDrawingText(index)
	if not drawings[index] then
		local text = Drawing.new("Text")
		text.Size = 18
		text.Color = Color3.fromRGB(255, 255, 255)
		text.Outline = true
		text.Center = false
		text.Font = 2
		text.Visible = false
		drawings[index] = text
	end
	return drawings[index]
end

local function initBackground()
	if not backgroundBox then
		backgroundBox = Drawing.new("Square")
		backgroundBox.Color = Color3.fromRGB(20, 20, 20)
		backgroundBox.Transparency = 0.6
		backgroundBox.Filled = true
		backgroundBox.Visible = false
	end
end

local function clearDrawings()
	for _, drawing in pairs(drawings) do
		drawing.Visible = false
	end
	if backgroundBox then
		backgroundBox.Visible = false
	end
end

-- Toggle key & FOV config
local enabled = false
local FOV_RADIUS = 250
local TOGGLE_KEY = Enum.KeyCode.F2

-- Get target closest to mouse within FOV
local function getTargetInFOV()
	local closest = nil
	local minDist = FOV_RADIUS
	for _, player in pairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local root = player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
				if onScreen then
					local mousePos = UserInputService:GetMouseLocation()
					local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
					if dist < minDist then
						minDist = dist
						closest = player
					end
				end
			end
		end
	end
	return closest
end

-- Draw inventory info
local function renderInventory()
	clearDrawings()
	if not enabled then return end
	local target = getTargetInFOV()
	if not target then return end

	local gunInventory = target:FindFirstChild("GunInventory")
	if not gunInventory then return end

	local startX, startY = 100, 100
	local lineHeight = 20
	local index = 1

	initBackground()

	local header = getDrawingText(index)
	header.Text = target.Name .. "'s Inventory:"
	header.Position = Vector2.new(startX, startY)
	header.Visible = true
	index += 1

	for _, item in ipairs(gunInventory:GetChildren()) do
		if item:IsA("ObjectValue") then
			local slot = item:FindFirstChild("Slot")
			local name = item.Value or "Empty"
			local mag = item:FindFirstChild("BulletsInMagazine")
			local res = item:FindFirstChild("BulletsInReserve")
			local muzzle = item:FindFirstChild("AttachmentMuzzle")
			local reticle = item:FindFirstChild("AttachmentReticle")

			local line = {slot and slot.Value or "?"} -> {name} [{mag and mag.Value or "--"}/{res and res.Value or "--"}] [{muzzle and muzzle.Value or "--"}/{reticle and reticle.Value or "--"}]

			local text = getDrawingText(index)
			text.Text = line
			text.Position = Vector2.new(startX, startY + lineHeight * (index - 1))
			text.Visible = true
			index += 1
		end
	end

	-- Set background size
	backgroundBox.Size = Vector2.new(600, (index - 1) * lineHeight + 4)
	backgroundBox.Position = Vector2.new(startX - 6, startY - 4)
	backgroundBox.Visible = true
end

-- Toggle key
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == TOGGLE_KEY then
		enabled = not enabled
		if not enabled then clearDrawings() end
	end
end)

-- Update loop
RunService.RenderStepped:Connect(renderInventory)
