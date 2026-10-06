"""Запись заявок в Google Таблицу через веб-приложение Apps Script (код — google_script.gs)."""

import asyncio
import html
import logging
import re

import httpx

log = logging.getLogger("heat_bot")

# Паузы между попытками, с. Google иногда отвечает ошибкой, даже записав строки, — повтор
# безопасен: скрипт пропускает заявки, чьи номера уже есть в таблице.
RETRY_DELAYS = (3, 10)


class SheetError(Exception):
    pass


def _cell(value):
    # Текст, начинающийся с = + - @, таблица посчитала бы формулой — экранируем апострофом
    if isinstance(value, str) and value[:1] in ("=", "+", "-", "@"):
        return "'" + value
    return value


async def append(url: str, header: list, rows: list) -> int:
    """Отправляет строки в таблицу и возвращает, сколько добавлено. При сбое повторяет."""
    payload = {"header": header, "rows": [[_cell(v) for v in row] for row in rows]}
    for attempt, delay in enumerate((*RETRY_DELAYS, None), 1):
        try:
            return await _post(url, payload)
        except SheetError as e:
            if delay is None:
                raise
            log.info("Google Таблица: попытка %s не удалась (%s), повтор через %s с", attempt, e, delay)
            await asyncio.sleep(delay)


async def _post(url: str, payload: dict) -> int:
    async with httpx.AsyncClient(timeout=30, follow_redirects=True) as client:
        try:
            resp = await client.post(url, json=payload)
        except httpx.HTTPError as e:
            raise SheetError(f"нет связи с Google ({type(e).__name__})") from e
    try:
        data = resp.json()
    except ValueError:
        raise SheetError(_explain(resp)) from None
    if not data.get("ok"):
        raise SheetError(f"ошибка скрипта: {data.get('error')}")
    return int(data.get("added", 0))


def _explain(resp: httpx.Response) -> str:
    """Понятная причина, когда вместо ответа скрипта пришла HTML-страница Google."""
    if resp.url.host == "accounts.google.com":
        return "Google просит войти в аккаунт — разверните веб-приложение с доступом «Все»"
    page = re.sub(r"<script.*?</script>|<style.*?</style>|<[^>]+>", " ", resp.text, flags=re.S)
    page = re.sub(r"\s+", " ", html.unescape(page)).strip()
    if "Script function not found" in page:
        return ("в развёрнутой версии скрипта нет кода — сохраните код в Apps Script и разверните "
                "новую версию (Управление развертываниями → ✏️ → Новая версия)")
    if "unable to open the file" in page:
        return "Google не открыл скрипт (HTTP 404 «unable to open the file»)"
    return f"неожиданный ответ скрипта (HTTP {resp.status_code}): {page[:150]}"
