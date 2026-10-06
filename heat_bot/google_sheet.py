"""Запись заявок в Google Таблицу через веб-приложение Apps Script (код — google_script.gs)."""

import httpx


class SheetError(Exception):
    pass


def _cell(value):
    # Текст, начинающийся с = + - @, таблица посчитала бы формулой — экранируем апострофом
    if isinstance(value, str) and value[:1] in ("=", "+", "-", "@"):
        return "'" + value
    return value


async def append(url: str, header: list, rows: list) -> int:
    """Отправляет строки в таблицу и возвращает, сколько добавлено.
    Скрипт пропускает заявки, чьи номера уже есть в таблице, поэтому повтор безопасен."""
    payload = {"header": header, "rows": [[_cell(v) for v in row] for row in rows]}
    async with httpx.AsyncClient(timeout=60, follow_redirects=True) as client:
        try:
            resp = await client.post(url, json=payload)
        except httpx.HTTPError as e:
            raise SheetError(f"нет связи с Google ({type(e).__name__})") from e
    try:
        data = resp.json()
    except ValueError:
        raise SheetError(
            f"неожиданный ответ скрипта (HTTP {resp.status_code}) — проверьте ссылку "
            "и что веб-приложение развёрнуто с доступом «Все»"
        ) from None
    if not data.get("ok"):
        raise SheetError(f"ошибка скрипта: {data.get('error')}")
    return int(data.get("added", 0))
