import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../Authen/authen.dart';

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
        primaryColor: const Color(0xFF1976D2),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        fontFamily: 'Sans-serif',
        textTheme: TextTheme(
          headlineSmall: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A202C),
          ),
          labelLarge: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2D3748),
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF4A5568),
          ),
        ),
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
  final Map<int, Uint8List> _imageBytes = {}; // เก็บ bytes สำหรับแสดงบน Web
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
      // สร้าง payload (เรียงลำดับและไม่ส่งค่า null สำหรับ id)
      final Map<String, dynamic> payload = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'priority': _mapPriority(_priority),
        'required_date': _formatDateForApi(_requestDate),
        // workflow / status
        'status_code': 'in_approval',
        'current_status': 'new',
        'current_step_order': 1,
        // location / extra (l_id will be set from Authen if available)
      };

      // Prefer numeric IDs when available; otherwise include name/division
      if (Authen.requesterId != null) {
        payload['requester_id'] = Authen.requesterId;
      } else {
        payload['name'] = Authen.userName ?? '';
      }
      //
      //----------------------------------------------------------------------------------------------------------------
      //  แปลงเลข department เป็น dp_id ให้ backend แทนการส่งชื่อ division แบบเดิม เพื่อความแม่นยำในการจัดหมวดหมู่และรายงานผล
      //------------------------------------------------------------------------------------------------------------------------------
      //
      // Map department names to numeric dp_id when possible
      final Map<String, int> _deptMap = {
        'MT': 1,
        'HR': 2,
        'L5': 3,
        'DL': 4,
        'IMD': 9,
        'L4': 12,
        'ACC': 14,
        'QA': 15,
        'QC': 16,
      };

      if (Authen.dpId != null) {
        payload['dp_id'] = Authen.dpId;
      } else {
        final divRaw = (Authen.division ?? '').toString().trim();
        final divKey = divRaw.toUpperCase();
        if (divKey.isNotEmpty && _deptMap.containsKey(divKey)) {
          payload['dp_id'] = _deptMap[divKey];
        } else if (divRaw.isNotEmpty) {
          // If no mapping, keep the human-readable division for backend fallback
          payload['division'] = divRaw;
        }
      }

      // Include l_id from login if available, otherwise keep default 1
      if (Authen.lId != null) {
        payload['l_id'] = Authen.lId;
      } else {
        payload['l_id'] = 1;
      }

      // Include username (prefer full name from login, fallback to login username)
      if (Authen.userName != null && Authen.userName!.isNotEmpty) {
        payload['username'] = Authen.userName;
      } else if (Authen.loginUsername != null &&
          Authen.loginUsername!.isNotEmpty) {
        payload['username'] = Authen.loginUsername;
      }

      // Include department_name from login if available
      if (Authen.departmentName != null && Authen.departmentName!.isNotEmpty) {
        payload['department_name'] = Authen.departmentName;
      } else if (Authen.division != null && Authen.division!.isNotEmpty) {
        payload['department_name'] = Authen.division;
      }

      // Log payload with one key:value per line for readability
      final payloadLines = payload.entries
          .map((e) {
            final k = e.key;
            final v = e.value;
            String vs;
            if (v == null) {
              vs = 'null';
            } else if (v is String || v is num || v is bool) {
              vs = v.toString();
            } else {
              vs = jsonEncode(v);
            }
            return '$k: $vs';
          })
          .join('\n');

      print('Sending request to API...');
      print('Payload:\n$payloadLines');

      final headers = {'Content-Type': 'application/json'};
      if (Authen.token != null && Authen.token!.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${Authen.token}';
        print('Including Authorization header for create request');
      }

      final response = await http
          .post(
            Uri.parse('http://26.99.205.41:9000/drugs/repair-requests'),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Try to parse returned id for uploading files
        String? createdId;
        try {
          final respJson = jsonDecode(response.body);
          if (respJson is Map) {
            createdId =
                respJson['id']?.toString() ??
                respJson['repair_request_id']?.toString() ??
                respJson['job_no']?.toString();
            // nested under data?
            createdId ??= respJson['data'] is Map
                ? respJson['data']['id']?.toString()
                : null;
          }
        } catch (e) {
          print('Failed to decode creation response: $e');
        }

        // If we have files and we got an id, upload each file
        if (createdId != null && _images.isNotEmpty) {
          for (var i = 0; i < _images.length; i++) {
            final file = _images[i];
            try {
              final uri = Uri.parse(
                'http://26.99.205.41:9000/drugs/repair-requests/$createdId/files',
              );
              final req = http.MultipartRequest('POST', uri);

              // Attach token to multipart upload if available
              if (Authen.token != null && Authen.token!.isNotEmpty) {
                req.headers['Authorization'] = 'Bearer ${Authen.token}';
                print('Including Authorization header for file upload');
              }

              // Include the created repair request id so the server can associate files
              // with the newly created request. Add both camelCase and snake_case
              // variants in case the backend expects one of them.
              req.fields['repairRequestId'] = createdId;
              req.fields['repair_request_id'] = createdId;

              // ใช้ bytes สำหรับ Web (fromPath ใช้ไม่ได้บน Web)
              final bytes = await file.readAsBytes();

              // เริ่มจากเดิมชื่อไฟล์จาก client (อาจเป็นชื่อที่ browser/OS ให้มา)
              final origName = file.name ?? 'image';

              // ระบุ content-type ของไฟล์ โดยดูจากนามสกุลถ้ามี
              String mimeType = 'image/jpeg';
              final lower = origName.toLowerCase();
              if (lower.endsWith('.png')) {
                mimeType = 'image/png';
              } else if (lower.endsWith('.gif')) {
                mimeType = 'image/gif';
              } else if (lower.endsWith('.webp')) {
                mimeType = 'image/webp';
              } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
                mimeType = 'image/jpeg';
              }

              // sanitize ชื่อไฟล์: เอาเฉพาะตัวอักษร ภาษาอังกฤษ ตัวเลข จุด ขีด และ underscore
              String safeName = origName.replaceAll(
                RegExp(r'[^A-Za-z0-9_.-]'),
                '_',
              );

              // ถ้าไม่มีนามสกุล ให้เติมจาก mimeType
              if (!safeName.contains('.')) {
                final ext = mimeType.split('/').last;
                safeName = '$safeName.$ext';
              }

              // เพิ่ม timestamp เพื่อป้องกันการชนของชื่อไฟล์บน server
              final uploadName =
                  '${DateTime.now().millisecondsSinceEpoch}_$safeName';

              req.files.add(
                http.MultipartFile.fromBytes(
                  'files', // ลองใช้ 'files' แทน 'file'
                  bytes,
                  filename: uploadName,
                  contentType: MediaType.parse(mimeType),
                ),
              );

              print('Uploading file: $uploadName to $uri');
              print('Original filename: $origName -> upload as: $uploadName');
              print('Content-Type: $mimeType, Size: ${bytes.length} bytes');

              final streamed = await req.send().timeout(
                const Duration(seconds: 20),
              );
              final respStr = await streamed.stream.bytesToString();
              print(
                'Upload file response status: ${streamed.statusCode} body: $respStr',
              );
              if (streamed.statusCode != 200 && streamed.statusCode != 201) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'อัปโหลดรูปไม่สำเร็จ (status ${streamed.statusCode})',
                    ),
                  ),
                );
              }
            } catch (e) {
              print('Error uploading file: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('เกิดข้อผิดพลาดขณะอัปโหลดรูป: $e')),
              );
            }
          }
        }

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
        _imageBytes.clear();
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
        title: const Text(
          'New Request',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                      fontSize: 14,
                    ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  _formatThaiDate(_requestDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  '(วันที่ร้องขอ)',
                  style: TextStyle(
                    color: Color(0xFF1976D2),
                    fontWeight: FontWeight.w500,
                  ),
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
                      if (picked != null) {
                        // อ่าน bytes สำหรับแสดงผลบน Web
                        final bytes = await picked.readAsBytes();
                        setState(() {
                          _images.add(picked);
                          _imageBytes[_images.length - 1] = bytes;
                        });
                      }
                    }
                  },
                  onLongPress: hasImage
                      ? () => setState(() {
                          _imageBytes.remove(index);
                          _images.removeAt(index);
                          // Re-index bytes
                          final newBytes = <int, Uint8List>{};
                          for (var i = 0; i < _images.length; i++) {
                            if (_imageBytes.containsKey(
                              i > index ? i + 1 : i,
                            )) {
                              newBytes[i] = _imageBytes[i > index ? i + 1 : i]!;
                            }
                          }
                          _imageBytes.clear();
                          _imageBytes.addAll(newBytes);
                        })
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
                              _imageBytes.containsKey(index)
                                  ? Image.memory(
                                      _imageBytes[index]!,
                                      fit: BoxFit.cover,
                                    )
                                  : const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _imageBytes.remove(index);
                                    _images.removeAt(index);
                                    // Re-index bytes
                                    final newBytes = <int, Uint8List>{};
                                    for (var i = 0; i < _images.length; i++) {
                                      if (_imageBytes.containsKey(
                                        i >= index ? i + 1 : i,
                                      )) {
                                        newBytes[i] =
                                            _imageBytes[i >= index
                                                ? i + 1
                                                : i]!;
                                      }
                                    }
                                    _imageBytes.clear();
                                    _imageBytes.addAll(newBytes);
                                  }),
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
            activeColor: const Color(0xFF1976D2),
            onChanged: (v) => setState(() => _priority = v),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            note,
            style: TextStyle(
              color: noteColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
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
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 36,
            child: TextFormField(
              initialValue: initialValue,
              controller: controller,
              style: const TextStyle(color: Color(0xFF2D3748), fontSize: 14),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(
                    color: Color(0xFF1976D2),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
