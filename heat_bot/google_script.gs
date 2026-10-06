// Веб-приложение для бота «Нет тепла? Сообщите!»: дописывает заявки в лист «Заявки».
// Как установить — см. README.md, раздел «Google Таблица».

function doPost(e) {
  const lock = LockService.getScriptLock();
  try {
    lock.waitLock(30000);
    const data = JSON.parse(e.postData.contents);
    const book = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = book.getSheetByName('Заявки') || book.insertSheet('Заявки');
    if (sheet.getLastRow() === 0) {
      sheet.appendRow(data.header);
      sheet.getRange(1, 1, 1, data.header.length).setFontWeight('bold');
      sheet.setFrozenRows(1);
    }
    // Номера заявок, которые уже есть, — чтобы повторная отправка не дублировала строки
    const last = sheet.getLastRow();
    const known = new Set(
      last > 1 ? sheet.getRange(2, 1, last - 1, 1).getValues().map(r => String(r[0])) : []
    );
    const rows = data.rows.filter(r => !known.has(String(r[0])));
    if (rows.length) {
      sheet.getRange(last + 1, 1, rows.length, rows[0].length).setValues(rows);
    }
    return reply({ok: true, added: rows.length});
  } catch (err) {
    return reply({ok: false, error: String(err)});
  } finally {
    lock.releaseLock();
  }
}

// Проверка в браузере: открыть ссылку веб-приложения — должно показать {"ok":true}
function doGet() {
  return reply({ok: true});
}

function reply(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
