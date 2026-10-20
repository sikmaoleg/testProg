# Coin Rush Obby

Паркур-башня для Roblox: 30 платформ по спирали, монетки, батуты, лава внизу и чекпоинты каждые 5 платформ. Лучший игрок — тот, кто набрал больше всех монет и выигрышей.

## Что внутри

- Монетки вращаются и покачиваются (клиент) и возрождаются через 20 секунд после сбора (сервер).
- Батуты (желтые светящиеся пады) подбрасывают игрока вверх.
- Лава на дне убивает игрока; после возрождения он появляется на последнем чекпоинте.
- Зелёные платформы — чекпоинты, золотая — финиш. На финише игрок получает `Wins` и 50 монет, после чего телепортируется на старт.
- Таблица лидеров (`leaderstats`): `Coins`, `Stage` (максимальная достигнутая платформа), `Wins`.

## Структура

```
roblox/
├── default.project.json                       # конфиг Rojo
└── src/
    ├── ServerScriptService/
    │   ├── CourseBuilder.luau                 # ModuleScript: строит карту кодом
    │   └── Main.server.luau                   # Script: логика игры на сервере
    └── StarterPlayer/StarterPlayerScripts/
        └── CoinSpinner.client.luau            # LocalScript: анимация монет
```

## Запуск

### Вариант 1: через Rojo (удобнее)

1. Установите [Rojo](https://rojo.space) (например, через Aftman или Foreman) и плагин Rojo в Roblox Studio.
2. В папке `roblox/` выполните `rojo serve`.
3. В Studio откройте пустой Baseplate, нажмите **Connect** в плагине Rojo.
4. Нажмите **Play**.

### Вариант 2: вручную, без Rojo

1. В Roblox Studio создайте пустой Baseplate.
2. В `ServerScriptService` добавьте:
   - `Script` с именем `Main`, вставьте туда содержимое `Main.server.luau`;
   - `ModuleScript` с именем `CourseBuilder`, вставьте туда содержимое `CourseBuilder.luau`.
3. В `StarterPlayer > StarterPlayerScripts` добавьте `LocalScript` с именем `CoinSpinner` и вставьте туда `CoinSpinner.client.luau`.
4. Нажмите **Play**.

## Идеи для развития

- Сохранение `Coins` и `Wins` через `DataStoreService`.
- Магазин скинов на монетки и случайные «сюрприз-платформы».
- Отдельные таймеры забега и рекорды.
- Более сложные препятствия: движущиеся платформы, исчезающие блоки.
