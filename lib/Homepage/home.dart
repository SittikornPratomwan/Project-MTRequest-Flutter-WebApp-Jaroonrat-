import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import './Request/request.dart';
import './datail/detail.dart';

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

  @override
  void initState() {
    super.initState();
    _futureItems = fetchRepairRequests();
    _futureItems.then((items) {
      setState(() {
        final set = <String>{};
        for (var it in items) {
          if (it.type.isNotEmpty) set.add(it.type);
        }
        _priorityOptions = ['ทั้งหมด', ...set.toList()];
      });
    });
  }

  // ฟังก์ชันเรียก API
  Future<List<PurchaseItem>> fetchRepairRequests() async {
    try {
      print('Fetching data from API...');
      final response = await http
          .get(Uri.parse('http://26.99.205.41:9000/drugs/repair-requests'))
          .timeout(const Duration(seconds: 10));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        print('Decoded JSON: $jsonData');

        // Handle different response formats
        List<dynamic> items = [];

        if (jsonData is List) {
          items = jsonData;
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

  // ฟังก์ชันกรองข้อมูลตามความสำคัญ (ใช้ค่า priority จาก API)
  List<PurchaseItem> _filterItems(List<PurchaseItem> items) {
    if (selectedPriority == null || selectedPriority == 'ทั้งหมด') {
      return items;
    }
    return items.where((item) => item.type == selectedPriority).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
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
                        value: 'รหัส',
                        items: ['รหัส', 'ชื่อ']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (_) {},
                      ),
                    ),
                    const SizedBox(width: 15),
                    const Text(
                      'Keyword : ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 5),
                    const Expanded(
                      child: SizedBox(
                        height: 35,
                        child: TextField(
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {},
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
                            _futureItems = fetchRepairRequests();
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

          // Header "MTrequest REPORT"
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
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
                      rows: filteredItems.map((item) {
                        return DataRow(
                          selected: _selectedItem == item,
                          onSelectChanged: (selected) {
                            setState(() {
                              _selectedItem = selected == true ? item : null;
                            });
                            if (selected == true) {
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
                            (states) => Colors.white,
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
