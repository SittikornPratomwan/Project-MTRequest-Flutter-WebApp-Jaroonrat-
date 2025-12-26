import 'package:flutter/material.dart';
import './Request/request.dart';

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
// 1. Data Model: จำลองโครงสร้างข้อมูลในตาราง
// ---------------------------------------------------------
class PurchaseItem {
  final String no;
  final String type; // ด่วน/ปกติ
  final String topic;
  final String reqDate; // วันต้องการ
  final String prDate; // จัดซื้อรับ PR
  final String reqBy;
  final String dept;
  final String status;
  final String approver; // คนอนุมัติ (อยู่ในช่อง Status)
  final bool isHighlight; // สำหรับแถวสีเขียว

  PurchaseItem({
    required this.no,
    required this.type,
    required this.topic,
    required this.reqDate,
    required this.prDate,
    required this.reqBy,
    required this.dept,
    required this.status,
    required this.approver,
    this.isHighlight = false,
  });
}

class PurchaseReportPage extends StatefulWidget {
  const PurchaseReportPage({super.key});

  @override
  State<PurchaseReportPage> createState() => _PurchaseReportPageState();
}

class _PurchaseReportPageState extends State<PurchaseReportPage> {
  // ข้อมูลตัวอย่าง (Mock Data) ตามภาพ
  final List<PurchaseItem> items = [
    PurchaseItem(
      no: 'MT20467/68',
      type: 'ด่วน',
      topic: 'ขออนุมัติสั่งซื้อมอเตอร์ปั๊มน้ำหอพัก',
      reqDate: 'รอการอนุมัติ',
      prDate: '-',
      reqBy: 'จารุวัฒน์ แพงศรี',
      dept: 'MT',
      status: 'รออนุมัติ',
      approver: 'จักรพันธุ์ บุญเพ็ง',
    ),
    PurchaseItem(
      no: 'MT20466/68',
      type: 'ปกติ',
      topic: 'ขออนุมัติสั่งซื้อสายไฟสำหรับตู้สนาม',
      reqDate: 'รอการอนุมัติ',
      prDate: '-',
      reqBy: 'นที กันภัย',
      dept: 'MT',
      status: 'รออนุมัติ',
      approver: 'สุริยา กันภัย',
    ),
    PurchaseItem(
      no: 'HR03247/68',
      type: 'ด่วน',
      topic: 'ขออนุมัติสั่งซื้อบัตรและหมึกปริ้น',
      reqDate: '16/12/68',
      prDate: '-',
      reqBy: 'ประกายทิพย์ อิ่มสมบัติ',
      dept: 'HR',
      status: 'อนุมัติ',
      approver: '',
      isHighlight: true,
    ),
    PurchaseItem(
      no: 'L501193/68',
      type: 'ปกติ',
      topic: 'ขออนุมัติสั่งซื้อแผ่นเพลทแผนกEDP5',
      reqDate: 'รอการอนุมัติ',
      prDate: '-',
      reqBy: 'ธันยพร สิงห์พร',
      dept: 'L5',
      status: 'รออนุมัติ',
      approver: 'วิชัย ทิพยพร',
    ),
    PurchaseItem(
      no: 'MT20465/68',
      type: 'ด่วน',
      topic: 'ขออนุมัติสั่งซื้อฝาเกียร์โฟล์คลิฟท์เบอร์ 4',
      reqDate: 'รอการอนุมัติ',
      prDate: '-',
      reqBy: 'จารุวัฒน์ แพงศรี',
      dept: 'MT',
      status: 'รออนุมัติ',
      approver: 'จักรพันธุ์ บุญเพ็ง',
    ),
    PurchaseItem(
      no: 'DL06588/68',
      type: 'ปกติ',
      topic: 'ขออนุมัติออก PO บ.ชัยทัต โปรดักท์ จก.',
      reqDate: 'รอการอนุมัติ',
      prDate: '-',
      reqBy: 'วรรณภา โฉมนาค',
      dept: 'DL',
      status: 'รออนุมัติ',
      approver: 'ชลาลัย สมบุญ',
    ),
  ];

  // ตัวแปรสำหรับ Filter
  String? selectedPriority = 'ทั้งหมด';
  int selectedRadio = 0; // 0=All, 1=Finished, etc.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'ค้นหา',
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
                        items: ['ทั้งหมด', 'ด่วน', 'ปกติ'].map((String value) {
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
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RequestFormPage(),
                          ),
                        );
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
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey[400]),
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
                        'จัดซื้อรับPR',
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
                  rows: items.map((item) {
                    return DataRow(
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
                            width: 200, // จำกัดความกว้าง Topic ไม่ให้ยาวเกิน
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
