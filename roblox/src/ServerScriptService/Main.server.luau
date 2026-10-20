-- Server-side game logic: stats, coins, checkpoints, lava, jump pads and the finish
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CourseBuilder = require(script.Parent.CourseBuilder)

local COIN_REWARD = 1
local FINISH_REWARD = 50
local COIN_RESPAWN_SECONDS = 20
local JUMP_PAD_SPEED = 110
local JUMP_PAD_COOLDOWN = 1
local FINISH_COOLDOWN = 3

local progressByPlayer = {}
local lastLaunchByRoot = setmetatable({}, { __mode = "k" })

CourseBuilder.build(Workspace)

local function getPlayer(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	return character and Players:GetPlayerFromCharacter(character)
end

local function addStat(player, name, amount)
	player.leaderstats[name].Value += amount
end

local function onPlayerAdded(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, name in { "Coins", "Stage", "Wins" } do
		local stat = Instance.new("IntValue")
		stat.Name = name
		stat.Parent = leaderstats
	end
	leaderstats.Parent = player

	progressByPlayer[player] = {
		checkpointStage = 0,
		position = CourseBuilder.START_POSITION,
		lastFinish = -math.huge,
	}

	-- Put the player back on their last checkpoint after every respawn (including lava deaths)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart")
		task.wait()
		local progress = progressByPlayer[player]
		if progress then
			character:PivotTo(CFrame.new(progress.position))
		end
	end)
end

local function onCoinTouched(coin, hit)
	if not coin.CanTouch then
		return
	end
	local player = getPlayer(hit)
	if not player then
		return
	end

	coin.CanTouch = false
	coin.Transparency = 1
	addStat(player, "Coins", COIN_REWARD)

	task.delay(COIN_RESPAWN_SECONDS, function()
		coin.Transparency = 0
		coin.CanTouch = true
	end)
end

local function onStageTouched(stage, hit)
	local player = getPlayer(hit)
	local progress = player and progressByPlayer[player]
	if not progress then
		return
	end

	local index = stage:GetAttribute("Stage")
	local stageStat = player.leaderstats.Stage
	if index > stageStat.Value then
		stageStat.Value = index
	end

	if stage:GetAttribute("Finish") then
		if os.clock() - progress.lastFinish < FINISH_COOLDOWN then
			return
		end
		progress.lastFinish = os.clock()
		progress.checkpointStage = 0
		progress.position = CourseBuilder.START_POSITION

		player.leaderstats.Wins.Value += 1
		addStat(player, "Coins", FINISH_REWARD)

		local character = player.Character
		if character then
			character:PivotTo(CFrame.new(CourseBuilder.START_POSITION))
		end
		return
	end

	if stage:GetAttribute("Checkpoint") and index > progress.checkpointStage then
		progress.checkpointStage = index
		progress.position = stage.Position + Vector3.new(0, 3, 0)
	end
end

local function onLavaTouched(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end

local function onJumpPadTouched(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local now = os.clock()
	if now - (lastLaunchByRoot[root] or -math.huge) < JUMP_PAD_COOLDOWN then
		return
	end
	lastLaunchByRoot[root] = now

	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, JUMP_PAD_SPEED, velocity.Z)
end

-- Runs the handler for every instance already tagged and for every one tagged later
local function bindTag(tag, handler)
	for _, instance in CollectionService:GetTagged(tag) do
		handler(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(handler)
end

bindTag("Coin", function(coin)
	coin.Touched:Connect(function(hit)
		onCoinTouched(coin, hit)
	end)
end)

bindTag("Stage", function(stage)
	stage.Touched:Connect(function(hit)
		onStageTouched(stage, hit)
	end)
end)

bindTag("Lava", function(lava)
	lava.Touched:Connect(onLavaTouched)
end)

bindTag("JumpPad", function(pad)
	pad.Touched:Connect(onJumpPadTouched)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	progressByPlayer[player] = nil
end)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
