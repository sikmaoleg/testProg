-- Builds the whole interface in code: HUD, toast messages and the command-center panel with tabs
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local UI = {}

local PANEL_WIDTH = 760
local PANEL_HEIGHT = 500
local TABS = {
	{ id = "upgrades", label = "Верфь" },
	{ id = "quests", label = "Задания" },
	{ id = "map", label = "Карта" },
	{ id = "donate", label = "Донат" },
	{ id = "history", label = "История" },
}
local PRODUCT_SECTIONS = {
	{ group = "credits", title = "Пакеты кредитов" },
	{ group = "support", title = "Поддержать автора" },
	{ group = "service", title = "Услуги" },
}
local COLORS = {
	panel = Color3.fromRGB(10, 14, 32),
	card = Color3.fromRGB(22, 30, 62),
	accent = Color3.fromRGB(80, 220, 255),
	gold = Color3.fromRGB(255, 200, 70),
	good = Color3.fromRGB(90, 230, 140),
	bad = Color3.fromRGB(255, 95, 110),
	text = Color3.fromRGB(235, 240, 255),
	muted = Color3.fromRGB(150, 160, 200),
	dark = Color3.fromRGB(8, 12, 26),
}
local KIND_COLORS = { info = COLORS.accent, good = COLORS.good, bad = COLORS.bad, gold = COLORS.gold }

local screen
local hud = {}
local panel
local tabContent
local tabButtons = {}
local currentTab = "upgrades"
local cachedProfile
local renderers = {}
local toastHolder
local toastOrder = 0

local function create(className, props, parent)
	local instance = Instance.new(className)
	for key, prop in props or {} do
		instance[key] = prop
	end
	instance.Parent = parent
	return instance
end

local function corner(parent, radius)
	create("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

local function stroke(parent, color)
	create("UIStroke", { Color = color or COLORS.accent, Thickness = 1.5, Transparency = 0.35 }, parent)
end

local function text(parent, value, props)
	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextColor3 = COLORS.text,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 22),
		Text = value,
	}, parent)
	for key, prop in props or {} do
		label[key] = prop
	end
	return label
end

local function button(parent, value, color, onClick)
	local instance = create("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = color or COLORS.accent,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextColor3 = COLORS.dark,
		TextSize = 14,
		Text = value,
	}, parent)
	corner(instance, 8)
	instance.Activated:Connect(onClick)
	return instance
end

local function row(parent, order, height)
	local frame = create("Frame", {
		BackgroundColor3 = COLORS.card,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = UDim2.new(1, -4, 0, height or 64),
	}, parent)
	corner(frame, 10)
	return frame
end

local function entry(parent, order, title, description, buttonText, onClick, color)
	local frame = row(parent, order, 64)
	text(frame, title, {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -190, 0, 22),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
	})
	text(frame, description, {
		Position = UDim2.fromOffset(14, 30),
		Size = UDim2.new(1, -190, 0, 28),
		TextSize = 13,
		TextColor3 = COLORS.muted,
	})
	if buttonText then
		local action = button(frame, buttonText, color, onClick or function() end)
		action.Position = UDim2.new(1, -168, 0.5, -18)
		action.Size = UDim2.fromOffset(156, 36)
	end
	return frame
end

local function sectionTitle(parent, title, order)
	text(parent, title, {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 26),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = COLORS.gold,
	})
end

local function bar(parent, y, color)
	local back = create("Frame", {
		BackgroundColor3 = COLORS.card,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, y),
		Size = UDim2.new(1, -24, 0, 8),
	}, parent)
	corner(back, 4)
	local fill = create("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, back)
	corner(fill, 4)
	return fill
end

local function zoneName(zoneId)
	if zoneId == nil then
		return "Открытый космос"
	end
	if zoneId == Config.Hub.id then
		return Config.Hub.name
	end
	local zone = Config.ZoneById[zoneId]
	return if zone then zone.name else "Открытый космос"
end

local function updateHud()
	local stats = player:FindFirstChild("leaderstats")
	local credits = stats and stats:FindFirstChild(Config.StatNames.Credits)
	local level = stats and stats:FindFirstChild(Config.StatNames.Level)
	hud.credits.Text = "Кредиты: " .. (if credits then credits.Value else 0)
	hud.level.Text = "Уровень " .. (if level then level.Value else 1)
	hud.xpFill.Size = UDim2.fromScale(math.clamp((player:GetAttribute("XP") or 0) / Config.XPPerLevel, 0, 1), 1)

	local cargo = player:GetAttribute("Cargo") or 0
	local cargoMax = player:GetAttribute("CargoMax") or Config.Mining.cargoBase
	hud.cargoFill.Size = UDim2.fromScale(math.clamp(cargo / cargoMax, 0, 1), 1)
	hud.cargoLabel.Text = "Трюм " .. cargo .. " / " .. cargoMax

	hud.zone.Text = zoneName(player:GetAttribute("Zone"))
	local title = player:GetAttribute("Title")
	hud.title.Text = if title and title ~= "" then "Титул: " .. title else "Титул: нет"
end

local function buildHud()
	local frame = create("Frame", {
		Name = "HUD",
		BackgroundColor3 = COLORS.panel,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(250, 146),
	}, screen)
	corner(frame, 12)
	stroke(frame)

	hud.credits = text(frame, "", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 22),
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = COLORS.gold,
	})
	hud.level = text(frame, "", {
		Position = UDim2.fromOffset(12, 32),
		Size = UDim2.new(1, -24, 0, 18),
		TextSize = 13,
		TextColor3 = COLORS.muted,
	})
	hud.xpFill = bar(frame, 54, COLORS.accent)
	hud.cargoLabel = text(frame, "", {
		Position = UDim2.fromOffset(12, 68),
		Size = UDim2.new(1, -24, 0, 18),
		TextSize = 13,
	})
	hud.cargoFill = bar(frame, 88, COLORS.gold)
	hud.zone = text(frame, "", {
		Position = UDim2.fromOffset(12, 102),
		Size = UDim2.new(1, -24, 0, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
	})
	hud.title = text(frame, "", {
		Position = UDim2.fromOffset(12, 124),
		Size = UDim2.new(1, -24, 0, 16),
		TextSize = 12,
		TextColor3 = COLORS.muted,
	})
end

local function buildToastHolder()
	toastHolder = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, -210, 0, 16),
		Size = UDim2.fromOffset(420, 400),
	}, screen)
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, toastHolder)
end

function UI.toast(message, kind)
	toastOrder += 1
	local color = KIND_COLORS[kind] or COLORS.accent
	local toast = create("Frame", {
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		LayoutOrder = toastOrder,
		Size = UDim2.new(1, 0, 0, 40),
	}, toastHolder)
	corner(toast, 8)
	stroke(toast, color)

	local label = text(toast, message or "", {
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0),
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 15,
	})

	task.delay(3.5, function()
		TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.4)
		toast:Destroy()
	end)
end

local function renderTab()
	for _, child in tabContent:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	if not cachedProfile then
		text(tabContent, "Загрузка профиля…", { Size = UDim2.new(1, 0, 0, 24), TextColor3 = COLORS.muted })
		return
	end
	renderers[currentTab](cachedProfile)
end

local function refresh()
	local ok, profile = pcall(function()
		return Remotes.get("GetProfile"):InvokeServer()
	end)
	if ok and profile then
		cachedProfile = profile
	end
	renderTab()
end

local function request(action, argument)
	local ok, success, message = pcall(function()
		return Remotes.get("Action"):InvokeServer(action, argument)
	end)
	if not ok then
		UI.toast("Нет связи с сервером", "bad")
		return
	end
	UI.toast(message, if success then "good" else "bad")
	refresh()
end

local function selectTab(id)
	currentTab = id
	for tabId, tabButton in tabButtons do
		local active = tabId == id
		tabButton.BackgroundColor3 = if active then COLORS.accent else COLORS.card
		tabButton.TextColor3 = if active then COLORS.dark else COLORS.text
	end
	renderTab()
end

renderers.upgrades = function(profile)
	text(tabContent, "Улучшайте корабль за кредиты: сильнее лазер, быстрее добыча и больше места в трюме.", {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 36),
		TextColor3 = COLORS.muted,
		TextSize = 13,
	})
	for index, key in Config.UpgradeOrder do
		local upgrade = Config.Upgrades[key]
		local level = profile.upgrades[key]
		local maxed = level >= upgrade.maxLevel
		entry(
			tabContent,
			index,
			upgrade.name .. "  ·  ур. " .. level .. "/" .. upgrade.maxLevel,
			upgrade.description,
			if maxed then "Максимум" else "Улучшить · " .. profile.upgradeCost[key],
			function()
				request("BuyUpgrade", key)
			end,
			COLORS.accent
		)
	end
end

renderers.quests = function(profile)
	entry(
		tabContent,
		0,
		"Ежедневная награда",
		"Получайте " .. profile.dailyReward .. " кредитов раз в 20 часов. У VIP-пилотов награда ×2.",
		if profile.dailyReady then "Забрать" else "Уже получено",
		function()
			request("ClaimDaily")
		end,
		COLORS.gold
	)
	for index, quest in profile.quests do
		entry(
			tabContent,
			index,
			quest.name .. "  ·  " .. quest.progress .. " / " .. quest.target,
			"Награда: +" .. quest.reward .. " кредитов и " .. quest.xp .. " опыта. Задания обновляются каждые сутки.",
			if quest.claimed then "Выполнено" else nil,
			nil,
			COLORS.good
		)
	end
end

renderers.map = function(profile)
	entry(
		tabContent,
		0,
		Config.Hub.name,
		Config.Hub.blurb,
		"На станцию",
		function()
			request("Teleport", Config.Hub.id)
		end,
		COLORS.accent
	)
	for index, zone in profile.zones do
		local config = Config.ZoneById[zone.id]
		local info = config.blurb .. " · руда: " .. config.ore.name .. " (" .. config.ore.value .. " кр.)"
		entry(
			tabContent,
			index,
			zone.name .. "  ·  от ур. " .. zone.requiredLevel,
			info,
			if zone.unlocked then "Лететь" else "Закрыто",
			function()
				request("Teleport", zone.id)
			end,
			if zone.unlocked then COLORS.accent else COLORS.muted
		)
	end
end

renderers.donate = function(profile)
	text(tabContent, "Покупки за Robux проходят через Roblox. Кредиты, титулы и пропуски выдаются сразу после оплаты.", {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 36),
		TextColor3 = COLORS.muted,
		TextSize = 13,
	})

	local order = 1
	for _, section in PRODUCT_SECTIONS do
		sectionTitle(tabContent, section.title, order)
		order += 1
		for _, key in Config.ProductOrder do
			local product = Config.DevProducts[key]
			if product.group == section.group then
				entry(
					tabContent,
					order,
					product.name .. "  ·  R$ " .. product.robux,
					product.description,
					"Купить",
					function()
						request("BuyProduct", key)
					end,
					COLORS.gold
				)
				order += 1
			end
		end
	end

	sectionTitle(tabContent, "Пропуски (навсегда)", order)
	order += 1
	for _, key in Config.PassOrder do
		local pass = Config.GamePasses[key]
		local owned = profile.passes[key] == true
		entry(
			tabContent,
			order,
			pass.name .. "  ·  R$ " .. pass.robux,
			pass.description,
			if owned then "Активен" else "Купить",
			function()
				request("BuyPass", key)
			end,
			if owned then COLORS.good else COLORS.accent
		)
		order += 1
	end
end

renderers.history = function(profile)
	text(tabContent, "Всего на поддержку проекта: R$ " .. profile.donated, {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 26),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = COLORS.gold,
	})

	local titles = {}
	for name in profile.titles do
		table.insert(titles, name)
	end
	text(tabContent, "Титулы: " .. (if #titles > 0 then table.concat(titles, ", ") else "пока нет"), {
		LayoutOrder = 1,
		TextColor3 = COLORS.muted,
		TextSize = 13,
	})

	if #profile.history == 0 then
		text(tabContent, "Покупок пока нет. Спасибо, что заглядываете!", {
			LayoutOrder = 2,
			TextColor3 = COLORS.muted,
		})
		return
	end

	for index, purchase in profile.history do
		local frame = row(tabContent, index + 2, 52)
		text(frame, purchase.name, {
			Position = UDim2.fromOffset(14, 6),
			Size = UDim2.new(1, -200, 0, 20),
			Font = Enum.Font.GothamBold,
		})
		text(frame, os.date("%d.%m.%Y %H:%M", purchase.t) .. "  ·  " .. purchase.kind, {
			Position = UDim2.fromOffset(14, 28),
			Size = UDim2.new(1, -200, 0, 18),
			TextSize = 12,
			TextColor3 = COLORS.muted,
		})
		text(frame, "R$ " .. purchase.robux, {
			Position = UDim2.new(1, -180, 0, 0),
			Size = UDim2.new(0, 164, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Enum.Font.GothamBold,
			TextSize = 17,
			TextColor3 = COLORS.gold,
		})
	end
end

local function buildBottomBar()
	local bottom = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(420, 44),
	}, screen)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bottom)

	local menu = button(bottom, "Командный центр  [M]", COLORS.accent, function()
		UI.toggle()
	end)
	menu.Size = UDim2.fromOffset(230, 44)

	local sell = button(bottom, "Продать руду", COLORS.gold, function()
		request("SellCargo")
	end)
	sell.Size = UDim2.fromOffset(170, 44)
end

local function buildPanel()
	panel = create("Frame", {
		Name = "Command",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT),
		Visible = false,
	}, screen)
	corner(panel, 14)
	stroke(panel)

	text(panel, "Командный центр", {
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.new(1, -80, 0, 30),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
	})
	local close = button(panel, "X", COLORS.bad, function()
		UI.toggle()
	end)
	close.Position = UDim2.new(1, -52, 0, 12)
	close.Size = UDim2.fromOffset(36, 36)

	local tabBar = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 56),
		Size = UDim2.new(1, -40, 0, 36),
	}, panel)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabBar)
	for index, tab in TABS do
		local tabButton = button(tabBar, tab.label, COLORS.card, function()
			selectTab(tab.id)
		end)
		tabButton.LayoutOrder = index
		tabButton.Size = UDim2.new(0, 128, 1, 0)
		tabButtons[tab.id] = tabButton
	end

	tabContent = create("ScrollingFrame", {
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		Position = UDim2.fromOffset(20, 104),
		ScrollBarImageColor3 = COLORS.accent,
		ScrollBarThickness = 5,
		Size = UDim2.new(1, -40, 1, -120),
	}, panel)
	create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabContent)
end

function UI.toggle()
	local open = not panel.Visible
	panel.Visible = open
	if open then
		panel.Size = UDim2.fromOffset(PANEL_WIDTH * 0.94, PANEL_HEIGHT * 0.94)
		TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
			Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT),
		}):Play()
		refresh()
	end
end

function UI.init()
	screen = create("ScreenGui", {
		Name = "StarEmpireUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	buildHud()
	buildToastHolder()
	buildBottomBar()
	buildPanel()
	selectTab(currentTab)

	for _, attribute in { "XP", "Cargo", "CargoMax", "Zone", "Title" } do
		player:GetAttributeChangedSignal(attribute):Connect(updateHud)
	end
	task.spawn(function()
		local stats = player:WaitForChild("leaderstats")
		for _, name in { Config.StatNames.Credits, Config.StatNames.Level } do
			stats:WaitForChild(name).Changed:Connect(updateHud)
		end
		updateHud()
	end)
end

return UI
