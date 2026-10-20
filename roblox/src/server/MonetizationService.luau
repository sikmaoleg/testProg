-- Everything that touches Robux: gamepasses, developer products, receipts and the purchase history
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local MonetizationService = {}

local PROCESSED_LIMIT = 200
local passByAssetId = {}
local productByAssetId = {}

local function ownsPass(userId, passId)
	local ok, owned = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(userId, passId)
	end)
	return ok and owned
end

function MonetizationService.applyCharacter(player, humanoid)
	local data = DataService.get(player)
	if not data then
		return
	end
	local speed = Config.DefaultWalkSpeed
	if data.Passes.speed then
		speed *= Config.SpeedMultiplier
	end
	humanoid.WalkSpeed = speed
end

local function grantPass(player, key, announce)
	local data = DataService.get(player)
	local pass = Config.GamePasses[key]
	if not data or not pass or data.Passes[key] then
		return
	end
	data.Passes[key] = true
	if key == "vip" then
		DataService.unlockTitle(player, "VIP")
	end
	if announce then
		DataService.recordPurchase(player, "Пропуск", pass.name, pass.robux)
		Remotes.notify(player, "Пропуск активирован: " .. pass.name, "gold")
		DataService.save(player)
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		MonetizationService.applyCharacter(player, humanoid)
	end
end

-- Gamepasses bought on another server are only visible through ownership checks
function MonetizationService.checkOwnedPasses(player)
	for key, pass in Config.GamePasses do
		if pass.id > 0 and ownsPass(player.UserId, pass.id) then
			grantPass(player, key, false)
		end
	end
end

local function grantProduct(player, product)
	if product.heal then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			-- Throwing makes ProcessReceipt retry later instead of charging for nothing
			error("Персонаж ещё не загружен")
		end
		humanoid.Health = humanoid.MaxHealth
	end
	if product.credits then
		DataService.addCredits(player, product.credits)
	end
	if product.title then
		DataService.unlockTitle(player, product.title)
	end
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and DataService.get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(data.Processed, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local key = productByAssetId[receipt.ProductId]
	local product = key and Config.DevProducts[key]
	if not product then
		warn("[Monetization] Неизвестный товар: " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not pcall(grantProduct, player, product) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(data.Processed, receipt.PurchaseId)
	while #data.Processed > PROCESSED_LIMIT do
		table.remove(data.Processed, 1)
	end
	DataService.recordPurchase(player, product.kind, product.name, product.robux)
	DataService.save(player)
	Remotes.notify(player, "Спасибо за покупку: " .. product.name, "gold")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.promptPass(player, key)
	local pass = Config.GamePasses[key]
	if not pass then
		return false, "Такого пропуска нет"
	end
	if pass.id <= 0 then
		return false, "Пропуск ещё не добавлен в игру"
	end
	local data = DataService.get(player)
	if data and data.Passes[key] then
		return false, "Пропуск уже активен"
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.id)
	return true, "Открыто окно покупки"
end

function MonetizationService.promptProduct(player, key)
	local product = Config.DevProducts[key]
	if not product then
		return false, "Такого товара нет"
	end
	if product.id <= 0 then
		return false, "Товар ещё не добавлен в игру"
	end
	MarketplaceService:PromptProductPurchase(player, product.id)
	return true, "Открыто окно покупки"
end

function MonetizationService.init()
	for key, pass in Config.GamePasses do
		if pass.id > 0 then
			passByAssetId[pass.id] = key
		end
	end
	for key, product in Config.DevProducts do
		if product.id > 0 then
			productByAssetId[product.id] = key
		end
	end

	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		local key = passByAssetId[passId]
		if wasPurchased and key then
			grantPass(player, key, true)
		end
	end)
end

return MonetizationService
