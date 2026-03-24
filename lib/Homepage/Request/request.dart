import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../Authen/authen.dart';
import '../../Service/mt_request_api.dart';

/// Form page used to create a new repair request and upload supporting images.
class RequestFormPage extends StatefulWidget {
  const RequestFormPage({super.key});

  @override
  State<RequestFormPage> createState() => _RequestFormPageState();
}

class _RequestFormPageState extends State<RequestFormPage> {
  String? _priority = 'ด่วน';
  late DateTime _requestDate;
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];
  final Map<int, Uint8List> _imageBytes = {};
  bool _isSubmitting = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  int? _categoryId;
  int? _characteristicId;

  final Map<int, String> _categoryOptions = {
    1: 'ไฟฟ้า',
    2: 'ประปา',
    3: 'โครงสร้าง',
    6: 'แอร์',
    7: 'อินเตอร์เน็ต',
    8: 'รถยนต์',
    9: 'โฟลคลิฟท์',
    10: 'หอพัก',
    11: 'เครื่องจักร',
  };

  final Map<int, String> _characteristicOptions = {
    1: 'สร้าง',
    2: 'สั่งทำ',
    3: 'ซ่อม',
  };

  @override
  void initState() {
    super.initState();
    _requestDate = DateTime.now();
  }

  /// Format the chosen date for the Thai display in the form.
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
    final year = (date.year + 543).toString();
    return '$day / $month / $year';
  }

  /// Convert the UI priority label into the API enum value.
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

  /// Convert the selected date into the API format.
  String _formatDateForApi(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Submit the new request and upload attachments when the API returns an id.
  Future<void> _submitRequest() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกหัวข้อ')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final Map<String, dynamic> payload = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'priority': _mapPriority(_priority),
        'required_date': _formatDateForApi(_requestDate),
        'status_code': 'in_approval',
        'current_status': 'new',
        'current_step_order': 1,
      };

      if (Authen.requesterId != null) {
        payload['requester_id'] = Authen.requesterId;
      } else {
        payload['name'] = Authen.userName ?? '';
      }

      // Keep the department to id mapping close to submission because it is part
      // of the payload contract with the backend.
      final Map<String, int> deptMap = {
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
        if (divKey.isNotEmpty && deptMap.containsKey(divKey)) {
          payload['dp_id'] = deptMap[divKey];
        } else if (divRaw.isNotEmpty) {
          payload['division'] = divRaw;
        }
      }

      if (Authen.lId != null) {
        payload['l_id'] = Authen.lId;
      } else {
        payload['l_id'] = 1;
      }

      if (Authen.userName != null && Authen.userName!.isNotEmpty) {
        payload['username'] = Authen.userName;
      } else if (Authen.loginUsername != null &&
          Authen.loginUsername!.isNotEmpty) {
        payload['username'] = Authen.loginUsername;
      }

      if (Authen.departmentName != null && Authen.departmentName!.isNotEmpty) {
        payload['department_name'] = Authen.departmentName;
      } else if (Authen.division != null && Authen.division!.isNotEmpty) {
        payload['department_name'] = Authen.division;
      }

      if (_categoryId != null) payload['category_id'] = _categoryId;
      if (_characteristicId != null)
        payload['characteristic_id'] = _characteristicId;

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
            MtRequestApi.uri('/repair-requests'),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(MtRequestApi.requestTimeout);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        String? createdId;
        try {
          final respJson = jsonDecode(response.body);
          if (respJson is Map) {
            createdId =
                respJson['id']?.toString() ??
                respJson['repair_request_id']?.toString() ??
                respJson['job_no']?.toString();
            createdId ??= respJson['data'] is Map
                ? respJson['data']['id']?.toString()
                : null;
          }
        } catch (e) {
          print('Failed to decode creation response: $e');
        }

        if (createdId != null && _images.isNotEmpty) {
          for (var i = 0; i < _images.length; i++) {
            final file = _images[i];
            try {
              final uri = MtRequestApi.uri('/repair-requests/$createdId/files');
              final req = http.MultipartRequest('POST', uri);

              if (Authen.token != null && Authen.token!.isNotEmpty) {
                req.headers['Authorization'] = 'Bearer ${Authen.token}';
                print('Including Authorization header for file upload');
              }

              req.fields['repairRequestId'] = createdId;
              req.fields['repair_request_id'] = createdId;

              final bytes = await file.readAsBytes();
              final origName = file.name;

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

              String safeName = origName.replaceAll(
                RegExp(r'[^A-Za-z0-9_.-]'),
                '_',
              );

              if (!safeName.contains('.')) {
                final ext = mimeType.split('/').last;
                safeName = '$safeName.$ext';
              }

              final uploadName =
                  '${DateTime.now().millisecondsSinceEpoch}_$safeName';

              req.files.add(
                http.MultipartFile.fromBytes(
                  'files',
                  bytes,
                  filename: uploadName,
                  contentType: MediaType.parse(mimeType),
                ),
              );

              print('Uploading file: $uploadName to $uri');
              print('Original filename: $origName -> upload as: $uploadName');
              print('Content-Type: $mimeType, Size: ${bytes.length} bytes');

              final streamed = await req.send().timeout(
                MtRequestApi.uploadTimeout,
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

        _titleController.clear();
        _descriptionController.clear();
        _images.clear();
        _imageBytes.clear();
        setState(() {
          _priority = 'ด่วน';
        });

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
            const SizedBox(height: 10),
            // Move Category & Characteristic selectors above the topic/title
            Row(
              children: [
                const SizedBox(
                  width: 100,
                  child: Text(
                    'หมวดหมู่ :',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _categoryId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    items: _categoryOptions.entries
                        .map(
                          (e) => DropdownMenuItem<int>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                    hint: const Text('เลือกหมวดหมู่'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(
                  width: 100,
                  child: Text(
                    'ลักษณะ :',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _characteristicId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    items: _characteristicOptions.entries
                        .map(
                          (e) => DropdownMenuItem<int>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _characteristicId = v),
                    hint: const Text('เลือกลักษณะ'),
                  ),
                ),
              ],
            ),
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
  } // Note: simple location radio removed (not saved to API)

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
