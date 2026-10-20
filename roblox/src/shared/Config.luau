-- Balance, zones, shop and UI data live here, so the whole economy can be tuned in one place.
-- Every id = 0 must be replaced with a real id from the Roblox Creator Hub before publishing.
local Config = {}

Config.GameName = "Звёздная Империя"

Config.StatNames = {
	Credits = "Кредиты",
	Level = "Уровень",
}

Config.XPPerLevel = 200
Config.DailyReward = 750
Config.DailyCooldown = 20 * 3600
Config.QuestResetSeconds = 24 * 3600
Config.HistoryLimit = 100
Config.AutosaveSeconds = 60

Config.VIPMultiplier = 2
Config.SpeedMultiplier = 1.3
Config.DefaultWalkSpeed = 16

Config.Hub = {
	id = "hub",
	name = "Станция «Орбита-1»",
	blurb = "Торговля, верфь и порталы во все сектора",
	center = Vector3.new(0, 0, 0),
	radius = 130,
	accent = Color3.fromRGB(120, 170, 255),
}
Config.Hub.spawn = Config.Hub.center + Vector3.new(-40, 4, 0)

Config.Combat = {
	laserRange = 300,
	fireCooldown = 0.3,
	baseDamage = 25,
	damagePerLevel = 8,
	aggroRange = 60,
	attackRange = 6,
	attackCooldown = 1.5,
	enemiesPerZone = 6,
	enemyRespawnSeconds = 10,
	bossRespawnSeconds = 300,
}

Config.Mining = {
	holdSeconds = 1.5,
	respawnSeconds = 30,
	nodesPerZone = 10,
	cargoBase = 50,
	cargoPerLevel = 20,
	cargoPassBonus = 50,
}

Config.Upgrades = {
	damage = { name = "Лазерная пушка", baseCost = 200, maxLevel = 10, description = "+8 урона за каждый уровень" },
	mining = { name = "Бур", baseCost = 150, maxLevel = 10, description = "+1 руда за каждые 3 уровня добычи" },
	cargo = { name = "Грузовой трюм", baseCost = 250, maxLevel = 10, description = "+20 места в трюме за каждый уровень" },
}
Config.UpgradeOrder = { "damage", "mining", "cargo" }

function Config.upgradeCost(key, level)
	return math.floor(Config.Upgrades[key].baseCost * 1.6 ^ level)
end

Config.Quests = {
	{ id = "mine", name = "Добыть руду", target = 40, reward = 800, xp = 60 },
	{ id = "kill", name = "Уничтожить дронов", target = 20, reward = 1200, xp = 80 },
	{ id = "boss", name = "Победить босса", target = 1, reward = 5000, xp = 300 },
}

Config.Titles = {
	VIP = { rank = 1 },
	Supporter = { rank = 2 },
	Patron = { rank = 3 },
	Legend = { rank = 4 },
}

Config.GamePasses = {
	vip = {
		id = 0,
		name = "VIP-пилот",
		robux = 199,
		description = "×2 к заработку кредитов, золотой лазер и титул VIP",
	},
	cargo = {
		id = 0,
		name = "Расширенный трюм",
		robux = 99,
		description = "+50 к вместимости трюма навсегда",
	},
	speed = {
		id = 0,
		name = "Турбо-двигатели",
		robux = 79,
		description = "Скорость передвижения +30% на станции и в секторах",
	},
}
Config.PassOrder = { "vip", "cargo", "speed" }

Config.DevProducts = {
	credits_small = {
		id = 0,
		group = "credits",
		kind = "Кредиты",
		name = "Пакет «Старт»",
		robux = 25,
		credits = 5000,
		description = "5 000 кредитов для быстрого старта",
	},
	credits_medium = {
		id = 0,
		group = "credits",
		kind = "Кредиты",
		name = "Пакет «Капитан»",
		robux = 99,
		credits = 25000,
		description = "25 000 кредитов на апгрейды флота",
	},
	credits_large = {
		id = 0,
		group = "credits",
		kind = "Кредиты",
		name = "Пакет «Адмирал»",
		robux = 399,
		credits = 120000,
		description = "120 000 кредитов для полного перевооружения",
	},
	supporter = {
		id = 0,
		group = "support",
		kind = "Донат",
		name = "Поддержать автора",
		robux = 99,
		title = "Supporter",
		description = "Титул «Supporter» над головой и запись в истории покупок",
	},
	patron = {
		id = 0,
		group = "support",
		kind = "Донат",
		name = "Меценат",
		robux = 299,
		title = "Patron",
		description = "Титул «Patron» и благодарность команды в игре",
	},
	legend = {
		id = 0,
		group = "support",
		kind = "Донат",
		name = "Легенда галактики",
		robux = 999,
		title = "Legend",
		description = "Титул «Legend» и золотой лазер",
	},
	repair = {
		id = 0,
		group = "service",
		kind = "Услуга",
		name = "Экстренный ремонт",
		robux = 15,
		heal = true,
		description = "Полное восстановление корабля прямо в бою",
	},
}
Config.ProductOrder = { "credits_small", "credits_medium", "credits_large", "supporter", "patron", "legend", "repair" }

Config.Zones = {
	{
		id = "moon",
		name = "Луна",
		blurb = "Серые кратеры и первые стычки с дронами",
		requiredLevel = 1,
		center = Vector3.new(600, 0, 0),
		accent = Color3.fromRGB(180, 200, 255),
		groundColor = Color3.fromRGB(120, 120, 128),
		ground = Enum.Material.Slate,
		planetColor = Color3.fromRGB(190, 190, 200),
		planetSize = 420,
		ore = { name = "Лунный камень", value = 6, color = Color3.fromRGB(230, 230, 240), material = Enum.Material.Slate },
		enemy = { name = "Дрон-разведчик", health = 60, damage = 6, speed = 12, credits = 12, xp = 8, color = Color3.fromRGB(120, 200, 255) },
	},
	{
		id = "mars",
		name = "Марс",
		blurb = "Красные пески, пыльные бури и штурмовые дроны",
		requiredLevel = 3,
		center = Vector3.new(1200, 0, 0),
		accent = Color3.fromRGB(255, 140, 80),
		groundColor = Color3.fromRGB(160, 70, 40),
		ground = Enum.Material.Basalt,
		planetColor = Color3.fromRGB(190, 90, 60),
		planetSize = 460,
		ore = { name = "Марсианский железняк", value = 14, color = Color3.fromRGB(200, 90, 60), material = Enum.Material.Rock },
		enemy = { name = "Штурмовой дрон", health = 140, damage = 10, speed = 14, credits = 25, xp = 14, color = Color3.fromRGB(255, 110, 90) },
	},
	{
		id = "belt",
		name = "Пояс астероидов",
		blurb = "Рой каменных глыб и добыча титана",
		requiredLevel = 5,
		center = Vector3.new(1800, 0, 0),
		accent = Color3.fromRGB(255, 200, 120),
		groundColor = Color3.fromRGB(90, 80, 70),
		ground = Enum.Material.Rock,
		asteroids = true,
		ore = { name = "Титан", value = 30, color = Color3.fromRGB(170, 170, 200), material = Enum.Material.Metal },
		enemy = { name = "Рой-мошка", health = 260, damage = 14, speed = 18, credits = 45, xp = 24, color = Color3.fromRGB(255, 200, 90) },
	},
	{
		id = "europa",
		name = "Европа",
		blurb = "Ледяная корка над океаном и хрустальные жилы",
		requiredLevel = 7,
		center = Vector3.new(2400, 0, 0),
		accent = Color3.fromRGB(120, 220, 255),
		groundColor = Color3.fromRGB(190, 220, 240),
		ground = Enum.Material.Glacier,
		planetColor = Color3.fromRGB(200, 225, 240),
		planetSize = 480,
		ore = { name = "Кристалл льда", value = 55, color = Color3.fromRGB(150, 230, 255), material = Enum.Material.Glacier },
		enemy = { name = "Ледяной страж", health = 420, damage = 18, speed = 13, credits = 80, xp = 40, color = Color3.fromRGB(150, 230, 255) },
	},
	{
		id = "saturn",
		name = "Кольца Сатурна",
		blurb = "Ледяные осколки колец и быстрые охотники",
		requiredLevel = 9,
		center = Vector3.new(3000, 0, 0),
		accent = Color3.fromRGB(255, 230, 170),
		groundColor = Color3.fromRGB(150, 130, 100),
		ground = Enum.Material.Sand,
		planetColor = Color3.fromRGB(220, 200, 150),
		planetSize = 520,
		rings = true,
		ore = { name = "Лёд кольца", value = 90, color = Color3.fromRGB(235, 225, 200), material = Enum.Material.Ice },
		enemy = { name = "Кольцевой охотник", health = 650, damage = 24, speed = 20, credits = 130, xp = 65, color = Color3.fromRGB(255, 230, 170) },
	},
	{
		id = "nebula",
		name = "Туманность Ориона",
		blurb = "Светящаяся пыль и легенда — Чёрный Левиафан",
		requiredLevel = 11,
		center = Vector3.new(3600, 0, 0),
		accent = Color3.fromRGB(220, 120, 255),
		groundColor = Color3.fromRGB(70, 40, 110),
		ground = Enum.Material.Slate,
		planetColor = Color3.fromRGB(120, 60, 180),
		planetSize = 560,
		ore = { name = "Звёздная пыль", value = 160, color = Color3.fromRGB(230, 140, 255), material = Enum.Material.Neon },
		enemy = { name = "Тёмный спрайт", health = 1000, damage = 30, speed = 22, credits = 220, xp = 100, color = Color3.fromRGB(200, 120, 255) },
		boss = {
			name = "Чёрный Левиафан",
			health = 5000,
			damage = 45,
			speed = 10,
			credits = 1500,
			xp = 400,
			scale = 3,
			color = Color3.fromRGB(120, 40, 160),
		},
	},
}

Config.ZoneById = {}
for _, zone in Config.Zones do
	zone.spawn = zone.center + Vector3.new(-45, 4, 0)
	Config.ZoneById[zone.id] = zone
end

return Config
