-- Ore nodes in every zone, cargo that is lost on death, and the trade terminal at the station
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local QuestService = require(script.Parent.QuestService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local MiningService = {}

local cargoByPlayer = setmetatable({}, { __mode = "k" }) -- player -> { zoneId = count }

local function cargoTotal(bag)
	local total = 0
	for _, count in bag do
		total += count
	end
	return total
end

local function cargoMax(player)
	local data = DataService.get(player)
	if not data then
		return Config.Mining.cargoBase
	end
	local max = Config.Mining.cargoBase + data.Upgrades.cargo * Config.Mining.cargoPerLevel
	if data.Passes.cargo then
		max += Config.Mining.cargoPassBonus
	end
	return max
end

local function publish(player)
	local bag = cargoByPlayer[player] or {}
	player:SetAttribute("Cargo", cargoTotal(bag))
	player:SetAttribute("CargoMax", cargoMax(player))
end

local function mine(player, zone)
	local data = DataService.get(player)
	local bag = cargoByPlayer[player]
	if not data or not bag then
		return false
	end

	local max = cargoMax(player)
	local total = cargoTotal(bag)
	if total >= max then
		Remotes.notify(player, "Трюм полон — продайте руду на станции", "bad")
		return false
	end

	local amount = math.min(1 + math.floor(data.Upgrades.mining / 3), max - total)
	bag[zone.id] = (bag[zone.id] or 0) + amount
	data.Stats.mined += amount
	DataService.addXP(player, amount * 2)
	QuestService.add(player, "mine", amount)
	publish(player)
	return true
end

local function spawnOre(zone, folder)
	local angle = math.random() * math.pi * 2
	local distance = math.random(25, 95)
	local position = zone.center + Vector3.new(math.cos(angle) * distance, 1.5, math.sin(angle) * distance)

	local node = Instance.new("Part")
	node.Name = "OreNode"
	node.Anchored = true
	node.Size = Vector3.new(3, 3, 3)
	node.CFrame = CFrame.new(position) * CFrame.Angles(math.random(), math.random(), math.random())
	node.Color = zone.ore.color
	node.Material = zone.ore.material
	node.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Добыть: " .. zone.ore.name
	prompt.ObjectText = zone.ore.name
	prompt.HoldDuration = Config.Mining.holdSeconds
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		if not prompt.Enabled or not mine(player, zone) then
			return
		end
		prompt.Enabled = false
		node.Transparency = 1
		task.delay(Config.Mining.respawnSeconds, function()
			node.Transparency = 0
			prompt.Enabled = true
		end)
	end)
	prompt.Parent = node
end

local function buildTerminal(folder)
	local terminal = Instance.new("Part")
	terminal.Name = "TradeTerminal"
	terminal.Anchored = true
	terminal.Size = Vector3.new(8, 6, 3)
	terminal.CFrame = CFrame.new(Config.Hub.center + Vector3.new(40, 3, 0))
	terminal.Color = Color3.fromRGB(40, 50, 80)
	terminal.Material = Enum.Material.Metal
	terminal.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Продать руду"
	prompt.ObjectText = "Торговый терминал"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		local ok, message = MiningService.sell(player)
		Remotes.notify(player, message, ok and "good" or "bad")
	end)
	prompt.Parent = terminal
end

function MiningService.onCharacter(player, humanoid)
	cargoByPlayer[player] = {}
	publish(player)
	humanoid.Died:Connect(function()
		local bag = cargoByPlayer[player]
		if bag and cargoTotal(bag) > 0 then
			Remotes.notify(player, "Корабль уничтожен — груз потерян", "bad")
		end
		cargoByPlayer[player] = nil
	end)
end

function MiningService.sell(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or WorldBuilder.zoneAt(root.Position) ~= Config.Hub.id then
		return false, "Продавать руду можно только на станции"
	end

	local bag = cargoByPlayer[player]
	if not bag or cargoTotal(bag) == 0 then
		return false, "Трюм пуст"
	end

	local total = 0
	for zoneId, count in bag do
		total += count * Config.ZoneById[zoneId].ore.value
	end
	cargoByPlayer[player] = {}
	publish(player)

	local earned = DataService.reward(player, total)
	return true, "Продано за " .. earned .. " кредитов"
end

function MiningService.init()
	for _, zone in Config.Zones do
		local folder = WorldBuilder.zones[zone.id]
		for _ = 1, Config.Mining.nodesPerZone do
			spawnOre(zone, folder)
		end
	end
	buildTerminal(WorldBuilder.hubFolder)

	task.spawn(function()
		while true do
			task.wait(1)
			for player in pairs(cargoByPlayer) do
				publish(player)
			end
		end
	end)
end

return MiningService
