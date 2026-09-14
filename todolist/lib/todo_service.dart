import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// บริการจัดการฐานข้อมูลรายการ Todo ภายในเครื่อง (Local Offline Database)
/// ทำงานบนมือถือได้ทันที 100% ไม่ต้องต่อเซิร์ฟเวอร์ ไม่ต้องตั้งค่า IP
class TodoService {
  static const String _storageKey = 'local_todolist_data_v1';

  /// ดึงรายการทั้งหมดจากเครื่อง
  static Future<List<Map<String, dynamic>>> getTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);

    if (data == null || data.trim().isEmpty) {
      // รายการตัวอย่างเมื่อเปิดใช้งานครั้งแรก
      final initialData = [
        {
          "id": 1,
          "title": "ยินดีต้อนรับสู่สมุดบันทึกรายการ",
          "detail": "แอปนี้บันทึกข้อมูลในมือถือของคุณโดยตรง ใช้งานได้ทันทีไม่ต้องต่อเน็ต"
        },
        {
          "id": 2,
          "title": "ลองแตะที่รายการนี้เพื่อแก้ไขหรือลบ",
          "detail": "คุณสามารถแก้ไขหัวข้อ รายละเอียด หรือกดลบรายการได้"
        },
        {
          "id": 3,
          "title": "กดปุ่ม + ด้านล่างเพื่อเพิ่มรายการใหม่",
          "detail": "เพิ่มบันทึกงาน สิ่งที่ต้องทำ หรือสิ่งที่ต้องซื้อได้ตามต้องการ"
        }
      ];
      await saveTodos(initialData);
      return initialData;
    }

    try {
      List decoded = jsonDecode(data);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// บันทึกรายการทั้งหมดลงเครื่อง
  static Future<void> saveTodos(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(items));
  }

  /// เพิ่มรายการใหม่
  static Future<void> addTodo(String title, String detail) async {
    final items = await getTodos();
    final newId = DateTime.now().millisecondsSinceEpoch;
    items.insert(0, {
      "id": newId,
      "title": title,
      "detail": detail,
    });
    await saveTodos(items);
  }

  /// แก้ไขรายการ
  static Future<void> updateTodo(dynamic id, String title, String detail) async {
    final items = await getTodos();
    for (var item in items) {
      if (item['id'].toString() == id.toString()) {
        item['title'] = title;
        item['detail'] = detail;
        break;
      }
    }
    await saveTodos(items);
  }

  /// ลบรายการ
  static Future<void> deleteTodo(dynamic id) async {
    final items = await getTodos();
    items.removeWhere((item) => item['id'].toString() == id.toString());
    await saveTodos(items);
  }
}
