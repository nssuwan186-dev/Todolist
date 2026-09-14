import 'package:flutter/material.dart';
import 'package:todolist/todo_service.dart';

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

  Future<void> saveTodo() async {
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
      await TodoService.addTodo(title, detail);
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการบันทึกข้อมูล'),
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
              onPressed: isSaving ? null : saveTodo,
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
