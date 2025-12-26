import 'package:flutter/material.dart';

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
  String? _supplier = '-';
  String _nature = 'สร้าง';
  String _category = 'ไฟฟ้า';

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
            // 1. Report By Section
            // ------------------------------------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 100,
                  child: Text(
                    'Report By :',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Column(
                  children: [
                    Container(
                      width: 80,
                      height: 100,
                      color: Colors.blue[100],
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.blue,
                      ), // Placeholder รูปภาพ
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'User Name',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),

            // ------------------------------------------------
            // 2. No. Input
            // ------------------------------------------------
            _buildTextFieldRow(label: 'No. :', initialValue: 'IMD00612/68'),

            // ------------------------------------------------
            // 3. Priority Section
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
                      Padding(
                        padding: const EdgeInsets.only(left: 30.0, top: 4),
                        child: Row(
                          children: [
                            const Text('-ระยะเวลาที่ต้องการของ '),
                            SizedBox(
                              width: 50,
                              height: 30,
                              child: TextField(
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 0,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(0),
                                  ),
                                  fillColor: Colors.white,
                                  filled: true,
                                ),
                              ),
                            ),
                            const Text(' วัน'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ------------------------------------------------
            // 4. Supplier Section
            // ------------------------------------------------
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 100,
                  child: Text(
                    'Location :',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildSimpleRadio(
                            val: 'JRP',
                            group: _supplier,
                            onChanged: (v) => setState(() => _supplier = v),
                          ),
                          const Text('JRP'),
                          const SizedBox(width: 20),
                          _buildSimpleRadio(
                            val: 'JRPE',
                            group: _supplier,
                            onChanged: (v) => setState(() => _supplier = v),
                          ),
                          const Text('JRPE'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ------------------------------------------------
            // 5. Request Date
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
                _buildDropdownMock('11'),
                const Text(' / '),
                _buildDropdownMock('ธันวาคม'),
                const Text(' / '),
                _buildDropdownMock('2568'),
                const SizedBox(width: 5),
                const Text(
                  '(วันที่ร้องขอ)',
                  style: TextStyle(color: Colors.blue),
                ),
              ],
            ),

            // ------------------------------------------------
            // 6. Department & Topic
            // ------------------------------------------------
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(
                  width: 100,
                  child: Text(
                    'Department :',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Text('IMD'),
              ],
            ),

            // ------------------------------------------------
            // 9. ลักษณะ และ หมวดหมู่ที่ซ่อม
            // ------------------------------------------------
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(
                  width: 100,
                  child: Text(
                    'ลักษณะ :',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _nature,
                      items: ['สร้าง', 'ซ่อม', 'สั่งทำ']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _nature = v!),
                    ),
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
                    'หมวดหมู่ที่ซ่อม :',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _category,
                      items:
                          [
                                'ไฟฟ้า',
                                'ปะปา',
                                'แอร์',
                                'อินเตอร์เน็ต',
                                'รถยนต์/โฟล์คลิฟท์',
                                'หอพัก',
                                'เครื่องจักร',
                                'อื่นๆ',
                              ]
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildTextFieldRow(label: 'หัวข้อ :'),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey),
              ),
              child: Column(
                children: [
                  // Text Area
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: TextField(
                        maxLines: null,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'รายละเอียด',
                        ),
                      ),
                    ),
                  ),
                ],
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

  // สร้าง Radio ธรรมดา
  Widget _buildSimpleRadio({
    required String val,
    required String? group,
    required Function(String?) onChanged,
  }) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Radio<String>(value: val, groupValue: group, onChanged: onChanged),
    );
  }

  // สร้าง Row แบบ Label : Input Field
  Widget _buildTextFieldRow({required String label, String? initialValue}) {
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

  // Mock Dropdown วันที่
  Widget _buildDropdownMock(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: Row(
        children: [
          Text(text),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    );
  }
}
