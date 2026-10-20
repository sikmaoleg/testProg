-- Entry point: starts every server service and handles players joining, respawning and leaving
local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local WorldBuilder = require(script.Parent.WorldBuilder)
local MiningService = require(script.Parent.MiningService)
local CombatService = require(script.Parent.CombatService)
local ShopService = require(script.Parent.ShopService)

local function addNameTag(player, character)
	local root = character:WaitForChild("HumanoidRootPart")

	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(220, 44)
	gui.StudsOffset = Vector3.new(0, 3.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 300
	gui.Parent = root

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(235, 240, 255)
	label.TextStrokeTransparency = 0.5
	label.Parent = gui

	local function refresh()
		local title = player:GetAttribute("Title")
		local prefix = if title and title ~= "" then "[" .. title .. "] " else ""
		label.Text = prefix .. player.DisplayName
	end
	refresh()

	local connection = player:GetAttributeChangedSignal("Title"):Connect(refresh)
	gui.Destroying:Connect(function()
		connection:Disconnect()
	end)
end

local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	if not DataService.waitFor(player) then
		return
	end
	player:WaitForChild("Backpack")

	CombatService.equipLaser(player, humanoid)
	MonetizationService.applyCharacter(player, humanoid)
	MiningService.onCharacter(player, humanoid)
	addNameTag(player, character)
end

local function onPlayerAdded(player)
	-- Connect before loading so a character that spawns during the load is not missed
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	DataService.load(player)
	MonetizationService.checkOwnedPasses(player)

	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

WorldBuilder.build()
MonetizationService.init()
MiningService.init()
CombatService.init()
ShopService.init()
DataService.startAutosave()

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	DataService.release(player)
end)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Keeps the Zone attribute up to date; the client uses it for lighting and the HUD, enemies for aggro
task.spawn(function()
	while true do
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local zoneId = WorldBuilder.zoneAt(root.Position)
				if player:GetAttribute("Zone") ~= zoneId then
					player:SetAttribute("Zone", zoneId)
				end
			end
		end
		task.wait(0.5)
	end
end)

game:BindToClose(function()
	DataService.saveAll()
end)
