-- Client entry point: starts the interface and effects, and turns mouse clicks into laser shots
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Effects = require(script.Parent.Effects)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local lastShot = 0

UI.init()
Effects.init()

local function onZoneChanged()
	Effects.setZone(player:GetAttribute("Zone"))
end
player:GetAttributeChangedSignal("Zone"):Connect(onZoneChanged)
onZoneChanged()

Remotes.get("Notify").OnClientEvent:Connect(function(message, kind)
	UI.toast(message, kind)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.M then
		UI.toggle()
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	local character = player.Character
	if not character or not character:FindFirstChild("Laser") then
		return
	end
	local now = os.clock()
	if now - lastShot < Config.Combat.fireCooldown then
		return
	end
	lastShot = now
	Remotes.get("Fire"):FireServer(mouse.Hit.Position)
end)
