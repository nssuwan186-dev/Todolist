import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:todolist/config.dart';

class AddPage extends StatefulWidget {
  const AddPage({Key? key}) : super(key: key);

  @override
  _AddPageState createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final TextEditingController todoTitle = TextEditingController();
  final TextEditingController todoDetail = TextEditingController();
  bool isSaving = false;

  @override
  void dispose() {
    todoTitle.dispose();
    todoDetail.dispose();
    super.dispose();
  }

  Future<void> postTodo() async {
    final title = todoTitle.text.trim();
    final detail = todoDetail.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('กรุณากรอกชื่อรายการที่ต้องทำ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      var url = AppConfig.getUri('/api/post-todolist');
      Map<String, String> headers = {
        "Content-type": "application/json; charset=UTF-8"
      };
      String jsondata = '{"title": ${jsonEncodeString(title)}, "detail": ${jsonEncodeString(detail)}}';

      var response = await http.post(url, headers: headers, body: jsondata).timeout(Duration(seconds: 7));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('บันทึกไม่สำเร็จ (รหัสสถานะ: ${response.statusCode})'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาตรวจสอบ IP'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  String jsonEncodeString(String value) {
    return '"' +
        value
            .replaceAll(r'\', r'\\')
            .replaceAll('"', r'\"')
            .replaceAll('\n', r'\n')
            .replaceAll('\r', r'\r')
            .replaceAll('\t', r'\t') +
        '"';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("เพิ่มรายการใหม่"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
              controller: todoTitle,
              decoration: InputDecoration(
                labelText: 'รายการที่ต้องทำ *',
                hintText: 'เช่น ซื้อของเข้าบ้าน, อ่านหนังสือ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: Icon(Icons.assignment),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              minLines: 4,
              maxLines: 8,
              controller: todoDetail,
              decoration: InputDecoration(
                labelText: 'รายละเอียด',
                hintText: 'รายละเอียดเพิ่มเติม (ถ้ามี)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: isSaving ? null : postTodo,
              icon: isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(Icons.save),
              label: Text(
                isSaving ? "กำลังบันทึก..." : "บันทึกรายการ",
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
