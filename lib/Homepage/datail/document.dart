import 'package:flutter/material.dart';

class DocumentPage extends StatelessWidget {
  const DocumentPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เอกสาร'),
        backgroundColor: const Color(0xFF1976D2),
      ),
      body: const Center(
        child: Text('หน้านี้สำหรับแสดงเอกสาร', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}
