import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'remark.dart';

// Data Model for detail page
class PurchaseItem {
  final String id;
  final String no;
  final String type;
  final String topic;
  final String reqDate;
  final String prDate;
  final String reqBy;
  final String dept;
  final String status;
  final String approver;
  final String createdAt;
  final bool isHighlight;
  final Map<String, dynamic>? rawData;

  PurchaseItem({
    required this.id,
    required this.no,
    required this.type,
    required this.topic,
    required this.reqDate,
    required this.prDate,
    required this.reqBy,
    required this.dept,
    required this.status,
    required this.approver,
    this.createdAt = '',
    this.isHighlight = false,
    this.rawData,
  });
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MT request Detail',
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
      home: const PurchaseDetailPage(),
    );
  }
}

class PurchaseDetailPage extends StatefulWidget {
  final PurchaseItem? item;

  const PurchaseDetailPage({super.key, this.item});

  @override
  State<PurchaseDetailPage> createState() => _PurchaseDetailPageState();
}

class _PurchaseDetailPageState extends State<PurchaseDetailPage> {
  final String _baseHost = 'http://26.99.205.41:9000';
  List<String> _fileUrls = [];
  bool _loadingFiles = false;
  String? _currentFetchId;
  String? _currentFetchUri;

  List<dynamic> _comments = [];
  bool _loadingComments = false;

  @override
  void initState() {
    super.initState();
    _loadFilesForItem();
    _loadCommentsForItem();
  }

  Future<void> _loadFilesForItem() async {
    String? id;

    // Use the ID directly from the item passed during navigation
    if (widget.item != null && widget.item!.id.isNotEmpty) {
      id = widget.item!.id;
      debugPrint('Using item.id from navigation: $id');
    }

    // Fallback to rawData if id is empty
    if (id == null || id.isEmpty) {
      final raw = widget.item?.rawData;
      if (raw != null) {
        id = raw['id']?.toString() ?? raw['repair_request_id']?.toString();
        debugPrint('Using rawData id: $id');
      }
    }

    if (id == null || id.isEmpty) {
      debugPrint('ERROR: No ID provided for fetching files!');
      return;
    }

    debugPrint(
      'Fetching files for id: $id from URL: $_baseHost/drugs/repair-requests/$id/files',
    );
    await _fetchFilesForId(id);
  }

  Future<void> _loadCommentsForItem() async {
    String? id;

    // Use the ID directly from the item passed during navigation
    if (widget.item != null && widget.item!.id.isNotEmpty) {
      id = widget.item!.id;
      debugPrint('Using item.id from navigation (comments): $id');
    }

    // Fallback to rawData if id is empty
    if (id == null || id.isEmpty) {
      final raw = widget.item?.rawData;
      if (raw != null) {
        id = raw['id']?.toString() ?? raw['repair_request_id']?.toString();
        debugPrint('Using rawData id (comments): $id');
      }
    }

    if (id == null || id.isEmpty) {
      debugPrint('ERROR: No ID provided for fetching comments!');
      return;
    }

    debugPrint(
      'Fetching comments for id: $id from URL: $_baseHost/drugs/repair-requests/$id/comments',
    );
    await _fetchCommentsForId(id);
  }

  Future<String?> _resolveIdFromList() async {
    try {
      final uri = Uri.parse('$_baseHost/drugs/repair-requests');
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(resp.body);
      List<dynamic>? list;
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map && decoded['data'] is List) {
        list = decoded['data'];
      }
      if (list == null || list.isEmpty) return null;

      final targetNo = widget.item?.no;
      final targetTopic = widget.item?.topic;

      for (final entry in list) {
        if (entry is! Map) continue;
        final entryId = entry['id']?.toString();
        if (entryId == null) continue;

        // Match by no
        if (targetNo != null && targetNo != 'N/A') {
          final candidates = [entry['no'], entry['pr_no'], entry['job_no']];
          for (final c in candidates) {
            if (c != null && c.toString() == targetNo) return entryId;
          }
        }
        // Match by topic
        if (targetTopic != null && targetTopic != 'N/A') {
          final t = entry['topic'] ?? entry['title'] ?? entry['description'];
          if (t != null && t.toString() == targetTopic) return entryId;
        }
      }
      // Fallback: first item
      final first = list.first;
      if (first is Map && first['id'] != null) return first['id'].toString();
    } catch (e) {}
    return null;
  }

  Future<void> _fetchFilesForId(String id) async {
    final uri = Uri.parse('$_baseHost/drugs/repair-requests/$id/files');
    setState(() {
      _loadingFiles = true;
      _currentFetchId = id;
      _currentFetchUri = uri.toString();
    });
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final List<String> urls = [];

        List<dynamic>? list;
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map) {
          // Try common API response keys
          if (decoded['value'] is List) {
            list = decoded['value'];
          } else if (decoded['data'] is List) {
            list = decoded['data'];
          } else if (decoded['files'] is List) {
            list = decoded['files'];
          }
        }

        if (list != null) {
          for (final item in list) {
            if (item is String) {
              final normalized = _normalizeUrl(item);
              urls.add(normalized);
            } else if (item is Map) {
              bool foundUrl = false;
              final candidates = [
                'file_url',
                'url',
                'path',
                'file',
                'filename',
                'location',
                'src',
              ];
              for (final k in candidates) {
                if (item[k] != null) {
                  final normalized = _normalizeUrl(item[k].toString());
                  urls.add(normalized);
                  foundUrl = true;
                  break;
                }
              }
              // fallback: search recursively for any string that looks like an image path
              if (!foundUrl) {
                final found = _findImageString(item);
                if (found != null) {
                  final normalized = _normalizeUrl(found);
                  urls.add(normalized);
                }
              }
            }
          }
        }
        if (mounted) setState(() => _fileUrls = urls);
      }
    } catch (e) {
    } finally {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  Future<void> _fetchCommentsForId(String id) async {
    final uri = Uri.parse('$_baseHost/drugs/repair-requests/$id/comments');
    setState(() {
      _loadingComments = true;
    });
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      debugPrint('Comments API response status: ${resp.statusCode}');
      debugPrint('Comments API response body: ${resp.body}');

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        List<dynamic> commentList = [];

        // Handle different response formats
        if (decoded is List) {
          commentList = decoded;
        } else if (decoded is Map) {
          if (decoded['comments'] is List) {
            commentList = decoded['comments'];
          } else if (decoded['data'] is List) {
            commentList = decoded['data'];
          } else if (decoded['value'] is List) {
            commentList = decoded['value'];
          }
        }

        if (mounted) {
          setState(() {
            _comments = commentList;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching comments: $e');
    } finally {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  String _normalizeUrl(String raw) {
    if (raw.startsWith('http')) return raw;
    if (raw.startsWith('/')) return '$_baseHost$raw';
    return '$_baseHost/$raw';
  }

  // Recursively search a Map/List for a string that looks like an image/file path
  String? _findImageString(dynamic node) {
    if (node == null) return null;
    final exts = ['.png', '.jpg', '.jpeg', '.gif', '.webp'];
    if (node is String) {
      final low = node.toLowerCase();
      for (final e in exts) {
        if (low.contains(e)) return node;
      }
      // also consider full URLs without extension (rare)
      if (low.startsWith('http')) return node;
      return null;
    }
    if (node is Map) {
      for (final v in node.values) {
        final found = _findImageString(v);
        if (found != null) return found;
      }
      return null;
    }
    if (node is List) {
      for (final v in node) {
        final found = _findImageString(v);
        if (found != null) return found;
      }
      return null;
    }
    return null;
  }

  String _formatCreatedAt(String raw) {
    try {
      final dt = DateTime.parse(raw);
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/$y $hh:$mm';
    } catch (_) {
      // Fallback: try extracting and reformatting common date patterns
      String part = raw;
      if (raw.contains(' ')) part = raw.split(' ').first;
      if (part.contains('-')) {
        final seg = part.split('-');
        if (seg.length >= 3) {
          if (seg[0].length == 4) {
            return '${seg[2].padLeft(2, '0')}/${seg[1].padLeft(2, '0')}/${seg[0]}';
          } else {
            return '${seg[0].padLeft(2, '0')}/${seg[1].padLeft(2, '0')}/${seg[2]}';
          }
        }
      }
      if (part.contains('/')) {
        final seg = part.split('/');
        if (seg.length >= 3) {
          if (seg[0].length == 4) {
            return '${seg[2].padLeft(2, '0')}/${seg[1].padLeft(2, '0')}/${seg[0]}';
          } else {
            return '${seg[0].padLeft(2, '0')}/${seg[1].padLeft(2, '0')}/${seg[2]}';
          }
        }
      }
      return raw;
    }
  }

  void _showRemarkDialog(BuildContext context) {
    final TextEditingController remarkController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Remark'),
          content: TextField(
            controller: remarkController,
            decoration: const InputDecoration(
              hintText: 'Enter your remark...',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final remark = remarkController.text.trim();
                if (remark.isNotEmpty) {
                  // TODO: Save remark to API or local storage
                  print('Remark saved: $remark');
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Remark saved')));
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color labelColor = const Color(0xFF1976D2);
    final Color valueColor = const Color(0xFF2D3748);

    // Use passed data or default data
    final displayItem =
        widget.item ??
        PurchaseItem(
          id: '',
          no: 'N/A',
          type: 'N/A',
          topic: 'ขออนุมัติซ่อมมอเตอร์ปั๊มน้ำหอพัก',
          reqDate: 'N/A',
          prDate: 'N/A',
          reqBy: 'N/A',
          dept: 'N/A',
          status: 'N/A',
          approver: 'N/A',
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MT request Detail',
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Show remark dialog without dimming background
          final result = await showRemarkDialog(
            context,
            repairRequestId: displayItem.id,
          );
          if (result != null && mounted) {
            final remark = result['remark'] as String? ?? '';
            final images = result['images'] as List<Uint8List>? ?? [];
            if (remark.isNotEmpty || images.isNotEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Remark saved')));
              // TODO: send remark/images to API if needed
            }
          }
        },
        backgroundColor: const Color(0xFF48BB78),
        foregroundColor: Colors.white,
        child: const Icon(Icons.note_add, color: Colors.white),
        tooltip: 'Add Remark',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------------------------------------------------------
            // 1. Header Section (ข้อมูลผู้ขอ + รายละเอียด Form)
            // -------------------------------------------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label: แจ้งซ่อมโดย
                SizedBox(
                  width: 100,
                  child: Text(
                    'แจ้งซ่อมโดย :',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                // Profile Image & Name
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 100,
                      color: Colors.grey[300],
                      // ใส่รูปจริงตรงนี้: Image.network(...)
                      child: const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      displayItem.reqBy,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: valueColor,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      displayItem.dept,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: valueColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ใช้ Table เพื่อจัดระเบียบข้อมูล key-value
            Table(
              columnWidths: const {
                0: FixedColumnWidth(140), // ความกว้างของ Label
                1: FlexColumnWidth(), // ความกว้างของ Value
              },
              children: [
                _buildTableRow(
                  'หัวข้อการซ่อม :',
                  displayItem.topic,
                  labelColor,
                  valueColor,
                ),
                if (displayItem.approver.isNotEmpty)
                  _buildTableRow(
                    'เรียน/สำเนาถึง :',
                    displayItem.approver,
                    labelColor,
                    valueColor,
                  ),
                _buildTableRow(
                  'ความสำคัญ :',
                  displayItem.type,
                  labelColor,
                  valueColor,
                ),
                if (displayItem.no.isNotEmpty)
                  _buildTableRow(
                    'MT No :',
                    displayItem.no,
                    labelColor,
                    valueColor,
                  ),
                if (displayItem.reqDate.isNotEmpty &&
                    displayItem.reqDate != 'N/A')
                  _buildTableRow(
                    'วันที่ต้องการ :',
                    displayItem.reqDate,
                    labelColor,
                    valueColor,
                  ),
                if (displayItem.createdAt.isNotEmpty &&
                    displayItem.createdAt != 'N/A')
                  _buildTableRow(
                    'สร้างเมื่อวันที่ :',
                    _formatCreatedAt(displayItem.createdAt),
                    labelColor,
                    valueColor,
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // -------------------------------------------------------
            // 2. Detail Section (กรอบรายละเอียด)
            // -------------------------------------------------------
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue[700]!, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      border: const Border(
                        bottom: BorderSide(color: Colors.blue, width: 1),
                      ),
                      color: Colors.white,
                    ),
                    child: Text(
                      'รายละเอียด',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: labelColor,
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      displayItem.topic,
                      style: TextStyle(color: valueColor, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // -------------------------------------------------------
            // Attached Files Section (รูปภาพแนบ)
            // (interactive debug UI removed)
            // -------------------------------------------------------
            if (_loadingFiles)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_loadingFiles && _fileUrls.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ไฟล์แนบ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Show each attached file at its natural/intrinsic size (full width within page)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _fileUrls.map<Widget>((url) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: GestureDetector(
                          onTap: () => _showFullImage(context, url),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 240),
                            child: Image.network(
                              url,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const SizedBox(
                                  height: 240,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                              errorBuilder: (c, e, s) => const SizedBox(
                                height: 240,
                                child: Center(
                                  child: Icon(Icons.broken_image, size: 48),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            if (!_loadingFiles && _fileUrls.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'ไม่มีไฟล์แนบ',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),

            // (ความเห็น ย้ายไว้ด้านล่างสุด)

            // -------------------------------------------------------
            // 3. Approval Table Section (ตารางอนุมัติ)
            // -------------------------------------------------------
            Row(
              children: [
                Text(
                  'สถานะ : ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: labelColor,
                  ),
                ),
                Text(
                  displayItem.status,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: displayItem.status == 'อนุมัติ'
                        ? Colors.green
                        : Colors.orange[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),

            Table(
              border: TableBorder.all(color: Colors.grey[600]!),
              columnWidths: const {
                0: FixedColumnWidth(40), // No
                1: FlexColumnWidth(2), // Name
                2: FlexColumnWidth(1.5), // Approved
                3: FlexColumnWidth(1), // Not Approved
              },
              children: [
                // Table Header
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey[200]),
                  children: [
                    _buildHeaderCell('No'),
                    _buildHeaderCell('Name'),
                    _buildHeaderCell('อนุมัติ'),
                    _buildHeaderCell('ไม่อนุมัติ', color: Colors.red),
                  ],
                ),
                // Data Rows
                _buildApprovalRow(
                  '1',
                  displayItem.approver.isNotEmpty
                      ? displayItem.approver
                      : 'ไม่มีข้อมูล',
                  displayItem.status == 'อนุมัติ'
                      ? 'อนุมัติ\n${displayItem.reqDate}'
                      : '-',
                  '-',
                ),
              ],
            ),

            // -------------------------------------------------------
            // Comments Section (ย้ายมาไว้ด้านล่างสุด)
            // -------------------------------------------------------
            const SizedBox(height: 20),
            if (_loadingComments)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_loadingComments && _comments.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ความเห็น/หมายเหตุ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey[300]),
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        final username =
                            comment['user_name'] ??
                            comment['username'] ??
                            comment['user'] ??
                            'Unknown';
                        final text =
                            comment['comment'] ??
                            comment['text'] ??
                            comment['message'] ??
                            '';
                        final timestamp =
                            comment['created_at'] ??
                            comment['createdAt'] ??
                            comment['date'] ??
                            '';
                        final userId = comment['user_id'] ?? comment['userId'];

                        return Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.blue[200],
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Center(
                                      child: Text(
                                        username.toString()[0].toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          username.toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (timestamp.toString().isNotEmpty)
                                          Text(
                                            _formatCreatedAt(
                                              timestamp.toString(),
                                            ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                text.toString(),
                                style: TextStyle(
                                  color: valueColor,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            if (!_loadingComments && _comments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'ไม่มีความเห็น/หมายเหตุ',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: InteractiveViewer(
                constrained: false,
                maxScale: 5.0,
                child: Image.network(
                  url,
                  // Do not force-fit; show at intrinsic size
                  errorBuilder: (c, e, s) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Icon(Icons.broken_image, size: 64),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Helper Widgets ---

  // สร้างแถวข้อมูลในส่วน Header (Label : Value)
  TableRow _buildTableRow(
    String label,
    String value,
    Color labelColor,
    Color valueColor,
  ) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.bold, color: labelColor),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 10.0, top: 4.0, bottom: 4.0),
          child: Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  // สร้าง Cell หัวตาราง
  Widget _buildHeaderCell(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color ?? Colors.teal[800],
          ),
        ),
      ),
    );
  }

  // สร้างแถวข้อมูลในตารางอนุมัติ
  TableRow _buildApprovalRow(
    String no,
    String name,
    String approvedStatus,
    String notApprovedStatus,
  ) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(child: Text(no)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: Text(
              name,
              style: TextStyle(
                color: Colors.blue[900],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Text(
                approvedStatus.split('\n')[0],
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (approvedStatus.contains('\n'))
                Text(
                  approvedStatus.split('\n')[1],
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: Text(
              notApprovedStatus,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }
}
