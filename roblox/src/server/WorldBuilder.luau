-- Builds the space station hub and every planet zone, plus the portals that link them
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local WorldBuilder = {}

local ZONE_RADIUS = 125

WorldBuilder.zones = {} -- zone id -> folder with the zone's geometry
WorldBuilder.hubFolder = nil

local function part(props)
	local instance = Instance.new(props.className or "Part")
	instance.Name = props.name or "Part"
	instance.Anchored = true
	instance.Size = props.size
	instance.CFrame = props.cframe
	instance.Color = props.color or Color3.fromRGB(70, 75, 95)
	instance.Material = props.material or Enum.Material.Metal
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	instance.CanCollide = props.collide ~= false
	instance.Transparency = props.transparency or 0
	if props.shape then
		instance.Shape = props.shape
	end
	instance.Parent = props.parent
	return instance
end

local function addLabel(parent, message, color, position)
	local anchor = part({
		parent = parent,
		name = "Label",
		size = Vector3.new(1, 1, 1),
		cframe = CFrame.new(position),
		transparency = 1,
		collide = false,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 34)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 400
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Text = message
	label.Parent = gui
end

local function addPrompt(parent, actionText, objectText, onTriggered)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(onTriggered)
	prompt.Parent = parent
	return prompt
end

local function travel(player, zoneId)
	local ok, message = WorldBuilder.teleport(player, zoneId)
	Remotes.notify(player, message, ok and "info" or "bad")
end

local function buildHub(folder)
	local center = Config.Hub.center

	part({
		parent = folder,
		name = "Deck",
		className = "Part",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(4, 260, 260),
		cframe = CFrame.new(center + Vector3.new(0, -2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(60, 66, 90),
	})
	part({
		parent = folder,
		name = "Ring",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1, 220, 220),
		cframe = CFrame.new(center + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = Config.Hub.accent,
		material = Enum.Material.Neon,
		collide = false,
	})
	part({
		parent = folder,
		name = "Tower",
		size = Vector3.new(16, 60, 16),
		cframe = CFrame.new(center + Vector3.new(0, 30, 0)),
		color = Color3.fromRGB(90, 100, 130),
		material = Enum.Material.SmoothPlastic,
	})
	part({
		parent = folder,
		name = "Spawn",
		className = "SpawnLocation",
		size = Vector3.new(8, 1, 8),
		cframe = CFrame.new(Config.Hub.spawn + Vector3.new(0, -3.5, 0)),
		color = Color3.fromRGB(70, 130, 180),
	}).Neutral = true
end

local function buildGates(folder)
	local count = #Config.Zones
	for index, zone in Config.Zones do
		local angle = (index - 1) / count * math.pi * 2 - math.pi / 2
		local position = Config.Hub.center + Vector3.new(math.cos(angle) * 95, 0.5, math.sin(angle) * 95)
		local gate = part({
			parent = folder,
			name = "Gate_" .. zone.id,
			size = Vector3.new(12, 1, 12),
			cframe = CFrame.new(position),
			color = zone.accent,
			material = Enum.Material.Neon,
		})
		addLabel(folder, zone.name .. " · ур. " .. zone.requiredLevel, zone.accent, position + Vector3.new(0, 5, 0))
		addPrompt(gate, "Лететь", zone.name, function(player)
			travel(player, zone.id)
		end)
	end
end

local function buildPlanet(folder, zone)
	local size = zone.planetSize
	local position = zone.center + Vector3.new(0, 380, -520)
	part({
		parent = folder,
		name = "Planet",
		shape = Enum.PartType.Ball,
		size = Vector3.new(size, size, size),
		cframe = CFrame.new(position),
		color = zone.planetColor,
		material = Enum.Material.SmoothPlastic,
		collide = false,
	})
	if zone.rings then
		part({
			parent = folder,
			name = "Rings",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(3, size * 1.9, size * 1.9),
			cframe = CFrame.new(position) * CFrame.Angles(math.rad(12), 0, math.rad(90)),
			color = Color3.fromRGB(230, 215, 180),
			transparency = 0.35,
			collide = false,
		})
	end
end

local function buildAsteroids(folder, zone, rng)
	for _ = 1, 45 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(30, 140)
		local size = rng:NextNumber(3, 9)
		local height = rng:NextNumber(4, 60)
		part({
			parent = folder,
			name = "Asteroid",
			shape = Enum.PartType.Ball,
			size = Vector3.new(size, size, size),
			cframe = CFrame.new(zone.center + Vector3.new(math.cos(angle) * distance, height, math.sin(angle) * distance))
				* CFrame.Angles(rng:NextNumber(), rng:NextNumber(), rng:NextNumber()),
			color = Color3.fromRGB(110, 100, 90),
			material = Enum.Material.Rock,
			collide = false,
		})
	end
end

local function buildPillars(folder, zone, rng)
	for _ = 1, 8 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(60, 105)
		local height = rng:NextNumber(10, 22)
		local base = zone.center + Vector3.new(math.cos(angle) * distance, height / 2, math.sin(angle) * distance)
		part({
			parent = folder,
			name = "Pillar",
			size = Vector3.new(4, height, 4),
			cframe = CFrame.new(base),
			color = zone.groundColor:Lerp(Color3.new(1, 1, 1), 0.2),
			material = Enum.Material.Metal,
		})
		part({
			parent = folder,
			name = "Beacon",
			size = Vector3.new(4.5, 1, 4.5),
			cframe = CFrame.new(base + Vector3.new(0, height / 2 + 0.5, 0)),
			color = zone.accent,
			material = Enum.Material.Neon,
			collide = false,
		})
	end
end

local function buildZone(zonesFolder, zone)
	local folder = Instance.new("Folder")
	folder.Name = zone.name
	folder.Parent = zonesFolder

	local center = zone.center
	local rng = Random.new(math.floor(center.X))

	part({
		parent = folder,
		name = "Ground",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(4, 240, 240),
		cframe = CFrame.new(center + Vector3.new(0, -2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = zone.groundColor,
		material = zone.ground,
	})

	if zone.planetSize then
		buildPlanet(folder, zone)
	end
	if zone.asteroids then
		buildAsteroids(folder, zone, rng)
	end
	buildPillars(folder, zone, rng)

	local returnPad = part({
		parent = folder,
		name = "ReturnPad",
		size = Vector3.new(10, 1, 10),
		cframe = CFrame.new(center + Vector3.new(-60, 0.5, 0)),
		color = Color3.fromRGB(255, 255, 255),
		material = Enum.Material.Neon,
	})
	addPrompt(returnPad, "Вернуться на станцию", "Портал на станцию", function(player)
		travel(player, Config.Hub.id)
	end)

	addLabel(folder, zone.name .. " · ур. " .. zone.requiredLevel, zone.accent, center + Vector3.new(0, 16, 0))
	return folder
end

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Returns the hub id, a zone id, or nil when the position is in open space
function WorldBuilder.zoneAt(position)
	local hub = Config.Hub
	if flatDistance(position, hub.center) <= hub.radius and math.abs(position.Y) < 60 then
		return hub.id
	end
	for _, zone in Config.Zones do
		if flatDistance(position, zone.center) <= ZONE_RADIUS and math.abs(position.Y - zone.center.Y) < 60 then
			return zone.id
		end
	end
	return nil
end

function WorldBuilder.teleport(player, zoneId)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local data = DataService.get(player)
	if not root or not data then
		return false, "Корабль ещё не готов"
	end

	local target = zoneId == Config.Hub.id and Config.Hub or Config.ZoneById[zoneId]
	if not target then
		return false, "Такого сектора нет"
	end
	local requiredLevel = target.requiredLevel or 1
	if DataService.levelOf(data) < requiredLevel then
		return false, "Сектор откроется на уровне " .. requiredLevel
	end

	character:PivotTo(CFrame.new(target.spawn))
	return true, "Прибытие: " .. target.name
end

function WorldBuilder.build()
	local hubFolder = Instance.new("Folder")
	hubFolder.Name = "Hub"
	hubFolder.Parent = Workspace
	buildHub(hubFolder)
	buildGates(hubFolder)
	WorldBuilder.hubFolder = hubFolder

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = Workspace
	for _, zone in Config.Zones do
		WorldBuilder.zones[zone.id] = buildZone(zonesFolder, zone)
	end
end

return WorldBuilder
