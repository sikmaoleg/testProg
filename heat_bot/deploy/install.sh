#!/usr/bin/env bash
# Установка бота службой systemd (Ubuntu/Debian): бот стартует при включении сервера
# и перезапускается после сбоя. Повторный запуск обновляет зависимости и перезапускает бота.
# Запуск: sudo bash deploy/install.sh
set -euo pipefail

cd "$(dirname "$0")/.."
BOT_DIR="$(pwd)"

apt-get update -qq
apt-get install -y -qq python3-venv curl >/dev/null

if ! curl -s -m 15 -o /dev/null https://api.telegram.org; then
    echo "⚠️  С этого сервера нет связи с api.telegram.org — бот здесь работать не сможет."
    echo "    Скорее всего, доступ к Telegram заблокирован: нужен сервер за пределами России."
fi

id heatbot >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin heatbot
python3 -m venv venv
venv/bin/pip install -q --upgrade -r requirements.txt
[ -f .env ] || cp .env.example .env
chown -R heatbot: "$BOT_DIR"
chmod 600 .env

sed "s#@BOT_DIR@#$BOT_DIR#g" deploy/heat-bot.service > /etc/systemd/system/heat-bot.service
systemctl daemon-reload
systemctl enable -q heat-bot

if grep -q "your-token" .env; then
    echo
    echo "Почти готово. Впишите настройки:  nano $BOT_DIR/.env"
    echo "и запустите бота:                 systemctl start heat-bot"
else
    systemctl restart heat-bot
    echo
    echo "Бот запущен. Состояние: systemctl status heat-bot   Журнал: journalctl -u heat-bot -f"
fi
