#!/usr/bin/env bash
# Автообновление: если в ветке на GitHub появились изменения — забирает их и переустанавливает бота.
# Запускается таймером heat-bot-update.timer (от root) раз в 10 минут.
set -euo pipefail

main() {
    cd "$(dirname "$0")/../.."  # корень репозитория
    git fetch -q origin
    [ "$(git rev-parse HEAD)" = "$(git rev-parse '@{u}')" ] && return 0
    git merge -q --ff-only '@{u}'
    bash heat_bot/deploy/install.sh
}

# Скрипт может обновить сам себя, поэтому bash читает его целиком до запуска
main "$@"; exit
