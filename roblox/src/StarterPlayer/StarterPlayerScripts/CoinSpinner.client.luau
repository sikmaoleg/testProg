-- Purely visual: makes course coins spin and bob on each player's screen
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local SPIN_SPEED = 3
local BOB_SPEED = 2
local BOB_HEIGHT = 0.4

local restingCFrames = {}

local function trackCoin(coin)
	restingCFrames[coin] = coin.CFrame
end

for _, coin in CollectionService:GetTagged("Coin") do
	trackCoin(coin)
end
CollectionService:GetInstanceAddedSignal("Coin"):Connect(trackCoin)
CollectionService:GetInstanceRemovedSignal("Coin"):Connect(function(coin)
	restingCFrames[coin] = nil
end)

RunService.RenderStepped:Connect(function()
	local time = os.clock()
	local bob = math.sin(time * BOB_SPEED) * BOB_HEIGHT
	for coin, restingCFrame in restingCFrames do
		coin.CFrame = restingCFrame * CFrame.Angles(0, time * SPIN_SPEED, 0) + Vector3.new(0, bob, 0)
	end
end)
