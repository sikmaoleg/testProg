-- Laser weapon, drone and boss AI, and the rewards for destroying them
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local QuestService = require(script.Parent.QuestService)

local CombatService = {}

local LASER_NAME = "Laser"
local AI_TICK = 0.5
local HOME_RADIUS = 15
local GOLD = Color3.fromRGB(255, 200, 70)
local CYAN = Color3.fromRGB(80, 220, 255)

local enemies = {} -- active enemy records
local enemyFolder
local lastShot = setmetatable({}, { __mode = "k" })
local spawnEnemy -- defined below, used by respawn timers

local laserTemplate = Instance.new("Tool")
laserTemplate.Name = LASER_NAME
laserTemplate.CanBeDropped = false
local laserHandle = Instance.new("Part")
laserHandle.Name = "Handle"
laserHandle.Size = Vector3.new(0.6, 0.6, 2.5)
laserHandle.Material = Enum.Material.Neon
laserHandle.CanCollide = false
laserHandle.Parent = laserTemplate

local function laserColor(player)
	local data = DataService.get(player)
	if data and (data.Passes.vip or data.Titles.Legend) then
		return GOLD
	end
	return CYAN
end

function CombatService.equipLaser(player, humanoid)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local tool = laserTemplate:Clone()
	tool.Handle.Color = laserColor(player)
	tool.Parent = backpack
	humanoid:EquipTool(tool)
end

local function drawBeam(from, to, color)
	local distance = (to - from).Magnitude
	if distance < 0.1 then
		return
	end
	local beam = Instance.new("Part")
	beam.Name = "LaserBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Size = Vector3.new(0.2, 0.2, distance)
	beam.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -distance / 2)
	beam.Parent = Workspace
	Debris:AddItem(beam, 0.15)
end

local function onFire(player, targetPosition)
	if typeof(targetPosition) ~= "Vector3" then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local laser = character and character:FindFirstChild(LASER_NAME)
	if not root or not laser then
		return
	end

	local now = os.clock()
	if now - (lastShot[player] or -math.huge) < Config.Combat.fireCooldown then
		return
	end
	lastShot[player] = now

	local origin = root.Position + Vector3.new(0, 1, 0)
	local offset = targetPosition - origin
	if offset.Magnitude < 1 then
		return
	end
	local direction = offset.Unit * Config.Combat.laserRange

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = Workspace:Raycast(origin, direction, params)
	local endPosition = result and result.Position or origin + direction
	drawBeam(origin, endPosition, laser.Handle.Color)

	if not result then
		return
	end
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	local humanoid = model and model:GetAttribute("Enemy") and model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		local data = DataService.get(player)
		local damageLevel = data and data.Upgrades.damage or 0
		model:SetAttribute("LastHit", player.UserId)
		humanoid:TakeDamage(Config.Combat.baseDamage + damageLevel * Config.Combat.damagePerLevel)
	end
end

local function randomPointAround(center, minRadius, maxRadius)
	local angle = math.random() * math.pi * 2
	local distance = minRadius + math.random() * (maxRadius - minRadius)
	return center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

local function onEnemyDied(record)
	local index = table.find(enemies, record)
	if index then
		table.remove(enemies, index)
	end

	local definition = record.definition
	local killerId = record.model:GetAttribute("LastHit")
	local killer = killerId and Players:GetPlayerByUserId(killerId)
	if killer then
		local data = DataService.get(killer)
		if data then
			data.Stats.kills += 1
			if record.isBoss then
				data.Stats.bosses += 1
			end
		end
		local credits = DataService.reward(killer, definition.credits)
		DataService.addXP(killer, definition.xp)
		QuestService.add(killer, if record.isBoss then "boss" else "kill", 1)
		Remotes.notify(killer, definition.name .. " уничтожен: +" .. credits .. " кредитов", "good")
	end

	Debris:AddItem(record.model, 4)
	local respawn = if record.isBoss then Config.Combat.bossRespawnSeconds else Config.Combat.enemyRespawnSeconds
	task.delay(respawn, function()
		spawnEnemy(record.zone, definition, record.home, record.isBoss)
	end)
end

function spawnEnemy(zone, definition, home, isBoss)
	local scale = definition.scale or 1
	local size = 3 * scale

	local model = Instance.new("Model")
	model.Name = definition.name

	local body = Instance.new("Part")
	body.Name = "HumanoidRootPart"
	body.Size = Vector3.new(size, size, size)
	body.CFrame = CFrame.new(home + Vector3.new(0, size / 2, 0))
	body.Color = definition.color or zone.accent
	body.Material = Enum.Material.Neon
	body.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = definition.health
	humanoid.Health = definition.health
	humanoid.WalkSpeed = definition.speed
	humanoid.HipHeight = 0
	humanoid.Parent = model

	model.PrimaryPart = body
	model:SetAttribute("Enemy", true)
	model:SetAttribute("Zone", zone.id)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 30)
	gui.StudsOffset = Vector3.new(0, size / 2 + 1.5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = body

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui

	local function showHealth(health)
		label.Text = definition.name .. "  " .. math.ceil(health) .. " / " .. definition.health
	end
	showHealth(definition.health)
	humanoid.HealthChanged:Connect(showHealth)

	local record = {
		model = model,
		humanoid = humanoid,
		zone = zone,
		definition = definition,
		home = home,
		isBoss = isBoss,
		damage = definition.damage,
		lastAttack = 0,
	}
	table.insert(enemies, record)
	humanoid.Died:Connect(function()
		onEnemyDied(record)
	end)

	model.Parent = enemyFolder
end

local function nearestPlayer(zoneId, position, range)
	local nearest, nearestDistance = nil, range
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Zone") == zoneId then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = humanoid and humanoid.RootPart
			if humanoid and root and humanoid.Health > 0 then
				local distance = (root.Position - position).Magnitude
				if distance < nearestDistance then
					nearest, nearestDistance = humanoid, distance
				end
			end
		end
	end
	return nearest, nearestDistance
end

local function thinkEnemy(record, now)
	local humanoid = record.humanoid
	local root = humanoid.RootPart
	if humanoid.Health <= 0 or not root then
		return
	end

	local target, distance = nearestPlayer(record.zone.id, root.Position, Config.Combat.aggroRange)
	if target and distance <= Config.Combat.attackRange then
		humanoid:MoveTo(root.Position)
		if now - record.lastAttack >= Config.Combat.attackCooldown then
			record.lastAttack = now
			target:TakeDamage(record.damage)
		end
	elseif target then
		humanoid:MoveTo(target.RootPart.Position)
	elseif (root.Position - record.home).Magnitude > HOME_RADIUS then
		humanoid:MoveTo(record.home)
	end
end

function CombatService.init()
	enemyFolder = Instance.new("Folder")
	enemyFolder.Name = "Enemies"
	enemyFolder.Parent = Workspace

	for _, zone in Config.Zones do
		for _ = 1, Config.Combat.enemiesPerZone do
			spawnEnemy(zone, zone.enemy, randomPointAround(zone.center, 30, 100), false)
		end
		if zone.boss then
			spawnEnemy(zone, zone.boss, zone.center + Vector3.new(0, 0, -60), true)
		end
	end

	Remotes.get("Fire").OnServerEvent:Connect(onFire)

	task.spawn(function()
		while true do
			task.wait(AI_TICK)
			local now = os.clock()
			for _, record in table.clone(enemies) do
				thinkEnemy(record, now)
			end
		end
	end)
end

return CombatService
