import 'package:flutter/material.dart';

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
  const PurchaseDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Color labelColor = Colors.teal[700]!;
    final Color valueColor = Colors.blue[900]!;

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
                      'คุณ จารุวัฒน์ แพงศรี',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: valueColor,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'แผนก MT',
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
                  'ขออนุมัติซ่อมมอเตอร์ปั๊มน้ำหอพัก',
                  labelColor,
                  valueColor,
                ),
                _buildTableRow(
                  'เรียน/สำเนาถึง :',
                  'คุณวัฒนะ , คุณจักรพันธุ์ , คุณสุรชัย , คุณปรีชา',
                  labelColor,
                  valueColor,
                ),
                _buildTableRow(
                  'ความสำคัญ :',
                  'ด่วน',
                  labelColor,
                  valueColor,
                ), // อาจจะใส่สีแดงถ้าต้องการ
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
                _buildTableRow('PR No :', 'MT20467/68', labelColor, valueColor),
                _buildTableRow(
                  'วันที่สร้าง PR :',
                  '11/12/2568 13:44:36',
                  labelColor,
                  valueColor,
                ),
                _buildTableRow(
                  'วันที่แก้ไข :',
                  '11/12/2568 13:44:36',
                  labelColor,
                  valueColor,
                ),
                _buildTableRow(
                  'วันที่ต้องการสินค้า :',
                  '11 / 12 / 2568',
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
                      'ขออนุมัติซ่อมมอเตอร์ปั๊มน้ำหอพัก\n'
                      'เนื่องจากมอเตอร์ปั๊มเดิมมอเตอร์ลงกราวด์และปั๊มน้ำใบพัดแตกเพลาใบพัดร่องลิ่มชำรุดทำให้ใช้งานไม่ได้ปัจจุบันใช้งานปั๊มตัวเล็กจึงอาจปั๊มน้ำให้ใช้งานช้าและไม่มีสแปร์เพื่อสลับ\n'
                      'เปลี่ยนใช้งานดังนั้นจึงขออนุมัติซ่อมมอเตอร์ปั๊มน้ำดังรายการ\n'
                      '1.มอเตอร์ปั๊ม STAC จำนวน 1 ตัว\n'
                      'จึงเรียนมาเพื่อขออนุมัติ',
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
                  'รายละเอียด คลิก ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: labelColor,
                  ),
                ),
                const Text(
                  'ดูรายละเอียด',
                  style: TextStyle(decoration: TextDecoration.underline),
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
                  'วัฒนะ จุไข่',
                  'อนุมัติ\n4/12/2568 13:36:45',
                  '-',
                ),
                _buildApprovalRow(
                  '2',
                  'จักรพันธุ์ บุญเพ็ง',
                  'อนุมัติ\n5/12/2568 9:29:11',
                  '-',
                ),
                _buildApprovalRow(
                  '3',
                  'วิทูล จันประทักษ์',
                  'อนุมัติ\n5/12/2568 9:36:53',
                  '-',
                ),
                _buildApprovalRow(
                  '4',
                  'สุรชัย ทองอ่อน',
                  'อนุมัติ\n6/12/2568 15:52:19',
                  '-',
                ),
                _buildApprovalRow(
                  '5',
                  'จีรัฐณัฏฐ์ กุลจิรานวัตร',
                  'อนุมัติ\n8/12/2568 13:08:36',
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
