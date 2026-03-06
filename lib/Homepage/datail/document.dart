import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'detail.dart';
import '../../Authen/authen.dart';

class DocumentPage extends StatefulWidget {
  final PurchaseItem item;
  const DocumentPage({super.key, required this.item});

  @override
  State<DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends State<DocumentPage> {
  final String _baseHost = 'http://26.99.205.41:9000/drugs';

  List<String> _fileUrls = [];
  bool _loadingFiles = false;

  List<dynamic> _approvers = [];
  bool _loadingApprovers = false;

  @override
  void initState() {
    super.initState();
    _fetchFiles();
    _fetchApprovers();
  }

  Map<String, String> _authHeaders() {
    final h = <String, String>{};
    if (Authen.token != null && Authen.token!.isNotEmpty) {
      h['Authorization'] = 'Bearer ${Authen.token}';
    }
    return h;
  }

  Future<void> _fetchFiles() async {
    final id = widget.item.id;
    if (id.isEmpty) return;
    setState(() => _loadingFiles = true);
    try {
      final resp = await http
          .get(
            Uri.parse('$_baseHost/repair-requests/$id/files'),
            headers: _authHeaders(),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        List<dynamic>? list;
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map) {
          list =
              (decoded['value'] ?? decoded['data'] ?? decoded['files'])
                  as List?;
        }
        final urls = <String>[];
        for (final item in (list ?? [])) {
          if (item is String) {
            urls.add(_normalizeUrl(item));
          } else if (item is Map) {
            for (final k in ['file_url', 'url', 'path', 'file', 'filename']) {
              if (item[k] != null) {
                urls.add(_normalizeUrl(item[k].toString()));
                break;
              }
            }
          }
        }
        if (mounted) setState(() => _fileUrls = urls);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  Future<void> _fetchApprovers() async {
    final id = widget.item.id;
    if (id.isEmpty) return;
    setState(() => _loadingApprovers = true);
    try {
      final resp = await http
          .get(
            Uri.parse('$_baseHost/repair-requests/$id/approval-steps'),
            headers: _authHeaders(),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        List<dynamic> list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map) {
          if (decoded['approval_steps'] is List) {
            list = decoded['approval_steps'];
          } else if (decoded['steps'] is List) {
            for (final step in decoded['steps'] as List) {
              if (step is Map && step['approvers'] is List) {
                for (final a in step['approvers']) {
                  if (a is Map) {
                    a['step_state'] = step['state']?.toString() ?? '';
                  }
                  list.add(a);
                }
              }
            }
          } else if (decoded['data'] is List) {
            list = decoded['data'];
          }
        }
        if (mounted) setState(() => _approvers = list);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingApprovers = false);
    }
  }

  String _normalizeUrl(String raw) {
    if (raw.startsWith('http')) return raw;
    if (raw.startsWith('/')) return '$_baseHost$raw';
    return '$_baseHost/$raw';
  }

  String _extractUsername(dynamic a) {
    if (a == null) return '-';
    if (a is String) return a;
    if (a is Map) {
      for (final k in ['username', 'user_name', 'name', 'display_name']) {
        if (a[k] is String && (a[k] as String).isNotEmpty) return a[k];
      }
    }
    return '-';
  }

  bool _isApproved(dynamic a) =>
      a['approved'] == true ||
      (a['status'] ?? a['step_state'] ?? '').toString().toLowerCase().contains(
        'approved',
      );

  bool _isRejected(dynamic a) =>
      a['approved'] == false ||
      (a['status'] ?? a['step_state'] ?? '').toString().toLowerCase().contains(
        'rejected',
      );

  String _formatDateString(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      String two(int v) => v.toString().padLeft(2, '0');
      return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
    } catch (_) {
      // try extracting date portion if already like 'YYYY-MM-DD...'
      final m = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
      if (m != null) return '${m.group(3)}/${m.group(2)}/${m.group(1)}';
      return raw;
    }
  }

  Future<void> _printDocument() async {
    final pdf = pw.Document();
    final item = widget.item;
    final raw = item.rawData ?? {};
    final requester = (raw['username'] ?? raw['user_name'] ?? item.reqBy)
        .toString();
    final dept = (raw['department_name'] ?? raw['department'] ?? item.dept)
        .toString();
    final reqDate = (raw['created_at'] ?? raw['createdAt'] ?? item.reqDate)
        .toString();
    final topic = (raw['topic'] ?? raw['description'] ?? item.topic ?? '')
        .toString();

    // determine characteristic from API (1=สร้าง,2=ปรับปรุง,3=ซ่อม)
    final charRaw =
        raw['characteristic_id'] ??
        raw['characteristicId'] ??
        raw['characteristic'];
    final int? charId = charRaw != null
        ? int.tryParse(charRaw.toString())
        : null;
    final pdfIsCreate = charId == 1 || item.type.contains('สร้าง');
    final pdfIsImprove = charId == 2 || item.type.contains('ปรับปรุง');
    final pdfIsRepair = charId == 3 || item.type.contains('ซ่อม');

    // helper used in PDF layout (defined here so build can be a simple expression)
    pw.Widget dotField(String val) => pw.Expanded(
      child: pw.Container(
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(style: pw.BorderStyle.dashed),
          ),
        ),
        child: pw.Text(val, style: pw.TextStyle(fontSize: 11)),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context ctx) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'บริษัทจรูญรัตน์ โปรดักส์ จำกัด',
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'ใบแจ้งซ่อม-สร้าง',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '(Maintenance Requisition Sheet)',
                      style: pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'MT No. : ${item.no}',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 6),

              // ลักษณะงาน
              pw.Row(
                children: [
                  pw.Text(
                    'ลักษณะงาน  ',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    '○ งานซ่อมทั่วไป    ',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Text(
                    '○ งานซ่อม Hanger',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  pw.Spacer(),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(style: pw.BorderStyle.dashed),
                    ),
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          pdfIsCreate ? '● สร้าง' : '○ สร้าง',
                          style: pw.TextStyle(fontSize: 9),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Text(
                          pdfIsImprove ? '● ปรับปรุง' : '○ ปรับปรุง',
                          style: pw.TextStyle(fontSize: 9),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Text(
                          pdfIsRepair ? '● ซ่อม' : '○ ซ่อม',
                          style: pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),

              // ผู้ร้อง / แผนก
              pw.Row(
                children: [
                  pw.Text(
                    'ผู้ร้อง/ผู้ส่งคำขอ  ',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  dotField(requester),
                  pw.SizedBox(width: 12),
                  pw.Text(
                    'แผนก  ',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  dotField(dept),
                ],
              ),
              pw.SizedBox(height: 4),

              // วันที่ / กำหนด
              pw.Row(
                children: [
                  pw.Text(
                    'วันที่ส่งคำขอ  ',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  dotField(_formatDateString(reqDate)),
                  pw.SizedBox(width: 12),
                  pw.Text(
                    'กำหนดเสร็จภายในวันที่  ',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  dotField(item.prDate),
                ],
              ),
              pw.SizedBox(height: 8),

              // หัวข้อรายการ
              pw.Center(
                child: pw.Text(
                  'รายการรายละเอียดของงาน',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ),
              pw.SizedBox(height: 6),

              // 2-Column Layout
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Container(
                      decoration: pw.BoxDecoration(border: pw.Border.all()),
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'ภาพประกอบ',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                              decoration: pw.TextDecoration.underline,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Container(
                            height: 120,
                            color: PdfColors.grey200,
                            child: pw.Center(
                              child: pw.Text(
                                '(รูปภาพประกอบ)',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.grey600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    flex: 6,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(topic, style: pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 6),
                        ...List.generate(
                          6,
                          (_) => pw.Column(
                            children: [
                              pw.Container(
                                height: 14,
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(
                                    bottom: pw.BorderSide(
                                      style: pw.BorderStyle.dashed,
                                    ),
                                  ),
                                ),
                              ),
                              pw.SizedBox(height: 2),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Approval Table
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(2.5),
                  2: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Center(
                          child: pw.Text(
                            'Fac.Mgr.',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Center(
                          child: pw.Text(
                            'Fac.Mgr./MKTDir./HR.Dir.',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Center(
                          child: pw.Text(
                            'Div.Mgr./Line Mgr.',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: List.generate(3, (i) {
                      final name = i < _approvers.length
                          ? _extractUsername(_approvers[i])
                          : '';
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 4,
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            name,
                            style: pw.TextStyle(fontSize: 9),
                          ),
                        ),
                      );
                    }),
                  ),
                  pw.TableRow(
                    children: List.generate(3, (i) {
                      final a = i < _approvers.length ? _approvers[i] : null;
                      final approved = a != null ? _isApproved(a) : false;
                      final rejected = a != null ? _isRejected(a) : false;
                      return pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(
                              children: [
                                pw.Text(
                                  approved ? '● ' : '○ ',
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                                pw.Text(
                                  'อนุมัติ',
                                  style: pw.TextStyle(fontSize: 9),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 2),
                            pw.Row(
                              children: [
                                pw.Text(
                                  rejected ? '● ' : '○ ',
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                                pw.Text(
                                  'ไม่อนุมัติ',
                                  style: pw.TextStyle(fontSize: 9),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      format: PdfPageFormat.a4,
      onLayout: (format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final raw = item.rawData ?? {};
    final requester = (raw['username'] ?? raw['user_name'] ?? item.reqBy)
        .toString();
    final dept = (raw['department_name'] ?? raw['department'] ?? item.dept)
        .toString();
    final reqDate = (raw['created_at'] ?? raw['createdAt'] ?? item.reqDate)
        .toString();
    const Color blue = Color(0xFF1976D2);

    // resolve characteristic from API for UI ticking (1=สร้าง,2=ปรับปรุง,3=ซ่อม)
    final charRaw =
        raw['characteristic_id'] ??
        raw['characteristicId'] ??
        raw['characteristic'];
    final int? charId = charRaw != null
        ? int.tryParse(charRaw.toString())
        : null;
    final isCreate = charId == 1 || item.type.contains('สร้าง');
    final isImprove = charId == 2 || item.type.contains('ปรับปรุง');
    final isRepair = charId == 3 || item.type.contains('ซ่อม');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        title: const Text(
          'เอกสาร',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'พิมพ์เอกสาร',
            onPressed: (_loadingApprovers || _loadingFiles)
                ? null
                : _printDocument,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //Company Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: const [
                        Text(
                          'บริษัทจรูญรัตน์ โปรดักส์ จำกัด',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'ใบแจ้งซ่อม-สร้าง',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '(Maintenance Requisition Sheet)',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'MT No. :',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(item.no, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const Divider(thickness: 1.2),

              // ── Job Type Section ─────────────────────────────────────────────────────────────
              Row(
                children: [
                  const Text(
                    'ลักษณะงาน',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  _radioOption(
                    'งานซ่อมทั่วไป',
                    !item.type.toLowerCase().contains('hanger'),
                  ),
                  const SizedBox(width: 12),
                  _radioOption(
                    'งานซ่อม Hanger',
                    item.type.toLowerCase().contains('hanger'),
                  ),
                  const Spacer(),
                  // Dashed Status Box
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade700, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _diamondStatus('สร้าง', isCreate),
                        _arrowSep(),
                        _diamondStatus('ปรับปรุง', isImprove),
                        _arrowSep(),
                        _diamondStatus('ซ่อม', isRepair),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Requester / Department ─────────────────────────────────────────────────────────────
              Row(
                children: [
                  const Text(
                    'ผู้ร้อง/ผู้ส่งคำขอ  ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Expanded(child: _dotField(requester)),
                  const SizedBox(width: 16),
                  const Text(
                    'แผนก  ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Expanded(child: _dotField(dept)),
                ],
              ),
              const SizedBox(height: 6),

              // ── Date Section ─────────────────────────────────────────────────────────────
              Row(
                children: [
                  const Text(
                    'วันที่ส่งคำขอ  ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Expanded(child: _dotField(_formatDateString(reqDate))),
                  const SizedBox(width: 16),
                  const Text(
                    'กำหนดเสร็จภายในวันที่  ',
                    style: TextStyle(fontSize: 12),
                  ),
                  Expanded(child: _dotField(item.prDate)),
                ],
              ),
              const SizedBox(height: 14),

              // ── Section Title ─────────────────────────────────────────────────────────────
              Center(
                child: Text(
                  'รายการรายละเอียดของงาน',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                    color: blue,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── 2-Column Layout ─────────────────────────────────────────────────────────────
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left: ภาพประกอบ
                    Expanded(
                      flex: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Text(
                              'ภาพประกอบ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                                color: blue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_loadingFiles)
                              const SizedBox(
                                height: 120,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_fileUrls.isEmpty)
                              Container(
                                height: 120,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Text(
                                    'ไม่มีภาพประกอบ',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              Column(
                                children: _fileUrls
                                    .map(
                                      (url) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: GestureDetector(
                                          onTap: () =>
                                              _showFullImage(context, url),
                                          child: Image.network(
                                            url,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                  Icons.broken_image,
                                                  size: 60,
                                                ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Right: description + dotted lines
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.topic,
                            style: const TextStyle(fontSize: 12, height: 1.6),
                          ),
                          const SizedBox(height: 6),
                          ...List.generate(8, (_) => _dottedLine()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Approval Table ─────────────────────────────────────────────────────────────
              Table(
                border: TableBorder.all(color: Colors.grey.shade500),
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(2.5),
                  2: FlexColumnWidth(2),
                },
                children: [
                  // Role headers
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade200),
                    children: [
                      _roleHeader('Fac.Mgr.'),
                      _roleHeader('Fac.Mgr./MKTDir./HR.Dir.'),
                      _roleHeader('Div.Mgr./Line Mgr.'),
                    ],
                  ),
                  // Approver names
                  TableRow(
                    children: List.generate(3, (i) {
                      final name = i < _approvers.length
                          ? _extractUsername(_approvers[i])
                          : '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        child: Center(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  // Approval status / Rejection status
                  TableRow(
                    children: List.generate(3, (i) {
                      final a = i < _approvers.length ? _approvers[i] : null;
                      final approved = a != null && _isApproved(a);
                      final rejected = a != null && _isRejected(a);
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _approvalRadio('อนุมัติ', approved),
                            const SizedBox(height: 4),
                            _approvalRadio('ไม่อนุมัติ', rejected),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_loadingApprovers || _loadingFiles) ? null : _printDocument,
        backgroundColor: blue,
        icon: const Icon(Icons.print, color: Colors.white),
        label: const Text(
          'พิมพ์เอกสาร',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            maxScale: 5.0,
            child: Image.network(
              url,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, size: 64),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────────

  /// Widget for radio button + label
  Widget _radioOption(String label, bool selected) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: 17,
        color: selected ? const Color(0xFF1976D2) : Colors.grey.shade600,
      ),
      const SizedBox(width: 3),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );

  /// ◇ Diamond shape + label
  Widget _diamondStatus(String label, bool active) {
    const blue = Color(0xFF1976D2);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? blue : Colors.transparent,
            border: Border.all(
              width: 1.5,
              color: active ? blue : Colors.grey.shade500,
            ),
          ),
          child: active
              ? const Icon(Icons.check, size: 12, color: Colors.white)
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? blue : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _arrowSep() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 4),
    child: Text('›', style: TextStyle(fontSize: 16, color: Colors.grey)),
  );

  Widget _dotField(String value) => Container(
    margin: const EdgeInsets.only(bottom: 2),
    decoration: const BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: Colors.black54,
          width: 0.8,
          style: BorderStyle.solid,
        ),
      ),
    ),
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      value,
      style: const TextStyle(fontSize: 12),
      overflow: TextOverflow.ellipsis,
    ),
  );

  Widget _dottedLine() => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: List.generate(
        60,
        (_) => Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            color: Colors.grey.shade400,
          ),
        ),
      ),
    ),
  );

  /// Header cell for approval
  Widget _roleHeader(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    ),
  );

  /// Radio button for approval
  Widget _approvalRadio(String label, bool selected) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: 16,
        color: selected
            ? (label == 'อนุมัติ' ? Colors.green : Colors.red)
            : Colors.grey.shade500,
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}
