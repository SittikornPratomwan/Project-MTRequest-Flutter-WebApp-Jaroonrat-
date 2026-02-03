import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Purchase Request Form',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F5DC), // สีครีมตามภาพ
        fontFamily:
            'Sans-serif', // ควรใช้ฟอนต์ Sarabun หรือ Kanit ในโปรเจกต์จริง
      ),
      home: const RequestFormPage(),
    );
  }
}

class RequestFormPage extends StatefulWidget {
  const RequestFormPage({super.key});

  @override
  State<RequestFormPage> createState() => _RequestFormPageState();
}

class _RequestFormPageState extends State<RequestFormPage> {
  // ตัวแปร State สำหรับเก็บค่าที่เลือก
  String? _priority = 'ด่วน';
  late DateTime _requestDate;
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];
  bool _isSubmitting = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _requestDate = DateTime.now();
  }

  // ฟังก์ชันแปลงวันที่เป็นรูปแบบไทย (dd/mm/yyyy)
  String _formatThaiDate(DateTime date) {
    final months = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = (date.year + 543).toString(); // Convert to Buddhist Era
    return '$day / $month / $year';
  }

  // ฟังก์ชันแปลง priority ให้เป็นค่าที่ API ต้องการ
  String _mapPriority(String? priority) {
    switch (priority) {
      case 'ด่วน':
        return 'urgent';
      case 'ปกติ':
        return 'normal';
      case 'โครงการ':
        return 'project';
      default:
        return 'normal';
    }
  }

  // ฟังก์ชันแปลงวันที่เป็นรูปแบบ yyyy-mm-dd
  String _formatDateForApi(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  // ฟังก์ชันส่งข้อมูลไป API
  Future<void> _submitRequest() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกหัวข้อ')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // สร้าง payload
      final payload = {
        'title': _titleController.text,
        'priority': _mapPriority(_priority),
        'description': _descriptionController.text,
        'requester_id': 1,
        'dp_id': 1,
        'l_id': 1,
        'status_code': 'in_approval',
        'current_status': 'new',
        'current_step_order': 1,
        'required_date': _formatDateForApi(_requestDate),
      };

      print('Sending request to API...');
      print('Payload: ${jsonEncode(payload)}');

      final response = await http
          .post(
            Uri.parse('http://26.99.205.41:9000/drugs/repair-requests'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ส่งใบแจ้งซ่อมเรียบร้อย'),
            backgroundColor: Colors.green,
          ),
        );
        // Clear form
        _titleController.clear();
        _descriptionController.clear();
        _images.clear();
        setState(() {
          _priority = 'ด่วน';
        });
        // Navigate back to home page after 1.5 seconds to show the SnackBar
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Request'),
        backgroundColor: Colors.grey[400],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------------------------------------
            // Priority Section (เก็บลง API)
            // ------------------------------------------------
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 100,
                  child: Text(
                    'Priority :',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRadioRow(
                        'ด่วน',
                        'กรณีที่ต้องทำให้เสร็จภายใน 3 วัน',
                        Colors.red,
                      ),
                      _buildRadioRow(
                        'ปกติ',
                        'กรณีที่ต้องทำให้เสร็จภายใน 7 วัน',
                        Colors.red,
                      ),
                      _buildRadioRow(
                        'โครงการ',
                        'กรณีที่ต้องใช้ระยะเวลา... ให้กำหนดวันที่ต้องการให้เหมาะสม',
                        Colors.red,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ------------------------------------------------
            // Request Date
            // ------------------------------------------------
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(
                  width: 100,
                  child: Text(
                    'Request :',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  _formatThaiDate(_requestDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  '(วันที่ร้องขอ)',
                  style: TextStyle(color: Colors.blue),
                ),
              ],
            ),

            // ------------------------------------------------
            // Topic and Description
            // ------------------------------------------------
            const SizedBox(height: 10),
            _buildTextFieldRow(label: 'หัวข้อ :', controller: _titleController),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey),
              ),
              child: Column(
                children: [
                  // Text Area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _descriptionController,
                        maxLines: null,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'รายละเอียด',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Text(
              'แนบรูป / ไฟล์ (สูงสุด 5)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(5, (index) {
                final hasImage = index < _images.length;
                return GestureDetector(
                  onTap: () async {
                    if (!hasImage && _images.length < 5) {
                      final XFile? picked = await _picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (picked != null) setState(() => _images.add(picked));
                    }
                  },
                  onLongPress: hasImage
                      ? () => setState(() => _images.removeAt(index))
                      : null,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      color: Colors.white,
                    ),
                    child: hasImage
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                File(_images[index].path),
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _images.removeAt(index)),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const Center(
                            child: Icon(Icons.add_a_photo, color: Colors.grey),
                          ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'ส่งใบแจ้งซ่อม',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  // สร้าง Radio Row สำหรับ Priority (มีข้อความแดงต่อท้าย)
  Widget _buildRadioRow(String value, String note, Color noteColor) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Radio<String>(
            value: value,
            groupValue: _priority,
            onChanged: (v) => setState(() => _priority = v),
          ),
        ),
        const SizedBox(width: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.normal)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            note,
            style: TextStyle(color: noteColor, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Note: simple location radio removed (not saved to API)

  // สร้าง Row แบบ Label : Input Field
  Widget _buildTextFieldRow({
    required String label,
    String? initialValue,
    TextEditingController? controller,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 35,
            child: TextFormField(
              initialValue: initialValue,
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
                fillColor: Colors.white,
                filled: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
