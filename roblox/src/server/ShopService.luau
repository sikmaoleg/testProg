-- Routes the menu buttons from the client (upgrades, purchases, travel, selling) and builds the profile view
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local MiningService = require(script.Parent.MiningService)
local QuestService = require(script.Parent.QuestService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local ShopService = {}

local ACTION_COOLDOWN = 0.25
local lastAction = setmetatable({}, { __mode = "k" })

local function buyUpgrade(player, key)
	local upgrade = Config.Upgrades[key]
	local data = DataService.get(player)
	if not upgrade or not data then
		return false, "Такого улучшения нет"
	end

	local level = data.Upgrades[key]
	if level >= upgrade.maxLevel then
		return false, "Уже максимальный уровень"
	end
	local cost = Config.upgradeCost(key, level)
	if data.Credits < cost then
		return false, "Не хватает кредитов: нужно " .. cost
	end

	DataService.addCredits(player, -cost)
	data.Upgrades[key] = level + 1
	return true, upgrade.name .. ": уровень " .. (level + 1)
end

local function buildProfileView(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	QuestService.refresh(player)

	local level = DataService.levelOf(data)

	local upgradeCost = {}
	for key in Config.Upgrades do
		upgradeCost[key] = Config.upgradeCost(key, data.Upgrades[key])
	end

	local quests = {}
	for _, quest in Config.Quests do
		table.insert(quests, {
			id = quest.id,
			name = quest.name,
			target = quest.target,
			reward = quest.reward,
			xp = quest.xp,
			progress = data.Quests.progress[quest.id] or 0,
			claimed = data.Quests.claimed[quest.id] == true,
		})
	end

	local zones = {}
	for _, zone in Config.Zones do
		table.insert(zones, {
			id = zone.id,
			name = zone.name,
			requiredLevel = zone.requiredLevel,
			unlocked = level >= zone.requiredLevel,
		})
	end

	return {
		credits = data.Credits,
		level = level,
		upgrades = data.Upgrades,
		upgradeCost = upgradeCost,
		passes = data.Passes,
		titles = data.Titles,
		donated = data.Donated,
		history = data.History,
		quests = quests,
		dailyReady = os.time() - data.LastDaily >= Config.DailyCooldown,
		dailyReward = Config.DailyReward,
		zones = zones,
	}
end

local actions = {
	BuyUpgrade = buyUpgrade,
	BuyPass = function(player, key)
		return MonetizationService.promptPass(player, key)
	end,
	BuyProduct = function(player, key)
		return MonetizationService.promptProduct(player, key)
	end,
	ClaimDaily = function(player)
		return QuestService.claimDaily(player)
	end,
	Teleport = function(player, zoneId)
		local ok, message = WorldBuilder.teleport(player, zoneId)
		return ok, message
	end,
	SellCargo = function(player)
		return MiningService.sell(player)
	end,
}

local function onAction(player, action, argument)
	if typeof(action) ~= "string" or (argument ~= nil and typeof(argument) ~= "string") then
		return false, "Некорректный запрос"
	end

	local now = os.clock()
	if now - (lastAction[player] or -math.huge) < ACTION_COOLDOWN then
		return false, "Слишком часто, подождите секунду"
	end
	lastAction[player] = now

	local handler = actions[action]
	if not handler then
		return false, "Неизвестное действие"
	end

	local ok, success, message = pcall(handler, player, argument)
	if not ok then
		warn("[ShopService] Ошибка действия " .. action .. ": " .. tostring(success))
		return false, "Что-то пошло не так, попробуйте ещё раз"
	end
	return success, message
end

function ShopService.init()
	Remotes.get("Action").OnServerInvoke = onAction
	Remotes.get("GetProfile").OnServerInvoke = function(player)
		return buildProfileView(player)
	end
end

return ShopService
