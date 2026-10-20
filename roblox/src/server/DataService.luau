-- Stores player profiles in a DataStore and owns credits, XP, titles and the purchase history
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService = {}

-- In Studio an unpublished place throws here; the game should still run without saving
local store
local storeOk, storeError = pcall(function()
	store = DataStoreService:GetDataStore("StarEmpire_Profiles_v1")
end)
if not storeOk then
	warn("[DataService] DataStore недоступен, прогресс не сохраняется: " .. tostring(storeError))
end

local profiles = {} -- player -> { data = table, canSave = boolean }

local function defaultProfile()
	return {
		Credits = 0,
		XP = 0,
		Upgrades = { damage = 0, mining = 0, cargo = 0 },
		Passes = {},
		Titles = {},
		Donated = 0,
		LastDaily = 0,
		Quests = { day = 0, progress = {}, claimed = {} },
		Stats = { kills = 0, mined = 0, bosses = 0 },
		History = {},
		Processed = {},
	}
end

-- Adds keys that appeared in newer versions of the profile without touching saved values
local function reconcile(target, template)
	for key, value in template do
		if target[key] == nil then
			target[key] = value
		elseif type(value) == "table" and type(target[key]) == "table" then
			reconcile(target[key], value)
		end
	end
	return target
end

local function keyFor(player)
	return "player_" .. player.UserId
end

local function setupLeaderstats(player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, name in { Config.StatNames.Level, Config.StatNames.Credits } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = folder
	end
	folder.Parent = player
end

local function syncPlayer(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local data = profile.data
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local credits = stats:FindFirstChild(Config.StatNames.Credits)
		local level = stats:FindFirstChild(Config.StatNames.Level)
		if credits then
			credits.Value = data.Credits
		end
		if level then
			level.Value = DataService.levelOf(data)
		end
	end
	player:SetAttribute("XP", data.XP % Config.XPPerLevel)
end

function DataService.levelOf(data)
	return 1 + math.floor(data.XP / Config.XPPerLevel)
end

function DataService.get(player)
	local profile = profiles[player]
	return profile and profile.data
end

-- Yields until the profile has loaded; returns false if the player left first
function DataService.waitFor(player)
	while not profiles[player] and player.Parent do
		task.wait(0.2)
	end
	return profiles[player] ~= nil
end

function DataService.refreshTitle(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local best, bestRank = "", 0
	for name, info in Config.Titles do
		if data.Titles[name] and info.rank > bestRank then
			best, bestRank = name, info.rank
		end
	end
	player:SetAttribute("Title", best)
end

function DataService.load(player)
	local ok, saved = false, nil
	for attempt = 1, 3 do
		ok, saved = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			break
		end
		task.wait(attempt)
	end
	if not ok then
		warn("[DataService] Не удалось загрузить профиль " .. player.Name .. ", сохранение отключено")
	end
	if not player.Parent then
		return
	end

	profiles[player] = {
		data = reconcile(saved or defaultProfile(), defaultProfile()),
		canSave = ok,
	}
	setupLeaderstats(player)
	DataService.refreshTitle(player)
	syncPlayer(player)
end

function DataService.save(player)
	local profile = profiles[player]
	if not profile or not profile.canSave then
		return false
	end
	local ok, err = pcall(function()
		store:SetAsync(keyFor(player), profile.data)
	end)
	if not ok then
		warn("[DataService] Ошибка сохранения " .. player.Name .. ": " .. tostring(err))
	end
	return ok
end

function DataService.release(player)
	DataService.save(player)
	profiles[player] = nil
end

function DataService.saveAll()
	for player in pairs(profiles) do
		DataService.save(player)
	end
end

function DataService.startAutosave()
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveSeconds)
			for player in pairs(profiles) do
				task.spawn(DataService.save, player)
			end
		end
	end)
end

-- Adds or removes credits exactly as given (used for purchases and upgrades)
function DataService.addCredits(player, amount)
	local data = DataService.get(player)
	if not data then
		return 0
	end
	data.Credits = math.max(0, data.Credits + amount)
	syncPlayer(player)
	return amount
end

-- Earned credits: VIP pilots get the multiplier
function DataService.reward(player, amount)
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local final = if data.Passes.vip then amount * Config.VIPMultiplier else amount
	DataService.addCredits(player, final)
	return final
end

function DataService.addXP(player, amount)
	local data = DataService.get(player)
	if not data then
		return
	end
	local oldLevel = DataService.levelOf(data)
	data.XP += amount
	syncPlayer(player)
	local newLevel = DataService.levelOf(data)
	if newLevel > oldLevel then
		Remotes.notify(player, "Новый уровень: " .. newLevel, "gold")
	end
end

function DataService.unlockTitle(player, name)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.Titles[name] = true
	DataService.refreshTitle(player)
end

function DataService.recordPurchase(player, kind, name, robux)
	local data = DataService.get(player)
	if not data then
		return
	end
	table.insert(data.History, 1, { t = os.time(), kind = kind, name = name, robux = robux })
	while #data.History > Config.HistoryLimit do
		table.remove(data.History)
	end
	data.Donated += robux
end

return DataService
