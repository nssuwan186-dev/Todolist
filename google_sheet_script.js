// ==========================================
// Google Apps Script สำหรับเชื่อมต่อกับ Todolist App
// ==========================================
// นำโค้ดนี้ไปวางใน Google Sheets -> ส่วนขยาย (Extensions) -> Apps Script

function doGet(e) {
  try {
    var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
    var rows = sheet.getDataRange().getValues();
    var data = [];

    // ตรวจสอบและสร้างหัวตารางอัตโนมัติหากตารางยังว่างอยู่
    if (rows.length === 0 || rows[0][0] === "") {
      sheet.appendRow(["id", "title", "detail", "timestamp"]);
      rows = sheet.getDataRange().getValues();
    }

    for (var i = 1; i < rows.length; i++) {
      if (rows[i][0] !== "" && rows[i][0] !== undefined) {
        data.push({
          id: rows[i][0].toString(),
          title: rows[i][1] ? rows[i][1].toString() : "",
          detail: rows[i][2] ? rows[i][2].toString() : ""
        });
      }
    }

    return ContentService.createTextOutput(JSON.stringify(data))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({ status: "error", message: error.toString() }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

function doPost(e) {
  try {
    var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
    var contents = e.postData.contents;
    var params = JSON.parse(contents);
    var action = params.action; // 'add', 'update', 'delete'

    // ตรวจสอบและสร้างหัวตารางอัตโนมัติหากยังไม่มี
    var rows = sheet.getDataRange().getValues();
    if (rows.length === 0 || rows[0][0] === "") {
      sheet.appendRow(["id", "title", "detail", "timestamp"]);
      rows = sheet.getDataRange().getValues();
    }

    if (action === 'add') {
      var newId = params.id ? params.id.toString() : new Date().getTime().toString();
      var title = params.title || "";
      var detail = params.detail || "";
      var now = new Date().toLocaleString("th-TH");
      sheet.appendRow([newId, title, detail, now]);
      return ContentService.createTextOutput(JSON.stringify({ status: "success", id: newId }))
        .setMimeType(ContentService.MimeType.JSON);
    } 
    else if (action === 'delete') {
      var targetId = params.id.toString();
      for (var i = 1; i < rows.length; i++) {
        if (rows[i][0].toString() === targetId) {
          sheet.deleteRow(i + 1);
          return ContentService.createTextOutput(JSON.stringify({ status: "success", deletedId: targetId }))
            .setMimeType(ContentService.MimeType.JSON);
        }
      }
      return ContentService.createTextOutput(JSON.stringify({ status: "not_found" }))
        .setMimeType(ContentService.MimeType.JSON);
    } 
    else if (action === 'update') {
      var targetId = params.id.toString();
      var title = params.title || "";
      var detail = params.detail || "";
      for (var i = 1; i < rows.length; i++) {
        if (rows[i][0].toString() === targetId) {
          sheet.getRange(i + 1, 2).setValue(title);
          sheet.getRange(i + 1, 3).setValue(detail);
          return ContentService.createTextOutput(JSON.stringify({ status: "success", updatedId: targetId }))
            .setMimeType(ContentService.MimeType.JSON);
        }
      }
      return ContentService.createTextOutput(JSON.stringify({ status: "not_found" }))
        .setMimeType(ContentService.MimeType.JSON);
    }

    return ContentService.createTextOutput(JSON.stringify({ status: "unknown_action" }))
      .setMimeType(ContentService.MimeType.JSON);

  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({ status: "error", message: error.toString() }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}
