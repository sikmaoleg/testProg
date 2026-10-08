"""Телеграм-бот «Нет тепла? Сообщите!» — сбор обращений жителей г.о. Черноголовка
об отсутствии отопления и горячей воды."""

import asyncio
import csv
import io
import logging
import os
import sqlite3
from datetime import datetime
from zoneinfo import ZoneInfo

from telegram import (
    KeyboardButton,
    ReplyKeyboardMarkup,
    ReplyKeyboardRemove,
    Update,
)
from telegram.ext import (
    Application,
    CommandHandler,
    ContextTypes,
    ConversationHandler,
    MessageHandler,
    filters,
)

import google_sheet

logging.basicConfig(format="%(asctime)s %(levelname)s %(name)s: %(message)s", level=logging.INFO)
logging.getLogger("httpx").setLevel(logging.WARNING)  # не логировать каждый запрос: в URL есть токен
log = logging.getLogger("heat_bot")


def load_env(path: str = ".env") -> None:
    """Простейшая загрузка .env без внешних зависимостей."""
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                os.environ.setdefault(key.strip(), value.strip())


load_env(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env"))

BOT_TOKEN = os.environ.get("BOT_TOKEN", "")
ADMIN_IDS = {int(x) for x in os.environ.get("ADMIN_IDS", "").replace(" ", "").split(",") if x}
ADMIN_CHAT_ID = os.environ.get("ADMIN_CHAT_ID", "").strip()
DB_PATH = os.environ.get("DB_PATH", "reports.db")
# Время заявок — московское, в каком бы часовом поясе ни был сервер
TIMEZONE = ZoneInfo(os.environ.get("TIMEZONE") or "Europe/Moscow")
REPORT_START = int(os.environ.get("REPORT_START") or 1)  # с какого номера начать нумерацию в новой базе
GOOGLE_SCRIPT_URL = os.environ.get("GOOGLE_SCRIPT_URL", "").strip()

DISTRICT = "г.о. Черноголовка"
CITY_GEN = "Черноголовки"  # «жителей Черноголовки»
SLOGAN = "🔥 Нет тепла? Сообщите!"

# Профиль бота: текст на пустом экране чата, краткое описание и меню команд
DESCRIPTION = (
    f"{SLOGAN}\n\n"
    f"Бот для жителей {CITY_GEN}. Если дома холодно, не работает отопление "
    "или нет горячей воды — оставьте заявку, и с вами свяжутся."
)
SHORT_DESCRIPTION = f"{SLOGAN} Сбор обращений жителей {CITY_GEN} об отоплении и горячей воде."
COMMANDS = [
    ("report", "Сообщить о проблеме"),
    ("help", "Помощь"),
    ("cancel", "Отменить заявку"),
]

# Тексты кнопок
BTN_REPORT = "📝 Сообщить о проблеме"
BTN_SKIP = "⏭ Пропустить"
BTN_CANCEL = "❌ Отмена"
BTN_SEND = "✅ Отправить"
PROBLEMS = [
    "❄️ Нет отопления",
    "🌡 Батареи еле тёплые",
    "🚿 Нет горячей воды",
    "🏢 Холодно в подъезде",
    "❓ Другое",
]
DURATIONS = ["Сегодня", "1–2 дня", "3–7 дней", "Больше недели"]

PROBLEM, ADDRESS, APARTMENT, DURATION, PHONE, COMMENT, CONFIRM = range(7)


# ---------------------------------------------------------------- база данных

def db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with db() as conn:
        conn.execute(
            """CREATE TABLE IF NOT EXISTS reports (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                created_at TEXT NOT NULL,
                user_id INTEGER,
                username TEXT,
                full_name TEXT,
                problem TEXT,
                address TEXT,
                apartment TEXT,
                duration TEXT,
                phone TEXT,
                comment TEXT
            )"""
        )
        conn.execute("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)")
        # При переезде на новый сервер номера продолжаются, а не совпадают со строками в таблице
        row = conn.execute("SELECT seq FROM sqlite_sequence WHERE name = 'reports'").fetchone()
        if REPORT_START - 1 > (row["seq"] if row else 0):
            conn.execute("DELETE FROM sqlite_sequence WHERE name = 'reports'")
            conn.execute("INSERT INTO sqlite_sequence (name, seq) VALUES ('reports', ?)", (REPORT_START - 1,))


def get_meta(key: str, default: str = "") -> str:
    with db() as conn:
        row = conn.execute("SELECT value FROM meta WHERE key = ?", (key,)).fetchone()
    return row["value"] if row else default


def set_meta(key: str, value: str) -> None:
    with db() as conn:
        conn.execute("INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)", (key, value))


# Столбцы выгрузки — для CSV и Google Таблицы
COLUMNS = ["№", "Дата", "Проблема", "Адрес", "Квартира", "Как давно", "Телефон",
           "Комментарий", "Имя", "Username", "User ID"]


def report_row(r) -> list:
    return [r["id"], r["created_at"], r["problem"], r["address"], r["apartment"], r["duration"],
            r["phone"], r["comment"], r["full_name"], r["username"], r["user_id"]]


def save_report(data: dict) -> int:
    with db() as conn:
        cur = conn.execute(
            """INSERT INTO reports (created_at, user_id, username, full_name, problem, address,
                                    apartment, duration, phone, comment)
               VALUES (:created_at, :user_id, :username, :full_name, :problem, :address,
                       :apartment, :duration, :phone, :comment)""",
            data,
        )
        return cur.lastrowid


# ---------------------------------------------------------------- клавиатуры

def kb(rows, one_time=True) -> ReplyKeyboardMarkup:
    return ReplyKeyboardMarkup(rows, resize_keyboard=True, one_time_keyboard=one_time)


MAIN_KB = kb([[BTN_REPORT]], one_time=False)
PROBLEM_KB = kb([[p] for p in PROBLEMS] + [[BTN_CANCEL]])
DURATION_KB = kb([DURATIONS[:2], DURATIONS[2:], [BTN_CANCEL]])
SKIP_KB = kb([[BTN_SKIP], [BTN_CANCEL]])
CANCEL_KB = kb([[BTN_CANCEL]])
PHONE_KB = kb([[KeyboardButton("📱 Отправить мой номер", request_contact=True)], [BTN_SKIP], [BTN_CANCEL]])
CONFIRM_KB = kb([[BTN_SEND], [BTN_CANCEL]])


def summary(d: dict) -> str:
    return (
        f"Проблема: {d.get('problem')}\n"
        f"Адрес: {DISTRICT}, {d.get('address')}"
        + (f", кв. {d['apartment']}" if d.get("apartment") else "")
        + f"\nКак давно: {d.get('duration')}\n"
        f"Телефон: {d.get('phone') or '—'}\n"
        f"Комментарий: {d.get('comment') or '—'}"
    )


# ---------------------------------------------------------------- диалог

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    await update.message.reply_text(
        f"{SLOGAN}\n\n"
        f"Это бот для жителей {CITY_GEN}. Если у вас дома холодно, нет отопления "
        "или горячей воды — оставьте заявку, и с вами свяжутся.\n\n"
        f"Нажмите «{BTN_REPORT}», чтобы начать.",
        reply_markup=MAIN_KB,
    )
    return ConversationHandler.END


async def help_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    text = (
        f"{SLOGAN}\n\n"
        "/report — оставить заявку\n"
        "/cancel — отменить заполнение\n"
    )
    if update.effective_user.id in ADMIN_IDS:
        text += "\nДля администраторов:\n/stats — сводка по адресам\n/export — выгрузка заявок в CSV\n"
    await update.message.reply_text(text, reply_markup=MAIN_KB)


async def report_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    context.user_data.clear()
    await update.message.reply_text("Что случилось?", reply_markup=PROBLEM_KB)
    return PROBLEM


async def got_problem(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    context.user_data["problem"] = update.message.text.strip()
    await update.message.reply_text(
        "Укажите адрес: улицу и номер дома.\n"
        "Если живёте не в самой Черноголовке — добавьте населённый пункт.\n"
        "Например: <i>Школьный бульвар, 10</i>",
        parse_mode="HTML",
        reply_markup=CANCEL_KB,
    )
    return ADDRESS


async def got_address(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    context.user_data["address"] = update.message.text.strip()[:200]
    await update.message.reply_text("Номер квартиры (или пропустите):", reply_markup=SKIP_KB)
    return APARTMENT


async def got_apartment(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    text = update.message.text.strip()
    context.user_data["apartment"] = "" if text == BTN_SKIP else text[:20]
    await update.message.reply_text("Как давно нет тепла?", reply_markup=DURATION_KB)
    return DURATION


async def got_duration(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    context.user_data["duration"] = update.message.text.strip()[:50]
    await update.message.reply_text(
        "Оставьте телефон для связи (по желанию):", reply_markup=PHONE_KB
    )
    return PHONE


async def got_phone(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    msg = update.message
    if msg.contact:
        context.user_data["phone"] = msg.contact.phone_number
    elif msg.text and msg.text != BTN_SKIP:
        context.user_data["phone"] = msg.text.strip()[:30]
    else:
        context.user_data["phone"] = ""
    await msg.reply_text(
        "Комментарий: температура в квартире, подробности (или пропустите):",
        reply_markup=SKIP_KB,
    )
    return COMMENT


async def got_comment(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    text = update.message.text.strip()
    context.user_data["comment"] = "" if text == BTN_SKIP else text[:1000]
    await update.message.reply_text(
        "Проверьте заявку:\n\n" + summary(context.user_data), reply_markup=CONFIRM_KB
    )
    return CONFIRM


async def confirm(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    user = update.effective_user
    d = dict(context.user_data)
    d.update(
        created_at=datetime.now(TIMEZONE).strftime("%Y-%m-%d %H:%M"),
        user_id=user.id,
        username=user.username or "",
        full_name=user.full_name,
    )
    for key in ("apartment", "phone", "comment"):
        d.setdefault(key, "")
    report_id = save_report(d)
    context.user_data.clear()

    await update.message.reply_text(
        f"Спасибо! Заявка №{report_id} принята. 🙏\n"
        "Мы передадим её ответственным службам.\n\n"
        "Если проблема повторится — сообщите снова.",
        reply_markup=MAIN_KB,
    )
    await notify_admins(context, report_id, d)
    if GOOGLE_SCRIPT_URL:
        context.application.create_task(sync_sheet(context.bot))
    return ConversationHandler.END


async def send_admins(bot, text: str) -> None:
    for chat_id in [ADMIN_CHAT_ID] if ADMIN_CHAT_ID else list(ADMIN_IDS):
        try:
            await bot.send_message(chat_id, text)
        except Exception as e:  # noqa: BLE001 — уведомление не должно ронять диалог
            log.warning("Не удалось уведомить %s: %s", chat_id, e)


async def notify_admins(context: ContextTypes.DEFAULT_TYPE, report_id: int, d: dict) -> None:
    who = d["full_name"] + (f" (@{d['username']})" if d["username"] else "")
    await send_admins(context.bot, f"🆕 Заявка №{report_id} от {d['created_at']}\nОт: {who}\n\n{summary(d)}")


# ---------------------------------------------------------------- Google Таблица

SHEET_LOCK = asyncio.Lock()


async def sync_sheet(bot) -> None:
    """Дописывает в Google Таблицу заявки, которые туда ещё не попали.
    Если отправка не удалась, они уйдут со следующей заявкой или при перезапуске бота."""
    key = f"sheet_last_id:{GOOGLE_SCRIPT_URL}"  # новая ссылка — новая таблица, в неё уйдут все заявки
    async with SHEET_LOCK:
        with db() as conn:
            pending = conn.execute(
                "SELECT * FROM reports WHERE id > ? ORDER BY id", (int(get_meta(key, "0")),)
            ).fetchall()
        if not pending:
            return
        try:
            added = await google_sheet.append(GOOGLE_SCRIPT_URL, COLUMNS, [report_row(r) for r in pending])
        except Exception as e:  # noqa: BLE001 — сбой таблицы не должен мешать приёму заявок
            log.warning("Google Таблица: %s", e)
            await send_admins(bot, f"⚠️ Не удалось записать заявки в Google Таблицу: {e}\n"
                                   "Попробую снова со следующей заявкой.")
            return
        set_meta(key, str(pending[-1]["id"]))
        log.info("Google Таблица: добавлено строк: %s", added)


async def cancel(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    context.user_data.clear()
    await update.message.reply_text("Заявка отменена.", reply_markup=MAIN_KB)
    return ConversationHandler.END


async def wrong_input(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await update.message.reply_text("Пожалуйста, используйте кнопки ниже или /cancel для отмены.")


# ---------------------------------------------------------------- администрирование

def admin_only(func):
    async def wrapper(update: Update, context: ContextTypes.DEFAULT_TYPE):
        if update.effective_user.id not in ADMIN_IDS:
            await update.message.reply_text("Команда доступна только администраторам.")
            return
        return await func(update, context)

    return wrapper


@admin_only
async def stats(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    with db() as conn:
        total = conn.execute("SELECT COUNT(*) FROM reports").fetchone()[0]
        today = conn.execute(
            "SELECT COUNT(*) FROM reports WHERE created_at LIKE ?",
            (datetime.now(TIMEZONE).strftime("%Y-%m-%d") + "%",),
        ).fetchone()[0]
        by_addr = conn.execute(
            "SELECT address, COUNT(*) AS n FROM reports GROUP BY LOWER(address) ORDER BY n DESC LIMIT 20"
        ).fetchall()
        by_problem = conn.execute(
            "SELECT problem, COUNT(*) AS n FROM reports GROUP BY problem ORDER BY n DESC"
        ).fetchall()
    lines = [f"📊 Всего заявок: {total}, сегодня: {today}", "", "По адресам (топ-20):"]
    lines += [f"• {r['address']} — {r['n']}" for r in by_addr] or ["—"]
    lines += ["", "По типу проблемы:"]
    lines += [f"• {r['problem']} — {r['n']}" for r in by_problem] or ["—"]
    await update.message.reply_text("\n".join(lines))


@admin_only
async def export(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    with db() as conn:
        rows = conn.execute("SELECT * FROM reports ORDER BY id").fetchall()
    buf = io.StringIO()
    writer = csv.writer(buf, delimiter=";")
    writer.writerow(COLUMNS)
    writer.writerows(report_row(r) for r in rows)
    data = buf.getvalue().encode("utf-8-sig")  # BOM — чтобы Excel корректно открыл кириллицу
    name = f"zayavki_chernogolovka_{datetime.now(TIMEZONE):%Y%m%d_%H%M}.csv"
    await update.message.reply_document(io.BytesIO(data), filename=name,
                                        caption=f"Заявок: {len(rows)}")


# ---------------------------------------------------------------- запуск

async def post_init(app: Application) -> None:
    """Заполняет профиль бота, если он ещё пустой (правки из @BotFather не перезаписываются),
    и досылает в Google Таблицу заявки, которые туда ещё не попали."""
    try:
        if not (await app.bot.get_my_description()).description:
            await app.bot.set_my_description(DESCRIPTION)
        if not (await app.bot.get_my_short_description()).short_description:
            await app.bot.set_my_short_description(SHORT_DESCRIPTION)
        if not await app.bot.get_my_commands():
            await app.bot.set_my_commands(COMMANDS)
    except Exception as e:  # noqa: BLE001 — профиль не критичен для работы
        log.warning("Не удалось настроить профиль бота: %s", e)
    if GOOGLE_SCRIPT_URL:
        await sync_sheet(app.bot)


def main() -> None:
    if not BOT_TOKEN:
        raise SystemExit("Не задан BOT_TOKEN (см. .env.example)")
    init_db()

    app = Application.builder().token(BOT_TOKEN).post_init(post_init).build()

    cancel_filter = filters.Regex(f"^{BTN_CANCEL}$")
    text = filters.TEXT & ~filters.COMMAND & ~cancel_filter
    skip = filters.Regex(f"^{BTN_SKIP}$")

    conv = ConversationHandler(
        entry_points=[
            CommandHandler("report", report_start),
            MessageHandler(filters.Regex(f"^{BTN_REPORT}$"), report_start),
        ],
        states={
            PROBLEM: [MessageHandler(text, got_problem)],
            ADDRESS: [MessageHandler(text & ~skip, got_address)],
            APARTMENT: [MessageHandler(text, got_apartment)],
            DURATION: [MessageHandler(text, got_duration)],
            PHONE: [MessageHandler(filters.CONTACT | text, got_phone)],
            COMMENT: [MessageHandler(text, got_comment)],
            CONFIRM: [MessageHandler(filters.Regex(f"^{BTN_SEND}$"), confirm)],
        },
        fallbacks=[
            CommandHandler("cancel", cancel),
            MessageHandler(cancel_filter, cancel),
            CommandHandler("start", cancel),
            MessageHandler(filters.ALL & ~filters.COMMAND, wrong_input),
        ],
    )

    app.add_handler(conv)
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("help", help_cmd))
    app.add_handler(CommandHandler("stats", stats))
    app.add_handler(CommandHandler("export", export))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, start))

    log.info("Бот запущен: %s", SLOGAN)
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
