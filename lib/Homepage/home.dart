// ignore_for_file: unused_field, unused_element

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import './Request/request.dart';
import './datail/detail.dart';
import './report.dart';
import '../Authen/authen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Purchase Report',
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
      home: const PurchaseReportPage(),
    );
  }
}

// ---------------------------------------------------------
// 1. Data Model: ใช้ PurchaseItem จาก detail.dart
// ---------------------------------------------------------

class PurchaseReportPage extends StatefulWidget {
  const PurchaseReportPage({super.key});

  @override
  State<PurchaseReportPage> createState() => _PurchaseReportPageState();
}

class _PurchaseReportPageState extends State<PurchaseReportPage> {
  late Future<List<PurchaseItem>> _futureItems;
  PurchaseItem? _selectedItem;
  // Set of IDs marked as read in this session
  final Set<String> _readIds = <String>{};
  bool _showPendingApproval = false; // Flag to show pending approval items
  int _pendingApprovalCount = 0; // Count of pending approval items

  // Pagination variables
  int _currentPage = 1;
  int _limit = 15;
  int _totalItems = 0;
  bool _hasMoreData = true;

  int get _offset => (_currentPage - 1) * _limit;
  int get _totalPages => (_totalItems / _limit).ceil();

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshPendingApprovalCount();
  }

  Future<void> _refreshPendingApprovalCount() async {
    try {
      final count = await fetchPendingApprovalCount();
      if (!mounted) return;
      setState(() {
        _pendingApprovalCount = count;
      });
    } catch (_) {}
  }

  void _loadData([int? offsetOverride]) {
    final offset = offsetOverride ?? _offset;
    _futureItems = fetchRepairRequests(_limit, offset);
    _futureItems.then((items) {
      setState(() {
        final set = <String>{};
        for (var it in items) {
          if (it.type.isNotEmpty) set.add(it.type);
        }
        _priorityOptions = ['ทั้งหมด', ...set];
        _hasMoreData = items.length >= _limit;
      });
    });
  }

  // Load and show pending-approval items (reset filters and update count)
  void _showPendingApprovalItems() {
    setState(() {
      _showPendingApproval = true;
      _currentPage = 1;
      selectedPriority = 'ทั้งหมด';
      _searchKeyword = '';
      _keywordController.clear();
    });

    _futureItems = fetchPendingApprovalRequests();
    _futureItems.then((items) {
      setState(() {
        _pendingApprovalCount = items.length;
        // Pending-approval list is typically not paginated by this UI
        _hasMoreData = false;
      });
    });
  }

  void _changeLimit(int newLimit) {
    if (newLimit == _limit) return;
    setState(() {
      _limit = newLimit;
      _currentPage = 1;
      // When changing page size, fetch from offset=0 per requirement
      _loadData(0);
    });
  }

  void _goToPage(int page) {
    if (page < 1) return;
    if (_totalItems > 0 && page > _totalPages) return;
    setState(() {
      _currentPage = page;
      _loadData();
    });
  }

  void _nextPage() {
    if (_hasMoreData) {
      _goToPage(_currentPage + 1);
    }
  }

  void _previousPage() {
    _goToPage(_currentPage - 1);
  }

  // ฟังก์ชันแปล priority จากภาษาอังกฤษเป็นไทย
  String _translatePriority(String priority) {
    final map = {'normal': 'ปกติ', 'urgent': 'เร่งรีบ', 'project': 'กำหนดเอง'};
    return map[priority.toLowerCase()] ?? priority;
  }

  String _normalizeDisplayStatus(String raw) {
    final status = raw.trim();
    if (status == 'อนุมัติ') return 'กำลังดำเนินการ';
    if (status == 'รอการอนุมัติ') return 'รออนุมัติ';
    if (status == 'รอตรวจสอบ') return 'รอตรวจรับงาน';
    return status;
  }

  Color _statusColorFor(String raw) {
    switch (_normalizeDisplayStatus(raw)) {
      case 'รออนุมัติ':
      case 'รอช่างอนุมัติ':
        return const Color(0xFFFACC15);
      case 'กำลังดำเนินการ':
        return const Color(0xFF3B82F6);
      case 'ตรวจสอบไม่ผ่าน':
        return const Color(0xFFFB923C);
      case 'ไม่อนุมัติ':
        return const Color(0xFF374151);
      case 'เสร็จสิ้น':
        return const Color(0xFF22C55E);
      case 'รอตรวจรับงาน':
        return const Color(0xFFA855F7);
      default:
        return const Color(0xFF4A5568);
    }
  }

  // ฟังก์ชันเลือก reqDate ตามค่า current_phase (ยังคงไว้ใช้กับวันที่ได้)
  String _getReqDate(
    dynamic currentPhase,
    dynamic dueDate,
    dynamic requestDate,
    dynamic createdDate,
  ) {
    final phase = int.tryParse(currentPhase.toString()) ?? 0;
    if (phase == 2 && dueDate != null && dueDate.toString().isNotEmpty) {
      return dueDate.toString();
    }
    // Fallback to request_date or created_date
    return requestDate?.toString() ?? createdDate?.toString() ?? 'รอการอนุมัติ';
  }

  // Map selected status dropdown value to display label
  String _statusLabelForSelected(int sel) {
    if (sel == 1) return 'รอการอนุมัติ';
    if (sel == 2) return 'กำลังดำเนินการ';
    if (sel == 3) return 'ดำเนินการสำเร็จ';
    return '';
  }

  // Map a raw status string to one of the status categories used in the dropdown
  String _mapStatusToCategory(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('ไม่อนุมัติ') ||
        s.contains('ยกเลิก') ||
        s.contains('reject') ||
        s.contains('rejected')) {
      return 'ไม่ผ่านการอนุมัติ';
    }
    if (s.contains('รอช่าง') || (s.contains('รอ') && s.contains('ช่าง'))) {
      return 'รอช่างอนุมัติ';
    }
    if (s.contains('ตรวจ') || s.contains('inspection')) {
      return 'รอตรวจรับงาน';
    }
    if (s.contains('เสร็จ') ||
        s.contains('สำเร็จ') ||
        s.contains('complete') ||
        s.contains('finish') ||
        s.contains('อนุมัติ')) {
      return 'เสร็จสิ้น';
    }
    if (s.contains('รอ') || s.contains('pending') || s.contains('wait')) {
      return 'รออนุมัติ';
    }
    return 'อื่นๆ';
  }

  // ฟังก์ชันเรียก API
  Future<List<PurchaseItem>> fetchRepairRequests(int limit, int offset) async {
    try {
      final uri = Uri.parse(
        'http://26.99.205.41:9000/drugs/repair-requests?limit=$limit&offset=$offset',
      );

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (Authen.token != null && Authen.token!.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${Authen.token}';
      }

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load repair requests: ${response.statusCode}',
        );
      }

      final jsonData = jsonDecode(response.body);

      // Handle different response formats
      List<dynamic> items = [];

      // Extract total count if available
      if (jsonData is Map && jsonData.containsKey('total')) {
        _totalItems = jsonData['total'] is int
            ? jsonData['total']
            : int.tryParse(jsonData['total'].toString()) ?? 0;
      }

      if (jsonData is List) {
        items = jsonData;
        if (_totalItems == 0) _totalItems = items.length;
      } else if (jsonData is Map) {
        if (jsonData.containsKey('data')) {
          items = jsonData['data'] is List
              ? jsonData['data']
              : [jsonData['data']];
        } else if (jsonData.containsKey('results')) {
          items = jsonData['results'] is List
              ? jsonData['results']
              : [jsonData['results']];
        } else if (jsonData.containsKey('items')) {
          items = jsonData['items'] is List
              ? jsonData['items']
              : [jsonData['items']];
        } else if (jsonData.containsKey('repair_requests')) {
          items = jsonData['repair_requests'] is List
              ? jsonData['repair_requests']
              : [jsonData['repair_requests']];
        } else {
          items = [jsonData];
        }
      }

      final List<PurchaseItem> purchaseItems = items.map((item) {
        return PurchaseItem(
          id: item['id']?.toString() ?? '',
          no: item['job_no']?.toString() ?? item['id']?.toString() ?? '',
          type: _translatePriority(item['priority']?.toString() ?? 'normal'),
          topic:
              item['title']?.toString() ??
              item['description']?.toString() ??
              '',
          reqDate: _getReqDate(
            item['current_phase'],
            item['due_date'],
            item['request_date'],
            item['created_date'],
          ),
          prDate:
              item['pr_date']?.toString() ?? item['po_date']?.toString() ?? '-',
          reqBy:
              item['username']?.toString() ??
              item['requested_by']?.toString() ??
              item['requester']?.toString() ??
              '',
          dept:
              item['department_name']?.toString() ??
              item['department']?.toString() ??
              '',
          // ดึงค่า status_label มาใช้แทน current_phase
          status:
              (item['status_label'] ?? item['statusLabel'] ?? 'รอการอนุมัติ')
                  .toString(),
          approver:
              item['approver']?.toString() ??
              item['approved_by']?.toString() ??
              '',
          createdAt:
              item['created_at']?.toString() ??
              item['created_date']?.toString() ??
              item['createdAt']?.toString() ??
              '',
          isHighlight: (item['status_label']?.toString() ?? '').contains(
            'อนุมัติ',
          ),
          rawData: item is Map ? Map<String, dynamic>.from(item) : null,
        );
      }).toList();

      return purchaseItems;
    } catch (e) {
      _showSnack('Error fetching data: $e', error: true);
      return [];
    }
  }

  Future<int> fetchPendingApprovalCount() async {
    if (Authen.requesterId == null) {
      return 0;
    }

    final uri = Uri.parse(
      'http://26.99.205.41:9000/drugs/repair-requests/pending-approval/by-user?user_id=${Authen.requesterId}',
    );

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (Authen.token != null && Authen.token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${Authen.token}';
    }

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load pending approval count: ${response.statusCode}',
      );
    }

    final jsonData = jsonDecode(response.body);

    if (jsonData is List) {
      return jsonData.length;
    }

    if (jsonData is Map) {
      if (jsonData.containsKey('total')) {
        final total = jsonData['total'];
        if (total is int) {
          return total;
        }
        return int.tryParse(total.toString()) ?? 0;
      }

      for (final key in const ['data', 'results', 'items', 'repair_requests']) {
        final value = jsonData[key];
        if (value is List) {
          return value.length;
        }
      }
    }

    return 0;
  }

  // ฟังก์ชันเรียก API สำหรับรายการที่รอการอนุมัติ
  Future<List<PurchaseItem>> fetchPendingApprovalRequests() async {
    try {
      if (Authen.requesterId == null) {
        throw Exception('User ID not found. Please login again.');
      }

      final uri = Uri.parse(
        'http://26.99.205.41:9000/drugs/repair-requests/pending-approval/by-user?user_id=${Authen.requesterId}',
      );

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (Authen.token != null && Authen.token!.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${Authen.token}';
      }

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load pending approval requests: ${response.statusCode}',
        );
      }

      final jsonData = jsonDecode(response.body);

      List<dynamic> items = [];
      if (jsonData is List) {
        items = jsonData;
        _totalItems = items.length;
      } else if (jsonData is Map) {
        if (jsonData.containsKey('data')) {
          items = jsonData['data'] is List
              ? jsonData['data']
              : [jsonData['data']];
        } else if (jsonData.containsKey('results')) {
          items = jsonData['results'] is List
              ? jsonData['results']
              : [jsonData['results']];
        } else if (jsonData.containsKey('items')) {
          items = jsonData['items'] is List
              ? jsonData['items']
              : [jsonData['items']];
        } else if (jsonData.containsKey('repair_requests')) {
          items = jsonData['repair_requests'] is List
              ? jsonData['repair_requests']
              : [jsonData['repair_requests']];
        } else if (jsonData.containsKey('total')) {
          _totalItems = jsonData['total'] is int
              ? jsonData['total']
              : int.tryParse(jsonData['total'].toString()) ?? 0;
          items = [];
        } else {
          items = [jsonData];
          _totalItems = 1;
        }
      }

      final List<PurchaseItem> purchaseItems = items.map((item) {
        return PurchaseItem(
          id: item['id']?.toString() ?? '',
          no: item['job_no']?.toString() ?? item['id']?.toString() ?? '',
          type: _translatePriority(item['priority']?.toString() ?? 'normal'),
          topic:
              item['title']?.toString() ??
              item['description']?.toString() ??
              '',
          reqDate: _getReqDate(
            item['current_phase'],
            item['due_date'],
            item['request_date'],
            item['created_date'],
          ),
          prDate:
              item['pr_date']?.toString() ?? item['po_date']?.toString() ?? '-',
          reqBy:
              item['username']?.toString() ??
              item['requested_by']?.toString() ??
              item['requester']?.toString() ??
              '',
          dept:
              item['department_name']?.toString() ??
              item['department']?.toString() ??
              '',
          // ดึงค่า status_label มาใช้แทน current_phase
          status:
              (item['status_label'] ?? item['statusLabel'] ?? 'รอการอนุมัติ')
                  .toString(),
          approver:
              item['approver']?.toString() ??
              item['approved_by']?.toString() ??
              '',
          createdAt:
              item['created_at']?.toString() ??
              item['created_date']?.toString() ??
              item['createdAt']?.toString() ??
              '',
          isHighlight: true,
          rawData: item is Map ? Map<String, dynamic>.from(item) : null,
        );
      }).toList();

      return purchaseItems;
    } catch (e) {
      _pendingApprovalCount = 0;
      _showSnack('Error: $e', error: true);
      return [];
    }
  }

  // ตัวแปรสำหรับ Filter
  String? selectedPriority = 'ทั้งหมด';
  int selectedRadio = 0; // 0=All, 1=Finished, etc.
  List<String> _priorityOptions = ['ทั้งหมด'];
  // สถานะตัวกรอง (dropdown)
  String selectedStatus = 'ทั้งหมด';
  final List<String> _statusOptions = [
    'ทั้งหมด',
    'รออนุมัติ',
    'กำลังดำเนินการ',
    'รอช่างอนุมัติ',
    'รอตรวจรับงาน',
    'เสร็จสิ้น',
    'ไม่ผ่านการอนุมัติ',
  ];

  // ตัวแปรสำหรับ Search
  String _searchBy = 'รหัส';
  final TextEditingController _keywordController = TextEditingController();
  String _searchKeyword = '';

  // ฟังก์ชันกรองข้อมูลตามความสำคัญ (ใช้ค่า priority จาก API)
  List<PurchaseItem> _filterItems(List<PurchaseItem> items) {
    // If showing pending approval items, don't apply additional filters
    // as the API already filtered them
    if (_showPendingApproval) {
      return items;
    }

    List<PurchaseItem> filtered = items;

    // Filter by priority
    if (selectedPriority != null && selectedPriority != 'ทั้งหมด') {
      filtered = filtered
          .where((item) => item.type == selectedPriority)
          .toList();
    }

    // Filter by status from dropdown
    if (selectedStatus != 'ทั้งหมด') {
      filtered = filtered.where((item) {
        final rawLabel =
            (item.rawData != null
                    ? (item.rawData!['status_label'] ??
                          item.rawData!['statusLabel'])
                    : null)
                ?.toString()
                .trim()
                .toLowerCase();

        final normalized =
            rawLabel ?? item.status.toString().trim().toLowerCase();

        // Exact-match filtering per user's mapping
        switch (selectedStatus) {
          case 'รออนุมัติ':
            return normalized == 'รออนุมัติ';
          case 'กำลังดำเนินการ':
            // include items whose raw status_label is exactly 'กำลังดำเนินการ'
            // or backend uses 'อนุมัติ' (mapped/displayed as 'กำลังดำเนินการ')
            return normalized == 'กำลังดำเนินการ' ||
                normalized == 'อนุมัติ' ||
                normalized.contains('ดำเนิน') ||
                normalized.contains('กำลัง');
          case 'รอช่างอนุมัติ':
            return normalized == 'รอช่างอนุมัติ';
          case 'รอตรวจรับงาน':
            return normalized == 'รอตรวจรับงาน';
          case 'เสร็จสิ้น':
            return normalized == 'เสร็จสิ้น';
          case 'ไม่ผ่านการอนุมัติ':
            // user asked to map this to status_label == 'ไม่อนุมัติ'
            return normalized == 'ไม่อนุมัติ';
          default:
            return false;
        }
      }).toList();
    }

    // Filter by status (support multiple backend formats):
    // 0=all, 1=รอการอนุมัติ, 2=กำลังดำเนินการ, 3=งานที่จบแล้ว
    if (selectedRadio != 0) {
      filtered = filtered.where((item) {
        final statusLabel = item.status.toLowerCase();

        if (selectedRadio == 1) {
          return statusLabel.contains('รอ') ||
              statusLabel.contains('pending') ||
              statusLabel.contains('wait');
        }
        if (selectedRadio == 2) {
          return statusLabel.contains('ดำเนิน') ||
              statusLabel.contains('กำลัง') ||
              statusLabel.contains('progress') ||
              statusLabel.contains('in progress');
        }
        if (selectedRadio == 3) {
          return statusLabel.contains('สำเร็จ') ||
              statusLabel.contains('อนุมัติ') ||
              statusLabel.contains('complete') ||
              statusLabel.contains('finish');
        }
        return false;
      }).toList();
    }

    // Filter by search keyword
    if (_searchKeyword.isNotEmpty) {
      filtered = filtered.where((item) {
        if (_searchBy == 'รหัส') {
          // ค้นหาจาก job_no
          return item.no.toLowerCase().contains(_searchKeyword.toLowerCase());
        } else {
          // ค้นหาจาก search_tsv (ในข้อมูลดิบ)
          if (item.rawData != null && item.rawData!.containsKey('search_tsv')) {
            final searchTsv = item.rawData!['search_tsv']?.toString() ?? '';
            return searchTsv.toLowerCase().contains(
              _searchKeyword.toLowerCase(),
            );
          }
          // fallback: ค้นหาจาก topic
          return item.topic.toLowerCase().contains(
            _searchKeyword.toLowerCase(),
          );
        }
      }).toList();
    }

    return filtered;
  }

  // ฟังก์ชันค้นหา
  void _performSearch() {
    setState(() {
      _searchKeyword = _keywordController.text.trim();
    });
  }

  // Calculate remaining days until a given date
  int _getRemainingDays(String dateString) {
    if (dateString.isEmpty || dateString == '-') return -1;
    try {
      final date = DateTime.parse(dateString);
      final today = DateTime.now();
      final remaining = date.difference(today).inDays;
      return remaining;
    } catch (_) {
      return -1;
    }
  }

  // Format a datetime string to date-only (YYYY-MM-DD). If parsing fails, return original or '-'.
  String _formatDateOnly(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$d/$m/$y';
    } catch (_) {
      // Fallback: try to handle common date string formats like
      // YYYY-MM-DD or YYYY/MM/DD or DD-MM-YYYY etc., and convert to DD/MM/YYYY
      String part = raw;
      if (raw.contains(' ')) part = raw.split(' ').first;
      if (part.contains('-')) {
        final seg = part.split('-');
        if (seg.length >= 3) {
          // If first segment looks like year (4 chars) assume YYYY-MM-DD
          if (seg[0].length == 4) {
            return '${seg[2].padLeft(2, '0')}/${seg[1].padLeft(2, '0')}/${seg[0]}';
          } else {
            // Assume already DD-MM-YYYY -> convert separators
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

  // Small helper to show SnackBar messages from async contexts
  void _showSnack(String message, {bool error = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        leading: IconButton(
          tooltip: 'Logout',
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('ยืนยันออกจากระบบ'),
                content: const Text('คุณต้องการออกจากระบบจริงหรือไม่?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('ยกเลิก'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('ออกจากระบบ'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (c) => const Authen()),
                (route) => false,
              );
            }
          },
        ),
        title: const Text(
          'MT request',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: const Color(0xFF1976D2),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _currentPage = 1;
                _loadData(0);
              });
              _refreshPendingApprovalCount();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ------------------------------------
          // 2. Search / Filter Section (ด้านบน)
          // ------------------------------------
          Container(
            width: MediaQuery.of(context).size.width,
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 24.0,
            ),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Priority & Radio Buttons
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'ประเภท : ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3748),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.white,
                      ),
                      child: DropdownButton<String>(
                        value: selectedPriority,
                        underline: const SizedBox.shrink(),
                        items: _priorityOptions.map((e) {
                          return DropdownMenuItem<String>(
                            value: e,
                            child: Text(
                              e,
                              style: const TextStyle(
                                color: Color(0xFF2D3748),
                                fontSize: 14,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() {
                          selectedPriority = v;
                          _searchKeyword = '';
                          _keywordController.clear();
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'สถานะ : ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3748),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.white,
                      ),
                      child: DropdownButton<String>(
                        value: selectedStatus,
                        underline: const SizedBox.shrink(),
                        items: _statusOptions.map((e) {
                          return DropdownMenuItem<String>(
                            value: e,
                            child: Text(
                              e,
                              style: const TextStyle(
                                color: Color(0xFF2D3748),
                                fontSize: 14,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() {
                          selectedStatus = v ?? 'ทั้งหมด';
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Row 2: Search Inputs & Buttons (left flexible, right fixed)
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Text(
                            'ค้นหาจาก : ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.white,
                            ),
                            child: DropdownButton<String>(
                              value: _searchBy,
                              underline: const SizedBox.shrink(),
                              items: ['รหัส', 'ชื่อ']
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(
                                        e,
                                        style: const TextStyle(
                                          color: Color(0xFF2D3748),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _searchBy = value ?? 'รหัส';
                                  _searchKeyword = '';
                                  _keywordController.clear();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 15),
                          const Text(
                            'คำที่ค้นหา : ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 5),
                          // Expanded search input stretches to the right up to fixed buttons
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: TextField(
                                controller: _keywordController,
                                style: const TextStyle(
                                  color: Color(0xFF2D3748),
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
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
                                  hintText: 'พิมพ์คำค้นหา...',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFFCBD5E0),
                                    fontSize: 14,
                                  ),
                                ),
                                onSubmitted: (_) => _performSearch(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Fixed right-aligned buttons: ค้นหาข้อมูล, ทั้งหมด, รายการที่รอคุณอนุมัติ, แจ้งซ่อมใหม่
                    ElevatedButton(
                      onPressed: _performSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('ค้นหาข้อมูล'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showPendingApproval = false;
                          _currentPage = 1;
                          _loadData(0);
                          selectedPriority = 'ทั้งหมด';
                          _searchKeyword = '';
                          _keywordController.clear();
                        });
                        _refreshPendingApprovalCount();
                      },
                      icon: const Icon(Icons.list, size: 18),
                      label: const Text('ทั้งหมด'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4299E1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showPendingApprovalItems,
                      icon: const Icon(Icons.pending_actions, size: 18),
                      label: Text(
                        'รายการที่รอคุณอนุมัติ (${_pendingApprovalCount})',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFED8936),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RequestFormPage(),
                          ),
                        );
                        // Refresh data if form was submitted successfully
                        if (result == true) {
                          setState(() {
                            _currentPage = 1;
                            _loadData();
                          });
                          _refreshPendingApprovalCount();
                        }
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('แจ้งซ่อมใหม่'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF48BB78),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(thickness: 1),

          // Header "MTrequest REPORT" (tappable)
          Center(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReportPage()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF1976D2), width: 2),
                  color: const Color(0xFF1976D2).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'MTRequest REPORT',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF1976D2),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          // ------------------------------------
          // 3. Data Table Section (ตาราง)
          // ------------------------------------
          Expanded(
            child: FutureBuilder<List<PurchaseItem>>(
              future: _futureItems,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No data available'));
                }

                List<PurchaseItem> items = snapshot.data!;
                List<PurchaseItem> filteredItems = _filterItems(items);
                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFF1976D2).withOpacity(0.1),
                      ),
                      columnSpacing: 28,
                      headingRowHeight: 56,
                      dataRowHeight: 76,
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: Colors.grey[200]!,
                          width: 1,
                        ),
                        bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                        top: BorderSide(color: Colors.grey[200]!, width: 1),
                        left: BorderSide(color: Colors.grey[200]!, width: 1),
                        right: BorderSide(color: Colors.grey[200]!, width: 1),
                      ),
                      columns: const [
                        DataColumn(label: SizedBox.shrink()),
                        DataColumn(
                          label: Text(
                            'หมายเลข',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1976D2),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'ประเภท',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1976D2),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'หัวข้อ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1976D2),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'วันที่ร้องขอ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1976D2),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'วันต้องการ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1976D2),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'ผู้ร้องขอ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1976D2),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'แผนก',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1976D2),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'สถานะ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1976D2),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                      rows: filteredItems.asMap().entries.map((entry) {
                        int index = entry.key;
                        PurchaseItem item = entry.value;
                        return DataRow(
                          selected: _selectedItem == item,
                          onSelectChanged: (selected) {
                            setState(() {
                              _selectedItem = selected == true ? item : null;
                              if (selected == true) {
                                // mark as locally read when user selects (opens) the item in this session
                                if (item.id.isNotEmpty) _readIds.add(item.id);
                              }
                            });
                            if (selected == true) {
                              print('========================================');
                              print('Navigating to detail page');
                              print('Selected item ID: ${item.id}');
                              print('Selected item No: ${item.no}');
                              print('Selected item Topic: ${item.topic}');
                              print('========================================');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PurchaseDetailPage(item: item),
                                ),
                              ).then((result) {
                                // If detail page indicates the item was deleted, refresh list
                                if (result == true) {
                                  setState(() {
                                    _currentPage = 1;
                                  });
                                  _loadData(0);
                                }
                              });
                            }
                          },
                          color: WidgetStateProperty.resolveWith<Color?>(
                            (states) => index.isEven
                                ? Colors.white
                                : const Color(0xFFF7FAFC),
                          ),
                          cells: [
                            DataCell(
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Builder(
                                  builder: (context) {
                                    // is_read = false หมายถึง ยังไม่อ่าน (มีข้อความใหม่)
                                    // is_read = true  หมายถึง อ่านแล้ว (ไม่มีข้อความใหม่)
                                    bool hasNewMsgFromApi = false;
                                    if (item.rawData != null &&
                                        item.rawData!['is_read'] != null) {
                                      final val = item.rawData!['is_read'];
                                      hasNewMsgFromApi =
                                          (val == false ||
                                          val == 'false' ||
                                          val == 0);
                                    }

                                    // .....ซ่อนจุดแจ้งเตือนหากผู้ใช้กดเปิดดูใน session ปัจจุบันแล้ว (_readIds.contains)
                                    final bool showNewMessageIcon =
                                        hasNewMsgFromApi &&
                                        !_readIds.contains(item.id);

                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Icon(
                                          showNewMessageIcon
                                              ? Icons.markunread
                                              : Icons.mark_email_read,
                                          color: showNewMessageIcon
                                              ? const Color(0xFF1976D2)
                                              : const Color(0xFF94A3B8),
                                          size: 20,
                                        ),
                                        if (showNewMessageIcon)
                                          Positioned(
                                            right: -2,
                                            top: -2,
                                            child: Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 1.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                            DataCell(
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Text(
                                  item.no,
                                  style: const TextStyle(
                                    color: Color(0xFF2D3748),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Text(
                                  item.type,
                                  style: TextStyle(
                                    color: item.type == 'เร่งรีบ'
                                        ? const Color(0xFFE53E3E)
                                        : item.type == 'ปกติ'
                                        ? const Color(0xFF38A169)
                                        : item.type == 'กำหนดเอง'
                                        ? const Color(0xFFD69E2E)
                                        : const Color(0xFF4A5568),
                                    fontWeight:
                                        item.type == 'เร่งรีบ' ||
                                            item.type == 'ปกติ' ||
                                            item.type == 'กำหนดเอง'
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: SizedBox(
                                  width: 350,
                                  child: Text(
                                    item.topic,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF2D3748),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Text(
                                  _formatDateOnly(item.createdAt),
                                  style: const TextStyle(
                                    color: Color(0xFF4A5568),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final remainingDays = _getRemainingDays(
                                      item.reqDate,
                                    );
                                    final isUrgent =
                                        remainingDays >= 0 &&
                                        remainingDays <= 2;
                                    return Text(
                                      _formatDateOnly(item.reqDate),
                                      style: TextStyle(
                                        color: const Color(0xFF2D3748),
                                        fontSize: 14,
                                        fontWeight: isUrgent
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            DataCell(
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Text(
                                  item.reqBy,
                                  style: const TextStyle(
                                    color: Color(0xFF4A5568),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Text(
                                  item.dept,
                                  style: const TextStyle(
                                    color: Color(0xFF2D3748),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            // New cell: show status_label from API (colored)
                            DataCell(
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final rawStatus =
                                        (item.rawData != null
                                                ? (item.rawData!['status_label'] ??
                                                      item.rawData!['statusLabel'])
                                                : null)
                                            ?.toString() ??
                                        item.status.toString();
                                    final displayStatus =
                                        _normalizeDisplayStatus(rawStatus);
                                    return Text(
                                      displayStatus,
                                      style: TextStyle(
                                        color: _statusColorFor(rawStatus),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),

          // ------------------------------------
          // 4. Pagination Controls
          // ------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Page size selector
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'แสดง: ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: DropdownButton<int>(
                        value: _limit,
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        items: [10, 15, 20, 25, 30].map((e) {
                          return DropdownMenuItem<int>(
                            value: e,
                            child: Text(
                              e.toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) _changeLimit(v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                ),

                // Previous button
                ElevatedButton.icon(
                  onPressed: _currentPage > 1 ? _previousPage : null,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text(
                    'ก่อนหน้า',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    minimumSize: const Size(36, 36),
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCBD5E0),
                    disabledForegroundColor: const Color(0xFF718096),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Page info (compact)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    'หน้า $_currentPage${_totalItems > 0 ? ' / $_totalPages' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Next button
                ElevatedButton.icon(
                  onPressed: _hasMoreData ? _nextPage : null,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text(
                    'ถัดไป',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    minimumSize: const Size(36, 36),
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCBD5E0),
                    disabledForegroundColor: const Color(0xFF718096),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget ช่วยสร้าง Radio Button
  Widget _buildRadioOption(int value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<int>(
          value: value,
          groupValue: selectedRadio,
          activeColor: const Color(0xFF1976D2),
          onChanged: (int? v) => setState(() => selectedRadio = v!),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF2D3748),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
