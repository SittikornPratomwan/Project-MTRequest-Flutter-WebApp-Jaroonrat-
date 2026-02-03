import 'package:flutter/material.dart';

// Data Model for detail page
class PurchaseItem {
  final String no;
  final String type;
  final String topic;
  final String reqDate;
  final String prDate;
  final String reqBy;
  final String dept;
  final String status;
  final String approver;
  final bool isHighlight;
  final Map<String, dynamic>? rawData;

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
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Sans-serif',
      ),
      home: const PurchaseDetailPage(),
    );
  }
}

class PurchaseDetailPage extends StatelessWidget {
  final PurchaseItem? item;

  const PurchaseDetailPage({super.key, this.item});

  @override
  Widget build(BuildContext context) {
    final Color labelColor = Colors.teal[700]!;
    final Color valueColor = Colors.blue[900]!;

    // Use passed data or default data
    final displayItem =
        item ??
        PurchaseItem(
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
        title: const Text('MT request Detail'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
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
                // Label: สั่งซื้อโดย
                SizedBox(
                  width: 100,
                  child: Text(
                    'สั่งซื้อโดย :',
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
                _buildTableRow('Mode :', 'Purchase', labelColor, valueColor),
                _buildTableRow(
                  'หัวข้อสั่งซื้อ :',
                  displayItem.topic,
                  labelColor,
                  valueColor,
                ),
                _buildTableRow(
                  'เรียน/สำเนาถึง :',
                  displayItem.approver.isNotEmpty
                      ? displayItem.approver
                      : 'ไม่มีข้อมูล',
                  labelColor,
                  valueColor,
                ),
                _buildTableRow(
                  'ความสำคัญ :',
                  displayItem.type,
                  labelColor,
                  valueColor,
                ),
                _buildTableRow(
                  'ระยะเวลาดำเนินการ :',
                  '3 วัน',
                  labelColor,
                  valueColor,
                ),
                _buildTableRow(
                  'ประเภท :',
                  'ค่าใช้จ่ายอื่นๆ',
                  labelColor,
                  valueColor,
                ),
                _buildTableRow(
                  'ประเภทการซื้อ :',
                  'ค่าใช้จ่ายอื่นๆ',
                  labelColor,
                  valueColor,
                ),
                _buildTableRow(
                  'ราคาโดยประมาณ :',
                  'น้อยกว่าหรือเท่ากับ 50,000 บาท',
                  labelColor,
                  valueColor,
                ),
                _buildTableRow(
                  'Budget :',
                  'นอก Budget',
                  labelColor,
                  valueColor,
                ),
                _buildTableRow(
                  'PR No :',
                  displayItem.no,
                  labelColor,
                  valueColor,
                ),
                _buildTableRow(
                  'วันที่สร้าง PR :',
                  displayItem.reqDate,
                  labelColor,
                  valueColor,
                ),
                _buildTableRow(
                  'วันที่แก้ไข :',
                  displayItem.reqDate,
                  labelColor,
                  valueColor,
                ),
                _buildTableRow(
                  'วันที่ต้องการสินค้า :',
                  displayItem.reqDate,
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

            const SizedBox(height: 30),
          ],
        ),
      ),
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
