import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../Authen/authen.dart';

class CloseJobButton extends StatefulWidget {
  // Accept a dynamic item (from detail page) to avoid circular imports
  final dynamic item;
  const CloseJobButton({super.key, required this.item});

  @override
  State<CloseJobButton> createState() => _CloseJobButtonState();
}

class _CloseJobButtonState extends State<CloseJobButton> {
  final String _baseHost = 'http://26.99.205.41:9000/drugs';
  bool _loading = false;

  Map<String, String> _authHeaders({bool json = false}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (Authen.token != null && Authen.token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${Authen.token}';
    }
    return headers;
  }

  Future<String?> _resolveIdFromList() async {
    try {
      final uri = Uri.parse('$_baseHost/repair-requests');
      final resp = await http
          .get(uri, headers: _authHeaders())
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      List<dynamic>? list;
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map && decoded['data'] is List)
        list = decoded['data'];
      if (list == null || list.isEmpty) return null;

      final targetNo = widget.item?.no;
      final targetTopic = widget.item?.topic;

      for (final entry in list) {
        if (entry is! Map) continue;
        final entryId = entry['id']?.toString();
        if (entryId == null) continue;
        if (targetNo != null && targetNo != 'N/A') {
          final candidates = [entry['no'], entry['pr_no'], entry['job_no']];
          for (final c in candidates) {
            if (c != null && c.toString() == targetNo) return entryId;
          }
        }
        if (targetTopic != null && targetTopic != 'N/A') {
          final t = entry['topic'] ?? entry['title'] ?? entry['description'];
          if (t != null && t.toString() == targetTopic) return entryId;
        }
      }
      final first = list.first;
      if (first is Map && first['id'] != null) return first['id'].toString();
    } catch (e) {
      debugPrint('resolveId error: $e');
    }
    return null;
  }

  Future<void> _closeRequest(String? id) async {
    if (id == null || id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบรหัสคำขอที่ต้องการปิดงาน')),
        );
      }
      return;
    }

    setState(() => _loading = true);
    // Prefer technician-finish endpoint used by technicians
    final uriTechFinish = Uri.parse(
      '$_baseHost/repair-requests/$id/technician-finish',
    );
    final uriPrimary = Uri.parse('$_baseHost/repair-requests/$id/close');
    final uriAlt = Uri.parse('$_baseHost/repair-requests/$id/complete');
    final headers = _authHeaders(json: true);
    final body = jsonEncode({'closed': true});

    try {
      // 0) Try technician-finish (PATCH)
      try {
        final respTech = await http
            .patch(uriTechFinish, headers: headers, body: body)
            .timeout(const Duration(seconds: 10));
        debugPrint(
          'PATCH technician-finish -> ${respTech.statusCode} ${respTech.body}',
        );
        if (respTech.statusCode == 200 ||
            respTech.statusCode == 201 ||
            respTech.statusCode == 204) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ส่งงานเรียบร้อยแล้ว')),
            );
            Navigator.of(context).pop(true);
          }
          return;
        }
      } catch (e) {
        debugPrint('Technician-finish PATCH error: $e');
      }
      // Try PATCH
      try {
        final resp = await http
            .patch(uriPrimary, headers: headers, body: body)
            .timeout(const Duration(seconds: 10));
        debugPrint('PATCH close -> ${resp.statusCode} ${resp.body}');
        if (resp.statusCode == 200 ||
            resp.statusCode == 201 ||
            resp.statusCode == 204) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ปิดงานเรียบร้อยแล้ว')),
            );
            Navigator.of(context).pop(true);
          }
          return;
        }
      } catch (e) {
        debugPrint('Primary PATCH close error: $e');
      }

      // Try POST to same endpoint
      try {
        final r2 = await http
            .post(uriPrimary, headers: headers, body: body)
            .timeout(const Duration(seconds: 10));
        debugPrint('POST close -> ${r2.statusCode} ${r2.body}');
        if (r2.statusCode == 200 ||
            r2.statusCode == 201 ||
            r2.statusCode == 204) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ปิดงานเรียบร้อยแล้ว')),
            );
            Navigator.of(context).pop(true);
          }
          return;
        }
      } catch (e) {
        debugPrint('POST close error: $e');
      }

      // Try alternate complete endpoint
      try {
        final r3 = await http
            .post(uriAlt, headers: headers, body: body)
            .timeout(const Duration(seconds: 10));
        debugPrint('POST complete -> ${r3.statusCode} ${r3.body}');
        if (r3.statusCode == 200 ||
            r3.statusCode == 201 ||
            r3.statusCode == 204) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ปิดงานเรียบร้อยแล้ว')),
            );
            Navigator.of(context).pop(true);
          }
          return;
        }
      } catch (e) {
        debugPrint('Alt complete error: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่สามารถปิดงานได้ (ติดต่อ API ไม่สำเร็จ)'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error closing request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เกิดข้อผิดพลาดในการปิดงาน')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayItem = widget.item;
    final lowerStatus = (displayItem?.status ?? '').toString().toLowerCase();
    final alreadyClosed =
        lowerStatus.contains('จบ') || lowerStatus.contains('เสร็จ');
    if (alreadyClosed) return const SizedBox();

    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        ),
        onPressed: _loading
            ? null
            : () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('ยืนยันปิดงาน'),
                    content: const Text(
                      'ต้องการปิดงานนี้และทำเครื่องหมายว่าเสร็จแล้วใช่หรือไม่?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('ยกเลิก'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('ส่งงาน'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  String? id;
                  try {
                    id = displayItem?.id?.toString();
                  } catch (_) {}
                  if (id == null || id.isEmpty) {
                    final raw = displayItem?.rawData;
                    if (raw != null) {
                      id =
                          raw['id']?.toString() ??
                          raw['repair_request_id']?.toString();
                    }
                  }
                  if (id == null || id.isEmpty) id = await _resolveIdFromList();
                  await _closeRequest(id);
                }
              },
        child: _loading
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'ส่งงาน',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
