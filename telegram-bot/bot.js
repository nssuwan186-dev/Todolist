/**
 * Telegram Bot สำหรับจัดการ Todolist
 * - เพิ่ม / ลบ / แก้ไข / ทำเครื่องหมายเสร็จสิ้น
 * - สรุปรายงานประจำวันและแจ้งเตือนอัตโนมัติ
 * - ถาม-ตอบ ค้นหาข้อมูลได้ทุกอย่าง
 * - เชื่อมต่อกับ Google Sheets หรือใช้งานในเครื่อง
 */

const fs = require('fs');
const path = require('path');

const CONFIG_FILE = path.join(__dirname, 'config.json');
const LOCAL_DB_FILE = path.join(__dirname, 'todolist_local.json');

// โหลดการตั้งค่า
function loadConfig() {
  if (!fs.existsSync(CONFIG_FILE)) {
    const defaultConfig = {
      botToken: process.env.TELEGRAM_BOT_TOKEN || process.argv[2] || "",
      sheetUrl: "",
      dailyReportHour: 8,
      dailyReportMinute: 0,
      chatIds: []
    };
    fs.writeFileSync(CONFIG_FILE, JSON.stringify(defaultConfig, null, 2));
    return defaultConfig;
  }
  try {
    return JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
  } catch (e) {
    return { botToken: "", sheetUrl: "", dailyReportHour: 8, dailyReportMinute: 0, chatIds: [] };
  }
}

function saveConfig(config) {
  fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
}

let config = loadConfig();

// อนุญาตให้รับ token จาก argument: node bot.js <TOKEN>
if (!config.botToken && process.argv[2]) {
  config.botToken = process.argv[2];
  saveConfig(config);
}

// ----------------------------------------------------
// ฐานข้อมูลและการดึงข้อมูล (Google Sheets หรือ Local)
// ----------------------------------------------------
function getLocalTodos() {
  if (!fs.existsSync(LOCAL_DB_FILE)) {
    const sample = [
      { id: "1", title: "เริ่มใช้งาน Todolist Bot", detail: "ทดสอบพิมพ์ /list หรือพิมพ์ถามบอทได้เลย", done: false, date: new Date().toLocaleDateString('th-TH') }
    ];
    fs.writeFileSync(LOCAL_DB_FILE, JSON.stringify(sample, null, 2));
    return sample;
  }
  try {
    return JSON.parse(fs.readFileSync(LOCAL_DB_FILE, 'utf8'));
  } catch (e) {
    return [];
  }
}

function saveLocalTodos(items) {
  fs.writeFileSync(LOCAL_DB_FILE, JSON.stringify(items, null, 2));
}

async function fetchTodos() {
  if (config.sheetUrl && config.sheetUrl.startsWith('http')) {
    try {
      const res = await fetch(config.sheetUrl);
      if (res.ok) {
        const data = await res.json();
        if (Array.isArray(data)) {
          saveLocalTodos(data);
          return data;
        }
      }
    } catch (err) {
      console.error("เชื่อมต่อ Google Sheets ไม่สำเร็จ ใช้ฐานข้อมูลสำรอง:", err.message);
    }
  }
  return getLocalTodos();
}

async function addTodo(title, detail) {
  const newId = Date.now().toString();
  const dateStr = new Date().toLocaleDateString('th-TH');
  const newItem = { id: newId, title, detail: detail || "", done: false, date: dateStr };

  if (config.sheetUrl && config.sheetUrl.startsWith('http')) {
    try {
      await fetch(config.sheetUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'add', id: newId, title, detail: detail || "" })
      });
    } catch (err) {
      console.error("ส่งไป Google Sheets ผิดพลาด:", err.message);
    }
  }

  const items = getLocalTodos();
  items.unshift(newItem);
  saveLocalTodos(items);
  return newItem;
}

async function updateTodo(id, title, detail, isDone) {
  const targetId = id.toString();
  const items = getLocalTodos();
  const item = items.find(i => i.id.toString() === targetId);
  if (item) {
    if (title !== undefined) item.title = title;
    if (detail !== undefined) item.detail = detail;
    if (isDone !== undefined) item.done = isDone;
    saveLocalTodos(items);
  }

  if (config.sheetUrl && config.sheetUrl.startsWith('http')) {
    try {
      await fetch(config.sheetUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'update',
          id: targetId,
          title: item ? item.title : title,
          detail: item ? item.detail : detail
        })
      });
    } catch (err) {}
  }
  return item;
}

async function deleteTodo(id) {
  const targetId = id.toString();
  let items = getLocalTodos();
  const beforeCount = items.length;
  items = items.filter(i => i.id.toString() !== targetId);
  saveLocalTodos(items);

  if (config.sheetUrl && config.sheetUrl.startsWith('http')) {
    try {
      await fetch(config.sheetUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'delete', id: targetId })
      });
    } catch (err) {}
  }
  return items.length < beforeCount;
}

// ----------------------------------------------------
// Telegram API Helper Functions
// ----------------------------------------------------
async function telegramRequest(method, payload) {
  if (!config.botToken) return null;
  const url = `https://api.telegram.org/bot${config.botToken}/${method}`;
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    return await res.json();
  } catch (err) {
    console.error(`Telegram API [${method}] Error:`, err.message);
    return null;
  }
}

async function sendMessage(chatId, text, replyMarkup = null) {
  const payload = { chat_id: chatId, text, parse_mode: 'HTML' };
  if (replyMarkup) payload.reply_markup = replyMarkup;
  return await telegramRequest('sendMessage', payload);
}

// ----------------------------------------------------
// คำสั่งและการตอบกลับข้อความ
// ----------------------------------------------------
async function handleStart(chatId) {
  if (!config.chatIds.includes(chatId)) {
    config.chatIds.push(chatId);
    saveConfig(config);
  }

  const text = `🤖 <b>ยินดีต้อนรับสู่ Todolist Assistant Bot!</b>\n` +
    `บอทที่จะช่วยคุณจัดการรายการที่ต้องทำ ตรวจสอบข้อมูล และรายงานประจำวัน\n\n` +
    `📌 <b>คำสั่งใช้งานด่วน:</b>\n` +
    `• /list - แสดงรายการที่ต้องทำทั้งหมด\n` +
    `• /add &lt;ข้อความ&gt; - เพิ่มรายการใหม่ (หรือพิมพ์ <i>"เพิ่ม [ข้อความ]"</i> ได้เลย)\n` +
    `• /report - ดูสรุปรายงานประจำวัน\n` +
    `• /done &lt;id&gt; - ทำเครื่องหมายว่าทำเสร็จแล้ว\n` +
    `• /del &lt;id&gt; - ลบรายการ\n` +
    `• /setsheet &lt;URL&gt; - เชื่อมต่อกับ Google Sheets Web App\n\n` +
    `💡 <i>คุณสามารถพิมพ์ถามคำถามทั่วไปได้ เช่น "มีงานอะไรบ้าง", "สรุปรายการ", "ค้นหา [คำ]"</i>`;

  const keyboard = {
    inline_keyboard: [
      [
        { text: '📋 ดูรายการทั้งหมด', callback_data: 'cmd_list' },
        { text: '📊 สรุปรายงานวันนี้', callback_data: 'cmd_report' }
      ],
      [
        { text: '➕ เพิ่มรายการใหม่', callback_data: 'cmd_help_add' },
        { text: '🔄 รีเฟรช', callback_data: 'cmd_refresh' }
      ]
    ]
  };

  await sendMessage(chatId, text, keyboard);
}

async function handleList(chatId) {
  const items = await fetchTodos();
  if (items.length === 0) {
    await sendMessage(chatId, '📭 <b>ยังไม่มีรายการที่ต้องทำ</b>\nคุณสามารถพิมพ์ <code>/add หัวข้อ | รายละเอียด</code> เพื่อเพิ่มรายการแรกได้เลยครับ');
    return;
  }

  let text = `📋 <b>รายการสิ่งที่ต้องทำ (${items.length} รายการ):</b>\n\n`;
  const inlineButtons = [];

  items.slice(0, 15).forEach((item, index) => {
    const isDone = item.done === true || item.title.startsWith('✅');
    const icon = isDone ? '✅' : '⏳';
    const cleanTitle = item.title.replace(/^✅\s*/, '');
    text += `${icon} <b>#${index + 1}</b> [ID: <code>${item.id}</code>]: <b>${cleanTitle}</b>\n`;
    if (item.detail && item.detail.trim()) {
      text += `   📝 <i>${item.detail}</i>\n`;
    }
    text += `\n`;

    inlineButtons.push([
      { text: isDone ? '↩️ ยกเลิกเสร็จ' : '✅ เสร็จแล้ว', callback_data: `done_${item.id}` },
      { text: '🗑️ ลบ', callback_data: `del_${item.id}` }
    ]);
  });

  if (items.length > 15) {
    text += `<i>(แสดง 15 รายการแรก จากทั้งหมด ${items.length} รายการ)</i>\n`;
  }

  inlineButtons.push([
    { text: '📊 สรุปรายงาน', callback_data: 'cmd_report' },
    { text: '🔄 รีเฟรช', callback_data: 'cmd_refresh' }
  ]);

  await sendMessage(chatId, text, { inline_keyboard: inlineButtons });
}

async function handleReport(chatId) {
  const items = await fetchTodos();
  const total = items.length;
  const completed = items.filter(i => i.done === true || i.title.startsWith('✅')).length;
  const pending = total - completed;
  const progressPercent = total > 0 ? Math.round((completed / total) * 100) : 0;

  let report = `📊 <b>รายงานสรุปภาพรวม Todolist ประจำวัน</b>\n`;
  report += `📅 วันที่: <b>${new Date().toLocaleDateString('th-TH', { dateStyle: 'full' })}</b>\n`;
  report += `━━━━━━━━━━━━━━━━━━\n`;
  report += `📦 รายการทั้งหมด: <b>${total}</b> รายการ\n`;
  report += `⏳ ค้างอยู่: <b>${pending}</b> รายการ\n`;
  report += `✅ ทำเสร็จแล้ว: <b>${completed}</b> รายการ\n`;
  report += `📈 ความคืบหน้า: <b>${progressPercent}%</b>\n\n`;

  if (pending > 0) {
    report += `🎯 <b>รายการที่ยังค้างอยู่:</b>\n`;
    const pendingList = items.filter(i => !(i.done === true || i.title.startsWith('✅'))).slice(0, 5);
    pendingList.forEach((item, idx) => {
      report += `• <b>${item.title}</b> (ID: <code>${item.id}</code>)\n`;
    });
    if (pending > 5) {
      report += `  <i>...และอีก ${pending - 5} รายการ</i>\n`;
    }
  } else if (total > 0) {
    report += `🎉 <i>ยอดเยี่ยมมาก! คุณทำรายการทั้งหมดเสร็จสิ้นแล้ว</i>\n`;
  }

  const keyboard = {
    inline_keyboard: [
      [
        { text: '📋 เปิดดูรายการทั้งหมด', callback_data: 'cmd_list' },
        { text: '🔄 อัพเดท', callback_data: 'cmd_report' }
      ]
    ]
  };

  await sendMessage(chatId, report, keyboard);
}

// ----------------------------------------------------
// ระบบ Smart Query (ถาม-ตอบภาษาไทย ค้นหาข้อมูลได้ทุกอย่าง)
// ----------------------------------------------------
async function handleNaturalQuery(chatId, text) {
  const lower = text.toLowerCase().trim();

  // ถามดูรายการ
  if (lower.includes('มีอะไร') || lower.includes('รายการ') || lower.includes('งาน') || lower.includes('list') || lower.includes('ต้องทำ')) {
    return handleList(chatId);
  }

  // ถามดูรายงาน/สรุป
  if (lower.includes('สรุป') || lower.includes('รายงาน') || lower.includes('ความคืบหน้า') || lower.includes('report') || lower.includes('วันนี้')) {
    return handleReport(chatId);
  }

  // คำสั่งเพิ่มรายการแบบข้อความธรรมชาติ เช่น "เพิ่ม ซื้อของเข้าบ้าน"
  if (lower.startsWith('เพิ่ม') || lower.startsWith('ช่วยบันทึก') || lower.startsWith('บันทึก')) {
    const content = text.replace(/^(เพิ่ม|ช่วยบันทึก|บันทึก)\s*/, '').trim();
    if (content) {
      const parts = content.split(/[\|\n]/);
      const title = parts[0].trim();
      const detail = parts[1] ? parts[1].trim() : "";
      const item = await addTodo(title, detail);
      await sendMessage(chatId, `✅ <b>เพิ่มรายการสำเร็จแล้ว!</b>\n📌 <b>${item.title}</b>\n(ID: <code>${item.id}</code>)`);
      return;
    }
  }

  // คำสั่งเสร็จสิ้น เช่น "เสร็จแล้ว 1234"
  if (lower.startsWith('เสร็จ') || lower.startsWith('ทำเสร็จ')) {
    const id = text.replace(/[^0-9]/g, '');
    if (id) {
      const updated = await updateTodo(id, undefined, undefined, true);
      if (updated) {
        await sendMessage(chatId, `🎉 <b>ยินดีด้วย! ทำเครื่องหมายเสร็จสิ้นแล้ว</b>: <i>${updated.title}</i>`);
        return;
      }
    }
  }

  // คำสั่งลบ เช่น "ลบ 1234"
  if (lower.startsWith('ลบ')) {
    const id = text.replace(/[^0-9]/g, '');
    if (id) {
      const deleted = await deleteTodo(id);
      if (deleted) {
        await sendMessage(chatId, `🗑️ <b>ลบรายการ ID <code>${id}</code> เรียบร้อยแล้ว</b>`);
        return;
      }
    }
  }

  // ค้นหารายการจากข้อความ
  const items = await fetchTodos();
  const matched = items.filter(i => 
    i.title.toLowerCase().includes(lower) || 
    (i.detail && i.detail.toLowerCase().includes(lower)) ||
    i.id.toString() === lower
  );

  if (matched.length > 0) {
    let reply = `🔍 <b>ผลการค้นหา (${matched.length} รายการ):</b>\n\n`;
    matched.forEach((m, idx) => {
      const icon = m.done ? '✅' : '⏳';
      reply += `${icon} <b>#${idx + 1}</b>: <b>${m.title}</b> (ID: <code>${m.id}</code>)\n`;
      if (m.detail) reply += `   📝 ${m.detail}\n`;
    });
    await sendMessage(chatId, reply);
    return;
  }

  // หากไม่ตรงกับอะไรเลย ให้ตอบคำแนะนำ
  await sendMessage(chatId, 
    `🤖 ผมเข้าใจสิ่งที่คุณต้องการได้ครับ คุณสามารถสั่งผมได้ เช่น:\n` +
    `• พิมพ์ <i>"มีอะไรต้องทำบ้าง"</i> เพื่อดูรายการทั้งหมด\n` +
    `• พิมพ์ <i>"เพิ่ม ซื้อนม | ยี่ห้อเมจิ"</i> เพื่อเพิ่มรายการ\n` +
    `• พิมพ์ <i>"สรุปรายงาน"</i> เพื่อดูความคืบหน้ารายวัน\n` +
    `• พิมพ์ค้นหาคำ เช่น <i>"ซื้อของ"</i> เพื่อหารายการที่เกี่ยวข้อง`
  );
}

// ----------------------------------------------------
// จัดการข้อความที่เข้ามา (Message Router)
// ----------------------------------------------------
async function handleMessage(msg) {
  const chatId = msg.chat.id;
  const text = (msg.text || '').trim();

  if (!text) return;

  if (text.startsWith('/start') || text.startsWith('/help')) {
    return handleStart(chatId);
  }

  if (text.startsWith('/list') || text.startsWith('/all')) {
    return handleList(chatId);
  }

  if (text.startsWith('/report') || text.startsWith('/today')) {
    return handleReport(chatId);
  }

  if (text.startsWith('/add')) {
    const content = text.replace(/^\/add\s*/, '').trim();
    if (!content) {
      await sendMessage(chatId, '⚠️ <b>กรุณาระบุรายการที่ต้องการเพิ่ม</b>\nตัวอย่าง: <code>/add ซื้อของเข้าบ้าน | ไข่ไก่ ผักสด</code>');
      return;
    }
    const parts = content.split(/[\|\n]/);
    const title = parts[0].trim();
    const detail = parts[1] ? parts[1].trim() : "";
    const item = await addTodo(title, detail);
    await sendMessage(chatId, `✅ <b>เพิ่มรายการสำเร็จแล้ว!</b>\n📌 <b>${item.title}</b>\n📝 <i>${item.detail || 'ไม่มีรายละเอียด'}</i>\n🆔 ID: <code>${item.id}</code>`);
    return;
  }

  if (text.startsWith('/done')) {
    const id = text.replace(/^\/done\s*/, '').trim();
    if (!id) {
      await sendMessage(chatId, '⚠️ กรุณาระบุ ID ของรายการ เช่น <code>/done 1234</code>');
      return;
    }
    const updated = await updateTodo(id, undefined, undefined, true);
    if (updated) {
      await sendMessage(chatId, `✅ <b>ทำเครื่องหมายว่าทำเสร็จแล้ว</b>: <i>${updated.title}</i>`);
    } else {
      await sendMessage(chatId, `❌ ไม่พบรายการ ID: <code>${id}</code>`);
    }
    return;
  }

  if (text.startsWith('/del') || text.startsWith('/delete')) {
    const id = text.replace(/^\/(del|delete)\s*/, '').trim();
    if (!id) {
      await sendMessage(chatId, '⚠️ กรุณาระบุ ID เช่น <code>/del 1234</code>');
      return;
    }
    const deleted = await deleteTodo(id);
    if (deleted) {
      await sendMessage(chatId, `🗑️ <b>ลบรายการ ID <code>${id}</code> สำเร็จแล้ว</b>`);
    } else {
      await sendMessage(chatId, `❌ ไม่พบรายการ ID: <code>${id}</code>`);
    }
    return;
  }

  if (text.startsWith('/setsheet')) {
    const url = text.replace(/^\/setsheet\s*/, '').trim();
    if (!url || !url.startsWith('http')) {
      await sendMessage(chatId, '⚠️ กรุณาระบุ Google Apps Script Web App URL ที่ถูกต้อง');
      return;
    }
    config.sheetUrl = url;
    saveConfig(config);
    await sendMessage(chatId, `🔗 <b>เชื่อมต่อ Google Sheets สำเร็จเรียบร้อย!</b>\nข้อมูลจากแอปและ Telegram จะซิงค์เข้าด้วยกันทันที`);
    return;
  }

  // ข้อความทั่วไป / Smart Query
  await handleNaturalQuery(chatId, text);
}

// ----------------------------------------------------
// จัดการปุ่มกด (Callback Queries)
// ----------------------------------------------------
async function handleCallbackQuery(cq) {
  const chatId = cq.message.chat.id;
  const data = cq.data;

  // ตอบกลับ Telegram ทันทีว่าได้รับ callback แล้ว
  await telegramRequest('answerCallbackQuery', { callback_query_id: cq.id });

  if (data === 'cmd_list') {
    return handleList(chatId);
  }
  if (data === 'cmd_report') {
    return handleReport(chatId);
  }
  if (data === 'cmd_refresh') {
    await sendMessage(chatId, '🔄 กำลังรีเฟรชข้อมูลล่าสุด...');
    return handleList(chatId);
  }
  if (data === 'cmd_help_add') {
    await sendMessage(chatId, '➕ <b>วิธีเพิ่มรายการใหม่:</b>\nพิมพ์ <code>/add หัวข้อ | รายละเอียด</code>\nหรือพิมพ์ข้อความธรรมดา เช่น <i>"เพิ่ม ซื้อของเข้าบ้าน"</i> ได้เลยครับ');
    return;
  }

  if (data.startsWith('done_')) {
    const id = data.replace('done_', '');
    const items = getLocalTodos();
    const item = items.find(i => i.id.toString() === id.toString());
    const newStatus = item ? !item.done : true;
    await updateTodo(id, undefined, undefined, newStatus);
    await sendMessage(chatId, newStatus ? `✅ <b>เสร็จเรียบร้อย!</b>` : `↩️ <b>เปลี่ยนสถานะกลับเป็นค้างอยู่</b>`);
    return handleList(chatId);
  }

  if (data.startsWith('del_')) {
    const id = data.replace('del_', '');
    await deleteTodo(id);
    await sendMessage(chatId, `🗑️ <b>ลบรายการ ID <code>${id}</code> เรียบร้อยแล้ว</b>`);
    return handleList(chatId);
  }
}

// ----------------------------------------------------
// ระบบแจ้งเตือนและส่งรายงานอัตโนมัติประจำวัน (Daily Notification)
// ----------------------------------------------------
let lastNotifiedDate = '';
function checkDailyNotification() {
  const now = new Date();
  const todayStr = now.toLocaleDateString('th-TH');

  if (now.getHours() === config.dailyReportHour && now.getMinutes() === config.dailyReportMinute && lastNotifiedDate !== todayStr) {
    lastNotifiedDate = todayStr;
    console.log(`[${now.toLocaleTimeString()}] กำลังส่งรายงานสรุปประจำวันอัตโนมัติ...`);
    if (config.chatIds && config.chatIds.length > 0) {
      config.chatIds.forEach(chatId => {
        sendMessage(chatId, `🔔 <b>แจ้งเตือนรายงานประจำวัน (Morning Summary)</b>`);
        handleReport(chatId);
      });
    }
  }
}

// ----------------------------------------------------
// ระบบ Long Polling ของ Telegram Bot
// ----------------------------------------------------
let offset = 0;
async function pollUpdates() {
  if (!config.botToken) {
    console.log("⚠️ ยังไม่มี Bot Token! กรุณาระบุ Token ใน config.json หรือรัน: node bot.js <YOUR_BOT_TOKEN>");
    process.exit(1);
  }

  try {
    const res = await telegramRequest('getUpdates', { offset, timeout: 25 });
    if (res && res.ok && Array.isArray(res.result)) {
      for (const update of res.result) {
        offset = update.update_id + 1;
        if (update.message) {
          await handleMessage(update.message);
        } else if (update.callback_query) {
          await handleCallbackQuery(update.callback_query);
        }
      }
    }
  } catch (err) {
    console.error("Polling Error:", err.message);
  }

  checkDailyNotification();
  setTimeout(pollUpdates, 500);
}

// เริ่มการทำงาน
console.log("==========================================");
console.log("🤖 Todolist Telegram Bot กำลังเริ่มต้น...");
console.log(`• Token: ${config.botToken ? '✅ กำหนดแล้ว' : '❌ ยังไม่ได้กำหนด'}`);
console.log(`• Google Sheet: ${config.sheetUrl ? config.sheetUrl : '⚡ โหมดออฟไลน์/ในเครื่อง'}`);
console.log("==========================================");

if (config.botToken) {
  telegramRequest('getMe', {}).then(info => {
    if (info && info.ok) {
      console.log(`🚀 บอทออนไลน์สำเร็จ! ชื่อบอท: @${info.result.username}`);
      console.log("คุณสามารถเปิด Telegram แล้วพิมพ์คำสั่ง /start คุยกับบอทได้ทันที");
      pollUpdates();
    } else {
      console.error("❌ Bot Token ไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง");
    }
  });
} else {
  console.log("กรุณากรอก Token ของคุณใน config.json หรือรันด้วยคำสั่ง:");
  console.log("node bot.js <YOUR_TELEGRAM_BOT_TOKEN>");
}
