-- Creates the RemoteEvents and RemoteFunctions on the server and waits for them on the client
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "Remotes"
local DEFINITIONS = {
	Fire = "RemoteEvent",
	Notify = "RemoteEvent",
	Action = "RemoteFunction",
	GetProfile = "RemoteFunction",
}

local folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for name, className in DEFINITIONS do
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

function Remotes.get(name)
	return folder:WaitForChild(name)
end

function Remotes.notify(player, message, kind)
	folder.Notify:FireClient(player, message, kind or "info")
end

return Remotes
