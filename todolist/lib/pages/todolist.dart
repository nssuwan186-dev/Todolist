import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:todolist/config.dart';
import 'package:todolist/pages/add.dart';
import 'package:todolist/pages/update_todolist.dart';

class Todolist extends StatefulWidget {
  @override
  _TodolistState createState() => _TodolistState();
}

class _TodolistState extends State<Todolist> {
  List todolistitems = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    getTodolist();
  }

  Future<void> getTodolist() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      var url = AppConfig.getUri('/api/all-todolist/');
      var response = await http.get(url).timeout(Duration(seconds: 7));

      if (response.statusCode == 200) {
        var result = utf8.decode(response.bodyBytes);
        setState(() {
          todolistitems = jsonDecode(result);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'เซิร์ฟเวอร์ตอบกลับด้วยรหัส: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ (${AppConfig.serverHost})\nกรุณาตรวจสอบว่าเซิร์ฟเวอร์เปิดอยู่หรือกดแก้ไข IP';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('รายการที่ต้องทำทั้งหมด'),
        actions: [
          IconButton(
            tooltip: 'ตั้งค่า Server IP',
            icon: Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              AppConfig.showServerSettingsDialog(context, () {
                getTodolist();
              });
            },
          ),
          IconButton(
            tooltip: 'รีเฟรชรายการ',
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              getTodolist();
            },
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
                  content: Text('เพิ่มรายการใหม่สำเร็จแล้ว'),
                  backgroundColor: Colors.green,
                ),
              );
              getTodolist();
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

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 64, color: Colors.red[300]),
              SizedBox(height: 16),
              Text(
                'เกิดข้อผิดพลาดในการเชื่อมต่อ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      AppConfig.showServerSettingsDialog(context, () {
                        getTodolist();
                      });
                    },
                    icon: Icon(Icons.settings),
                    label: Text('ตั้งค่า IP'),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: getTodolist,
                    icon: Icon(Icons.refresh),
                    label: Text('ลองใหม่อีกครั้ง'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (todolistitems.isEmpty) {
      return RefreshIndicator(
        onRefresh: getTodolist,
        child: ListView(
          physics: AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 120),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checklist_rtl, size: 80, color: Colors.grey[400]),
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
      onRefresh: getTodolist,
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
                    getTodolist();
                  } else if (value == 'update') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('แก้ไขรายการสำเร็จแล้ว'), backgroundColor: Colors.green),
                    );
                    getTodolist();
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
