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
        // แนะนำให้ใช้ GoogleFonts.sarabun() หรือ kanit() ในงานจริงเพื่อให้ฟอนต์สวยงาม
        fontFamily: 'Sans-serif',
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

  // Pagination variables
  int _currentPage = 1;
  final int _limit = 15;
  int _totalItems = 0;
  bool _hasMoreData = true;

  int get _offset => (_currentPage - 1) * _limit;
  int get _totalPages => (_totalItems / _limit).ceil();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _futureItems = fetchRepairRequests(_limit, _offset);
    _futureItems.then((items) {
      setState(() {
        final set = <String>{};
        for (var it in items) {
          if (it.type.isNotEmpty) set.add(it.type);
        }
        _priorityOptions = ['ทั้งหมด', ...set.toList()];
        _hasMoreData = items.length >= _limit;
      });
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

  // ฟังก์ชันเรียก API
  Future<List<PurchaseItem>> fetchRepairRequests(int limit, int offset) async {
    try {
      print('Fetching data from API... (limit: $limit, offset: $offset)');
      final uri = Uri.parse(
        'http://26.99.205.41:9000/drugs/repair-requests?limit=$limit&offset=$offset',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        print('Decoded JSON: $jsonData');

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
          // Try common API response keys
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
            // If no data key, treat the entire object as single item
            items = [jsonData];
          }
        }

        print('Total items found: ${items.length}');

        List<PurchaseItem> purchaseItems = items.map((item) {
          print('Processing item: $item');
          return PurchaseItem(
            id: item['id']?.toString() ?? '',
            no: item['job_no']?.toString() ?? item['id']?.toString() ?? '',
            type: item['priority']?.toString() ?? 'ปกติ',
            topic:
                item['title']?.toString() ??
                item['description']?.toString() ??
                '',
            reqDate:
                item['request_date']?.toString() ??
                item['created_date']?.toString() ??
                'รอการอนุมัติ',
            prDate:
                item['pr_date']?.toString() ??
                item['po_date']?.toString() ??
                '-',
            reqBy:
                item['requested_by']?.toString() ??
                item['requester']?.toString() ??
                '',
            dept: item['department']?.toString() ?? '',
            status: item['status']?.toString() ?? 'รออนุมัติ',
            approver:
                item['approver']?.toString() ??
                item['approved_by']?.toString() ??
                '',
            createdAt:
                item['created_at']?.toString() ??
                item['created_date']?.toString() ??
                item['createdAt']?.toString() ??
                '',
            isHighlight: (item['status']?.toString() ?? '').contains('อนุมัติ'),
            rawData: item is Map ? Map<String, dynamic>.from(item) : null,
          );
        }).toList();
        print('Successfully loaded ${purchaseItems.length} items');
        return purchaseItems;
      } else {
        throw Exception(
          'Failed to load repair requests: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching data: $e');
      // Return empty list or default data on error
      return [];
    }
  }

  // ตัวแปรสำหรับ Filter
  String? selectedPriority = 'ทั้งหมด';
  int selectedRadio = 0; // 0=All, 1=Finished, etc.
  List<String> _priorityOptions = ['ทั้งหมด'];

  // ตัวแปรสำหรับ Search
  String _searchBy = 'รหัส';
  final TextEditingController _keywordController = TextEditingController();
  String _searchKeyword = '';

  // ฟังก์ชันกรองข้อมูลตามความสำคัญ (ใช้ค่า priority จาก API)
  List<PurchaseItem> _filterItems(List<PurchaseItem> items) {
    List<PurchaseItem> filtered = items;

    // Filter by priority
    if (selectedPriority != null && selectedPriority != 'ทั้งหมด') {
      filtered = filtered
          .where((item) => item.type == selectedPriority)
          .toList();
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

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Logout',
          icon: const Icon(Icons.logout, color: Colors.black),
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
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[300],
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ------------------------------------
          // 2. Search / Filter Section (ด้านบน)
          // ------------------------------------
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[100],
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
                      'Priority : ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(
                      height: 35,
                      child: DropdownButton<String>(
                        value: selectedPriority,
                        items: _priorityOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => selectedPriority = v),
                      ),
                    ),
                    _buildRadioOption(0, 'งานคงค้างทั้งหมด'),
                    _buildRadioOption(1, 'งานที่จบแล้ว'),
                    _buildRadioOption(2, 'งานค้างเปิด PO'),
                    _buildRadioOption(3, 'งานรออนุมัติ'),
                  ],
                ),
                const SizedBox(height: 10),

                // Row 2: Search Inputs & Buttons
                Row(
                  children: [
                    const Text(
                      'Search By : ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 5),
                    SizedBox(
                      height: 35,
                      child: DropdownButton<String>(
                        value: _searchBy,
                        items: ['รหัส', 'ชื่อ']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _searchBy = value ?? 'รหัส';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 15),
                    const Text(
                      'Keyword : ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: SizedBox(
                        height: 35,
                        child: TextField(
                          controller: _keywordController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                            ),
                            hintText: 'พิมพ์คำค้นหา...',
                          ),
                          onSubmitted: (_) => _performSearch(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _performSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[400],
                      ),
                      child: const Text(
                        'ค้นหาข้อมูล',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
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
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Colors.grey),
                      ),
                      child: const Text(
                        'แจ้งซ่อมใหม่',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(thickness: 2),

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
                  vertical: 8,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  color: Colors.grey[200],
                ),
                child: const Text(
                  'MTrequest REPORT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 5),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'REMARK : สามารถคลิกเพื่อดูไฟล์ PO ได้ที่ (PO:......) ใต้ Status',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                      headingRowColor: MaterialStateProperty.all(
                        Colors.grey[400],
                      ),
                      columnSpacing: 20,
                      border: TableBorder.all(color: Colors.grey[300]!),
                      columns: const [
                        DataColumn(
                          label: Text(
                            'No.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Type',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Topic',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'วันต้องการ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            '---',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Req.By',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Dept',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Status',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Finish',
                            style: TextStyle(fontWeight: FontWeight.bold),
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
                              );
                            }
                          },
                          color: MaterialStateProperty.resolveWith<Color?>(
                            (states) =>
                                index.isEven ? Colors.white : Colors.grey[50],
                          ),
                          cells: [
                            DataCell(
                              Text(
                                item.no,
                                style: const TextStyle(color: Colors.brown),
                              ),
                            ),
                            DataCell(
                              Text(
                                item.type,
                                style: TextStyle(
                                  color: item.type == 'ด่วน'
                                      ? Colors.red
                                      : Colors.black,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 200,
                                child: Text(
                                  item.topic,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(item.reqDate)),
                            DataCell(Text(item.prDate)),
                            DataCell(Text(item.reqBy)),
                            DataCell(
                              Text(
                                item.dept,
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.status,
                                    style: TextStyle(
                                      color: item.status == 'อนุมัติ'
                                          ? Colors.green
                                          : Colors.orange[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (item.approver.isNotEmpty)
                                    Text(
                                      item.approver,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                            const DataCell(
                              Icon(Icons.edit, color: Colors.orange, size: 20),
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
              color: Colors.grey[100],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Previous button
                ElevatedButton.icon(
                  onPressed: _currentPage > 1 ? _previousPage : null,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('ก่อนหน้า'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey[200],
                    disabledForegroundColor: Colors.grey[400],
                  ),
                ),
                const SizedBox(width: 16),

                // Page info
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'หน้า $_currentPage${_totalItems > 0 ? ' / $_totalPages' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),

                // Next button
                ElevatedButton.icon(
                  onPressed: _hasMoreData ? _nextPage : null,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('ถัดไป'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey[200],
                    disabledForegroundColor: Colors.grey[400],
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
          onChanged: (int? v) => setState(() => selectedRadio = v!),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
