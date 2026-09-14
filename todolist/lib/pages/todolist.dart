import 'package:flutter/material.dart';
import 'package:todolist/pages/add.dart';
import 'package:todolist/pages/update_todolist.dart';
import 'package:todolist/todo_service.dart';

class Todolist extends StatefulWidget {
  @override
  _TodolistState createState() => _TodolistState();
}

class _TodolistState extends State<Todolist> {
  List<Map<String, dynamic>> todolistitems = [];
  bool isLoading = true;
  String? currentSheetUrl;

  @override
  void initState() {
    super.initState();
    loadTodos();
  }

  Future<void> loadTodos() async {
    setState(() {
      isLoading = true;
    });

    final url = await TodoService.getSheetUrl();
    final data = await TodoService.getTodos();

    setState(() {
      currentSheetUrl = url;
      todolistitems = data;
      isLoading = false;
    });
  }

  void showGoogleSheetDialog() {
    final controller = TextEditingController(text: currentSheetUrl ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.table_chart, color: Colors.green),
            SizedBox(width: 8),
            Text('เชื่อมต่อ Google Sheet'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'วางลิงก์ Web App URL ที่ได้จาก Google Apps Script:',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Web App URL',
                  hintText: 'https://script.google.com/macros/s/.../exec',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 8),
              Text(
                'ไฟล์โค้ดสคริปต์ถูกสร้างไว้ที่โฟลเดอร์ดาวน์โหลดแล้ว:\ngoogle_sheet_script.js',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: [
          if (currentSheetUrl != null)
            TextButton(
              onPressed: () async {
                await TodoService.setSheetUrl(null);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('ยกเลิกการเชื่อมต่อ กลับมาใช้ในเครื่องแล้ว')),
                );
                loadTodos();
              },
              child: Text('ใช้ในเครื่อง (ตัดการเชื่อมต่อ)', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ปิด'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                await TodoService.setSheetUrl(text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('บันทึกและเชื่อมต่อ Google Sheet เรียบร้อยแล้ว'),
                    backgroundColor: Colors.green,
                  ),
                );
                loadTodos();
              }
            },
            child: Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(currentSheetUrl != null ? 'Todolist (Google Sheet)' : 'Todolist (ในเครื่อง)'),
        actions: [
          IconButton(
            tooltip: 'เชื่อมต่อ Google Sheet',
            icon: Icon(
              Icons.table_chart,
              color: currentSheetUrl != null ? Colors.greenAccent : Colors.white,
            ),
            onPressed: showGoogleSheetDialog,
          ),
          IconButton(
            tooltip: 'รีเฟรชรายการ',
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: loadTodos,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddPage()),
          ).then((value) {
            if (value == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('เพิ่มรายการใหม่เรียบร้อยแล้ว'),
                  backgroundColor: Colors.green,
                ),
              );
              loadTodos();
            }
          });
        },
        icon: Icon(Icons.add),
        label: Text('เพิ่มรายการ'),
      ),
      body: buildBody(),
    );
  }

  Widget buildBody() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('กำลังโหลดรายการ...', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
          ],
        ),
      );
    }

    if (todolistitems.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadTodos,
        child: ListView(
          physics: AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 120),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt, size: 80, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'ยังไม่มีรายการที่ต้องทำ',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'กดปุ่ม "เพิ่มรายการ" ด้านล่างเพื่อเริ่มบันทึกรายการ',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadTodos,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: todolistitems.length,
        itemBuilder: (context, index) {
          final item = todolistitems[index];
          final title = item['title'] ?? 'ไม่มีหัวข้อ';
          final detail = item['detail'] ?? '';

          return Card(
            elevation: 2,
            margin: EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Text(
                  '${index + 1}',
                  style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              subtitle: detail.toString().trim().isNotEmpty
                  ? Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600]))
                  : null,
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UpdatePage(
                      item['id'],
                      title,
                      detail,
                    ),
                  ),
                ).then((value) {
                  if (value == 'delete') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('ลบรายการสำเร็จแล้ว'), backgroundColor: Colors.redAccent),
                    );
                    loadTodos();
                  } else if (value == 'update') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('แก้ไขรายการสำเร็จแล้ว'), backgroundColor: Colors.green),
                    );
                    loadTodos();
                  }
                });
              },
            ),
          );
        },
      ),
    );
  }
}
