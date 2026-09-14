import 'package:flutter/material.dart';
import 'package:todolist/todo_service.dart';

class UpdatePage extends StatefulWidget {
  final dynamic id;
  final String title;
  final String detail;

  const UpdatePage(this.id, this.title, this.detail, {Key? key}) : super(key: key);

  @override
  _UpdatePageState createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  late TextEditingController todoTitle;
  late TextEditingController todoDetail;
  bool isUpdating = false;
  bool isDeleting = false;

  @override
  void initState() {
    super.initState();
    todoTitle = TextEditingController(text: widget.title);
    todoDetail = TextEditingController(text: widget.detail);
  }

  @override
  void dispose() {
    todoTitle.dispose();
    todoDetail.dispose();
    super.dispose();
  }

  Future<void> confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('ยืนยันการลบ'),
          ],
        ),
        content: Text('คุณต้องการลบรายการ "${widget.title}" นี้หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(primary: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('ลบรายการ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      deleteTodo();
    }
  }

  Future<void> deleteTodo() async {
    setState(() {
      isDeleting = true;
    });

    try {
      await TodoService.deleteTodo(widget.id);
      Navigator.pop(context, 'delete');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการลบข้อมูล'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isDeleting = false;
        });
      }
    }
  }

  Future<void> updateTodo() async {
    final title = todoTitle.text.trim();
    final detail = todoDetail.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('กรุณากรอกหัวข้อรายการ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isUpdating = true;
    });

    try {
      await TodoService.updateTodo(widget.id, title, detail);
      Navigator.pop(context, 'update');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการแก้ไขข้อมูล'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("แก้ไขรายการ"),
        actions: [
          IconButton(
            tooltip: 'ลบรายการนี้',
            onPressed: (isDeleting || isUpdating) ? null : confirmDelete,
            icon: isDeleting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(Icons.delete, color: Colors.redAccent),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
              controller: todoTitle,
              decoration: InputDecoration(
                labelText: 'รายการที่ต้องทำ *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: Icon(Icons.edit),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              minLines: 4,
              maxLines: 8,
              controller: todoDetail,
              decoration: InputDecoration(
                labelText: 'รายละเอียด',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: (isUpdating || isDeleting) ? null : updateTodo,
              icon: isUpdating
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(Icons.check_circle_outline),
              label: Text(
                isUpdating ? "กำลังบันทึกการแก้ไข..." : "บันทึกการแก้ไข",
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
