import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// บริการจัดการฐานข้อมูล Todolist (รองรับทั้ง Google Sheet และบันทึกในเครื่อง)
class TodoService {
  static const String _storageKey = 'local_todolist_data_v1';
  static const String _sheetUrlKey = 'google_sheet_webapp_url';

  /// ดึง URL ของ Google Sheet Web App (ถ้ามี)
  static Future<String?> getSheetUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_sheetUrlKey);
    return (url != null && url.trim().isNotEmpty) ? url.trim() : null;
  }

  /// บันทึกหรือลบ URL ของ Google Sheet Web App
  static Future<void> setSheetUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      await prefs.remove(_sheetUrlKey);
    } else {
      await prefs.setString(_sheetUrlKey, url.trim());
    }
  }

  /// ดึงรายการทั้งหมด (ถ้าตั้งค่า Google Sheet จะดึงจากชีต ถ้าไม่มีจะดึงจากในเครื่อง)
  static Future<List<Map<String, dynamic>>> getTodos() async {
    final sheetUrl = await getSheetUrl();

    if (sheetUrl != null) {
      try {
        final response = await http.get(Uri.parse(sheetUrl)).timeout(Duration(seconds: 10));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is List) {
            final items = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
            await saveLocal(items);
            return items;
          }
        }
      } catch (e) {
        // หากเชื่อมต่อ Google Sheet ไม่ได้ ให้ดึงจากข้อมูลสำรองในเครื่อง
      }
    }

    return await getLocal();
  }

  /// เพิ่มรายการใหม่
  static Future<void> addTodo(String title, String detail) async {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final sheetUrl = await getSheetUrl();

    if (sheetUrl != null) {
      try {
        await http.post(
          Uri.parse(sheetUrl),
          headers: {"Content-Type": "application/json; charset=UTF-8"},
          body: jsonEncode({
            "action": "add",
            "id": newId,
            "title": title,
            "detail": detail,
          }),
        ).timeout(Duration(seconds: 10));
      } catch (e) {
        // หากต่อเน็ตไม่ได้ บันทึกไว้ในเครื่อง
      }
    }

    final items = await getLocal();
    items.insert(0, {
      "id": newId,
      "title": title,
      "detail": detail,
    });
    await saveLocal(items);
  }

  /// แก้ไขรายการ
  static Future<void> updateTodo(dynamic id, String title, String detail) async {
    final targetId = id.toString();
    final sheetUrl = await getSheetUrl();

    if (sheetUrl != null) {
      try {
        await http.post(
          Uri.parse(sheetUrl),
          headers: {"Content-Type": "application/json; charset=UTF-8"},
          body: jsonEncode({
            "action": "update",
            "id": targetId,
            "title": title,
            "detail": detail,
          }),
        ).timeout(Duration(seconds: 10));
      } catch (e) {
        // หากต่อเน็ตไม่ได้ อัพเดทในเครื่อง
      }
    }

    final items = await getLocal();
    for (var item in items) {
      if (item['id'].toString() == targetId) {
        item['title'] = title;
        item['detail'] = detail;
        break;
      }
    }
    await saveLocal(items);
  }

  /// ลบรายการ
  static Future<void> deleteTodo(dynamic id) async {
    final targetId = id.toString();
    final sheetUrl = await getSheetUrl();

    if (sheetUrl != null) {
      try {
        await http.post(
          Uri.parse(sheetUrl),
          headers: {"Content-Type": "application/json; charset=UTF-8"},
          body: jsonEncode({
            "action": "delete",
            "id": targetId,
          }),
        ).timeout(Duration(seconds: 10));
      } catch (e) {
        // หากต่อเน็ตไม่ได้ ลบในเครื่อง
      }
    }

    final items = await getLocal();
    items.removeWhere((item) => item['id'].toString() == targetId);
    await saveLocal(items);
  }

  /// ดึงข้อมูลจาก Local Storage ในเครื่อง
  static Future<List<Map<String, dynamic>>> getLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);

    if (data == null || data.trim().isEmpty) {
      final initialData = [
        {
          "id": "1",
          "title": "ยินดีต้อนรับสู่ Todolist",
          "detail": "แอปนี้สามารถบันทึกในเครื่อง หรือเชื่อมต่อกับ Google Sheets ได้"
        },
        {
          "id": "2",
          "title": "วิธีเชื่อมต่อ Google Sheet",
          "detail": "กดปุ่มไอคอนตาราง (Google Sheet) ด้านบนเพื่อวาง URL สคริปต์"
        }
      ];
      await saveLocal(initialData);
      return initialData;
    }

    try {
      List decoded = jsonDecode(data);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// บันทึกข้อมูลลง Local Storage
  static Future<void> saveLocal(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(items));
  }
}
