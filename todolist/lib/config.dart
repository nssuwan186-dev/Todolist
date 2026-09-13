import 'package:flutter/material.dart';

/// การตั้งค่าเชื่อมต่อเซิร์ฟเวอร์ (API Configuration)
class AppConfig {
  // ค่าเริ่มต้น Server IP / Host สำหรับเชื่อมต่อ Django backend
  // สามารถเปลี่ยนได้ในแอพผ่านปุ่มตั้งค่า (Settings) บนหน้าแรก
  static String serverHost = '192.168.1.34:8000';
  static bool isHttps = false;

  /// สร้าง Uri สำหรับเรียก API
  static Uri getUri(String path) {
    if (isHttps) {
      return Uri.https(serverHost, path);
    } else {
      return Uri.http(serverHost, path);
    }
  }

  /// Dialog สำหรับแก้ไข Server IP ในแอพ
  static Future<void> showServerSettingsDialog(BuildContext context, VoidCallback onSaved) async {
    final controller = TextEditingController(text: serverHost);
    bool useHttps = isHttps;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.dns, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('ตั้งค่า Server IP'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ระบุ IP Address หรือ Hostname ของ Django Backend:',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'IP หรือ Host:Port',
                        hintText: 'เช่น 192.168.1.34:8000',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.computer),
                      ),
                    ),
                    SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('ใช้งาน HTTPS'),
                      value: useHttps,
                      onChanged: (val) {
                        setDialogState(() {
                          useHttps = val ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final trimmed = controller.text.trim();
                    if (trimmed.isNotEmpty) {
                      serverHost = trimmed;
                      isHttps = useHttps;
                      Navigator.pop(context);
                      onSaved();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('บันทึกการตั้งค่า Server IP เรียบร้อยแล้ว'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: Text('บันทึก'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
