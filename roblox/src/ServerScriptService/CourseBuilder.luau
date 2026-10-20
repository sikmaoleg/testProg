-- Builds the whole obby course from code, so the map lives in the repo as text
local CollectionService = game:GetService("CollectionService")

local CourseBuilder = {}

CourseBuilder.START_POSITION = Vector3.new(0, 3, 0)

local STAGE_COUNT = 30
local CHECKPOINT_EVERY = 5
local JUMP_PAD_EVERY = 7
local STAGE_ANGLE_STEP = 0.6
local STAGE_HEIGHT_STEP = 4
local COIN_OFFSET = Vector3.new(0, 4, 0)
local PAD_OFFSET = Vector3.new(0, 1.25, 0)

local function makePart(props)
	local part = Instance.new(props.className or "Part")
	part.Anchored = true
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(163, 162, 165)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.shape then
		part.Shape = props.shape
	end
	part.Parent = props.parent
	return part
end

local function buildSpawn(folder)
	local spawn = makePart({
		className = "SpawnLocation",
		size = Vector3.new(24, 2, 24),
		cframe = CFrame.new(0, 0, 0),
		color = Color3.fromRGB(70, 130, 180),
		parent = folder,
	})
	spawn.Name = "Spawn"
	spawn.Neutral = true
	spawn.Duration = 0
end

local function buildStages(folder)
	for index = 1, STAGE_COUNT do
		local angle = index * STAGE_ANGLE_STEP
		local radius = 24 + (index % 4) * 2
		local position = Vector3.new(
			math.cos(angle) * radius,
			1 + index * STAGE_HEIGHT_STEP,
			math.sin(angle) * radius
		)

		local isFinish = index == STAGE_COUNT
		local isCheckpoint = index % CHECKPOINT_EVERY == 0

		local stage = makePart({
			size = Vector3.new(10, 2, 10),
			cframe = CFrame.new(position),
			color = isFinish and Color3.fromRGB(255, 200, 0)
				or isCheckpoint and Color3.fromRGB(90, 220, 120)
				or Color3.fromHSV(index / STAGE_COUNT, 0.5, 0.95),
			parent = folder,
		})
		stage.Name = "Stage" .. index
		stage:SetAttribute("Stage", index)
		stage:SetAttribute("Checkpoint", isCheckpoint or isFinish)
		stage:SetAttribute("Finish", isFinish)
		CollectionService:AddTag(stage, "Stage")

		local coin = makePart({
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.3, 2, 2),
			cframe = CFrame.new(position + COIN_OFFSET),
			color = Color3.fromRGB(255, 205, 40),
			material = Enum.Material.Metal,
			parent = folder,
		})
		coin.Name = "Coin"
		coin.CanCollide = false
		CollectionService:AddTag(coin, "Coin")

		if index % JUMP_PAD_EVERY == 3 then
			local pad = makePart({
				size = Vector3.new(4, 0.5, 4),
				cframe = CFrame.new(position + PAD_OFFSET),
				color = Color3.fromRGB(255, 240, 80),
				material = Enum.Material.Neon,
				parent = folder,
			})
			pad.Name = "JumpPad"
			CollectionService:AddTag(pad, "JumpPad")
		end
	end
end

local function buildLava(folder)
	local lava = makePart({
		size = Vector3.new(800, 2, 800),
		cframe = CFrame.new(0, -8, 0),
		color = Color3.fromRGB(255, 90, 20),
		material = Enum.Material.Neon,
		parent = folder,
	})
	lava.Name = "Lava"
	lava.CanCollide = false
	CollectionService:AddTag(lava, "Lava")
end

function CourseBuilder.build(parent)
	local folder = Instance.new("Folder")
	folder.Name = "Course"
	folder.Parent = parent

	buildSpawn(folder)
	buildStages(folder)
	buildLava(folder)

	return folder
end

return CourseBuilder
