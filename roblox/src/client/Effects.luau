-- Client-only visuals: a starfield around the stations and a color mood that changes per zone
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Effects = {}

local STAR_COUNT = 350
local DEFAULT_ACCENT = Color3.fromRGB(120, 160, 255)
local grading

function Effects.init()
	grading = Instance.new("ColorCorrectionEffect")
	grading.Name = "ZoneGrading"
	grading.Parent = Lighting

	local folder = Instance.new("Folder")
	folder.Name = "Starfield"
	folder.Parent = Workspace
	for _ = 1, STAR_COUNT do
		local size = 0.4 + math.random() * 1.2
		local star = Instance.new("Part")
		star.Shape = Enum.PartType.Ball
		star.Size = Vector3.new(size, size, size)
		star.Anchored = true
		star.CanCollide = false
		star.CanQuery = false
		star.CanTouch = false
		star.CastShadow = false
		star.Material = Enum.Material.Neon
		star.Color = Color3.fromHSV(0.55 + math.random() * 0.15, 0.2 + math.random() * 0.4, 1)
		star.Position = Vector3.new(math.random(-1000, 4600), math.random(-500, 900), math.random(-1400, 1400))
		star.Parent = folder
	end
end

function Effects.setZone(zoneId)
	local zone = if zoneId == Config.Hub.id then Config.Hub else Config.ZoneById[zoneId]
	local accent = if zone then zone.accent else DEFAULT_ACCENT
	local tweenInfo = TweenInfo.new(1.2, Enum.EasingStyle.Quad)
	TweenService:Create(grading, tweenInfo, { TintColor = accent:Lerp(Color3.new(1, 1, 1), 0.82) }):Play()
	TweenService:Create(Lighting, tweenInfo, { Ambient = accent:Lerp(Color3.new(0, 0, 0), 0.55) }):Play()
end

return Effects
