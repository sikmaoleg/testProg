-- Daily quests that reset every 24 hours, and the daily login reward
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local QuestService = {}

local questById = {}
for _, quest in Config.Quests do
	questById[quest.id] = quest
end

function QuestService.refresh(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	if os.time() - data.Quests.day >= Config.QuestResetSeconds then
		data.Quests.day = os.time()
		data.Quests.progress = {}
		data.Quests.claimed = {}
	end
end

function QuestService.add(player, questId, amount)
	local data = DataService.get(player)
	local quest = questById[questId]
	if not data or not quest then
		return
	end
	QuestService.refresh(player)
	if data.Quests.claimed[questId] then
		return
	end

	local progress = (data.Quests.progress[questId] or 0) + amount
	data.Quests.progress[questId] = math.min(progress, quest.target)
	if progress >= quest.target then
		data.Quests.claimed[questId] = true
		local reward = DataService.reward(player, quest.reward)
		DataService.addXP(player, quest.xp)
		Remotes.notify(player, "Задание выполнено: " .. quest.name .. " (+" .. reward .. " кредитов)", "gold")
	end
end

function QuestService.claimDaily(player)
	local data = DataService.get(player)
	if not data then
		return false, "Профиль ещё загружается"
	end
	if os.time() - data.LastDaily < Config.DailyCooldown then
		return false, "Награда уже получена, возвращайтесь позже"
	end
	data.LastDaily = os.time()
	local reward = DataService.reward(player, Config.DailyReward)
	DataService.addXP(player, 30)
	return true, "Ежедневная награда: +" .. reward .. " кредитов"
end

return QuestService
