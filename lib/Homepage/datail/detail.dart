// ignore_for_file: dead_code, unused_field, unused_element, unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'remark.dart';
import '../../Authen/authen.dart';
import 'closejob.dart';
import 'document.dart';
import 'usercheck.dart';
import '../home.dart';

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
  final String _baseHost = 'http://26.99.205.41:9000/drugs';
  List<String> _fileUrls = [];
  bool _loadingFiles = false;
  String? _currentFetchId;
  String? _currentFetchUri;

  List<dynamic> _comments = [];
  bool _loadingComments = false;
  List<dynamic> _approvers = [];
  bool _loadingApprovers = false;
  String? _currentRepairRequestId;

  @override
  void initState() {
    super.initState();
    _loadFilesForItem();
    _loadCommentsForItem();
    _loadApproversForItem();
  }

  Future<void> _loadApproversForItem() async {
    String? id;

    if (widget.item != null && widget.item!.id.isNotEmpty) {
      id = widget.item!.id;
      debugPrint('Using item.id from navigation (approvers): $id');
    }
    if (id == null || id.isEmpty) {
      final raw = widget.item?.rawData;
      if (raw != null) {
        id = raw['id']?.toString() ?? raw['repair_request_id']?.toString();
        debugPrint('Using rawData id (approvers): $id');
      }
    }
    if (id == null || id.isEmpty) {
      debugPrint('ERROR: No ID provided for fetching approvers!');
      return;
    }
    debugPrint('Fetching approvers for id: $id');
    _currentRepairRequestId = id;
    await _fetchApproversForId(id);
  }

  Future<void> _fetchApproversForId(String id) async {
    // Use the approval-steps endpoint per request
    final uri = Uri.parse('$_baseHost/repair-requests/$id/approval-steps');
    setState(() {
      _loadingApprovers = true;
    });
    try {
      final resp = await http
          .get(uri, headers: _authHeaders())
          .timeout(const Duration(seconds: 10));
      debugPrint('Approval-steps API response status: ${resp.statusCode}');
      debugPrint('Approval-steps API response body: ${resp.body}');
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        List<dynamic> list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map) {
          // Try common API response keys
          if (decoded['approval_steps'] is List) {
            list = decoded['approval_steps'];
          } else if (decoded['approvalSteps'] is List) {
            list = decoded['approvalSteps'];
          } else if (decoded['steps'] is List) {
            // Extract approvers from all steps and attach step state to each approver
            final steps = decoded['steps'] as List;
            for (final step in steps) {
              if (step is Map && step['approvers'] is List) {
                final stepState = step['state']?.toString() ?? '';
                for (final approver in step['approvers']) {
                  if (approver is Map) {
                    // Add step_state to each approver so we know which step they belong to
                    approver['step_state'] = stepState;
                  }
                  list.add(approver);
                }
              }
            }
          } else if (decoded['data'] is List) {
            list = decoded['data'];
          } else if (decoded['value'] is List) {
            list = decoded['value'];
          }
        }
        debugPrint('Parsed approval steps: $list');
        if (mounted) setState(() => _approvers = list);
        // Debug: log each approver's extracted username
        for (int i = 0; i < list.length; i++) {
          final extracted = _extractUsername(list[i]);
          debugPrint('Approver[$i] username: $extracted | raw: ${list[i]}');
        }
      }
    } catch (e) {
      debugPrint('Error fetching approvers: $e');
    } finally {
      if (mounted) setState(() => _loadingApprovers = false);
    }
  }

  Future<void> _sendApproverAction(
    int idx,
    String approverId,
    bool approve,
  ) async {
    if (_currentRepairRequestId == null) {
      debugPrint('No repairRequestId available for approver action');
      return;
    }
    final Map<String, dynamic> bodyMap = {'approved': approve};
    if (Authen.requesterId != null) bodyMap['user_id'] = Authen.requesterId;
    // Primary endpoint requested by backend: POST /drugs/repair-requests/{id}/approve
    final primaryApproveUri = Uri.parse(
      '$_baseHost/repair-requests/$_currentRepairRequestId/approve',
    );
    final approversUri = Uri.parse(
      '$_baseHost/repair-requests/$_currentRepairRequestId/approvers/$approverId',
    );
    final altApproveUri = Uri.parse(
      '$_baseHost/repair-requests/$_currentRepairRequestId/approvers/$approverId/approve',
    );
    final bodyWithApprover = Map<String, dynamic>.from(bodyMap);
    bodyWithApprover['approver_id'] = approverId;
    final bodyPrimary = jsonEncode(bodyWithApprover);
    final body = jsonEncode(bodyMap);
    final headers = _authHeaders(json: true);

    Future<bool> handleSuccess() async {
      if (!mounted) return false;
      setState(() {
        final now = DateTime.now().toIso8601String();
        _approvers[idx]['approved'] = approve;
        _approvers[idx]['approved_at'] = now;
        _approvers[idx]['status'] = approve ? 'approved' : 'rejected';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'อนุมัติสำเร็จ' : 'ไม่อนุมัติสำเร็จ')),
      );
      // If this was an approval action, navigate back to the home list and
      // replace this detail page so the home will reload once.
      if (approve) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (ctx) => const PurchaseReportPage()),
        );
      }
      return true;
    }

    try {
      // 1) Try PATCH to /repair-requests/{id}/approve (primary requested)
      try {
        debugPrint('Primary PATCH /approve URI: $primaryApproveUri');
        debugPrint('Primary PATCH /approve headers: $headers');
        debugPrint('Primary PATCH /approve body: $bodyPrimary');
        final pResp = await http
            .patch(primaryApproveUri, headers: headers, body: bodyPrimary)
            .timeout(const Duration(seconds: 10));
        debugPrint(
          'Primary PATCH /approve response: ${pResp.statusCode} ${pResp.body}',
        );
        if (pResp.statusCode == 200 ||
            pResp.statusCode == 201 ||
            pResp.statusCode == 204) {
          await handleSuccess();
          return;
        }
      } catch (e) {
        debugPrint('Primary PATCH /approve error: $e');
      }

      // 2) Try PATCH to approvers/{approverId}
      try {
        final resp = await http
            .patch(approversUri, headers: headers, body: body)
            .timeout(const Duration(seconds: 10));
        debugPrint('Approvers PATCH response: ${resp.statusCode} ${resp.body}');
        if (resp.statusCode == 200 ||
            resp.statusCode == 201 ||
            resp.statusCode == 204) {
          await handleSuccess();
          return;
        }

        // If server replies 404 or method not allowed, try POST to approvers/{id}/approve
        if (resp.statusCode == 404 || resp.statusCode == 405) {
          try {
            final r2 = await http
                .post(altApproveUri, headers: headers, body: body)
                .timeout(const Duration(seconds: 10));
            debugPrint(
              'Alt POST approvers/{id}/approve response: ${r2.statusCode} ${r2.body}',
            );
            if (r2.statusCode == 200 ||
                r2.statusCode == 201 ||
                r2.statusCode == 204) {
              await handleSuccess();
              return;
            }
          } catch (e) {
            debugPrint('Alt POST approvers/{id}/approve error: $e');
          }
        }
      } catch (e) {
        debugPrint('Approvers PATCH error: $e');
      }

      // If we reach here, no endpoint succeeded
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('การอัปเดตสถานะล้มเหลว (ไม่สามารถติดต่อ API ได้)'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending approver action: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เกิดข้อผิดพลาด เชื่อมต่อไม่สำเร็จ')),
        );
      }
    }
  }

  Future<void> _approveApproverAt(int idx) async {
    final approver = _approvers[idx];
    // approver user id in the list (could be 'id' or 'user_id' depending on API)
    final approverUserIdRaw =
        (approver['id'] ??
        approver['user_id'] ??
        approver['approver_id'] ??
        approver['approverId']);
    if (approverUserIdRaw == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่พบรหัสผู้อนุมัติ')));
      return;
    }

    final approverUserId = approverUserIdRaw.toString();
    final loggedUserId = Authen.requesterId;
    if (loggedUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาล็อกอินก่อนทำรายการ')));
      return;
    }

    // If logged in user id does not match approver id for this row, deny permission
    if (approverUserId != loggedUserId.toString()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('คุณไม่มีสิทอนุมัตินี้')));
      return;
    }
    // Use approver-specific approvers/{approverId} endpoint (PATCH) to approve.
    final approverId =
        (approver['id'] ??
                approver['approver_id'] ??
                approver['user_id'] ??
                approver['approverId'])
            ?.toString();
    if (approverId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่พบรหัสผู้อนุมัติ')));
      return;
    }

    await _sendApproverAction(idx, approverId, true);
  }

  Future<void> _rejectApproverAt(int idx) async {
    final approver = _approvers[idx];
    // approver user id in the list (could be 'id' or 'user_id' depending on API)
    final approverUserIdRaw =
        (approver['id'] ??
        approver['user_id'] ??
        approver['approver_id'] ??
        approver['approverId']);
    if (approverUserIdRaw == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่พบรหัสผู้อนุมัติ')));
      return;
    }

    final approverUserId = approverUserIdRaw.toString();
    final loggedUserId = Authen.requesterId;
    if (loggedUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาล็อกอินก่อนทำรายการ')));
      return;
    }

    // If logged in user id does not match approver id for this row, deny permission
    if (approverUserId != loggedUserId.toString()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('คุณไม่มีสิทอนุมัตินี้')));
      return;
    }
    // Use approver-specific approvers/{approverId} endpoint (PATCH) to reject.
    final approverId =
        (approver['id'] ??
                approver['approver_id'] ??
                approver['user_id'] ??
                approver['approverId'])
            ?.toString();
    if (approverId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่พบรหัสผู้อนุมัติ')));
      return;
    }
    // Open remark dialog first and require a remark before rejecting
    final repairId = _currentRepairRequestId;
    if (repairId == null || repairId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบข้อมูลรายการ เพื่อส่งการไม่อนุมัติ'),
        ),
      );
      return;
    }

    final result = await showRemarkDialog(context, repairRequestId: repairId);
    if (result == null) {
      // user cancelled
      return;
    }
    final remark = (result['remark'] as String?) ?? '';

    // Call the reject endpoint: PATCH /repair-requests/{id}/reject
    final uri = Uri.parse('$_baseHost/repair-requests/$repairId/reject');
    final headers = _authHeaders(json: true);
    final bodyMap = <String, dynamic>{};
    if (Authen.requesterId != null) bodyMap['user_id'] = Authen.requesterId;
    if (remark.isNotEmpty) bodyMap['remark'] = remark;

    try {
      final resp = await http
          .patch(uri, headers: headers, body: jsonEncode(bodyMap))
          .timeout(const Duration(seconds: 10));
      debugPrint('Reject PATCH response: ${resp.statusCode} ${resp.body}');
      if (resp.statusCode == 200 ||
          resp.statusCode == 201 ||
          resp.statusCode == 204) {
        if (!mounted) return;
        setState(() {
          final now = DateTime.now().toIso8601String();
          _approvers[idx]['approved'] = false;
          _approvers[idx]['approved_at'] = now;
          _approvers[idx]['status'] = 'rejected';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ไม่อนุมัติสำเร็จ')));
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('การไม่อนุมัติล้มเหลว')));
    } catch (e) {
      debugPrint('Error calling reject endpoint: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาด ขณะส่งคำขอไม่อนุมัติ')),
      );
    }
  }

  // Handle requester acceptance (user inspection passed) by calling
  // POST /drugs/repair-requests/{id}/requester-accept
  Future<void> _handleRequesterAccept() async {
    String? id = _currentRepairRequestId ?? widget.item?.id;
    if (id == null || id.isEmpty) id = await _resolveIdFromList();
    if (id == null || id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบ ID สำหรับส่งการตรวจรับ')),
        );
      }
      return;
    }

    final uri = Uri.parse('$_baseHost/repair-requests/$id/requester-accept');
    final headers = _authHeaders(json: true);

    final bodyMap = <String, dynamic>{};
    if (Authen.requesterId != null) bodyMap['user_id'] = Authen.requesterId;
    // include raw item data to help server process the submission
    if (widget.item?.rawData != null) {
      bodyMap['data'] = widget.item!.rawData;
    }

    try {
      // Prefer PATCH as shown in the API screenshot. If PATCH not supported, fall back to POST.
      try {
        debugPrint('PATCH requester-accept URI: $uri');
        debugPrint('PATCH headers: $headers');
        debugPrint('PATCH body: ${jsonEncode(bodyMap)}');
        final pResp = await http
            .patch(uri, headers: headers, body: jsonEncode(bodyMap))
            .timeout(const Duration(seconds: 10));
        debugPrint('PATCH response: ${pResp.statusCode} ${pResp.body}');
        if (pResp.statusCode == 200 ||
            pResp.statusCode == 201 ||
            pResp.statusCode == 204) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ส่งการตรวจรับสำเร็จ'),
                backgroundColor: Colors.green,
              ),
            );
            await _loadApproversForItem();
            await _loadCommentsForItem();
          }
          return;
        }
      } catch (e) {
        debugPrint('PATCH requester-accept error: $e');
      }

      // fallback to POST if PATCH failed
      try {
        debugPrint('POST requester-accept URI: $uri');
        final resp = await http
            .post(uri, headers: headers, body: jsonEncode(bodyMap))
            .timeout(const Duration(seconds: 10));
        debugPrint('POST response: ${resp.statusCode} ${resp.body}');
        if (resp.statusCode == 200 ||
            resp.statusCode == 201 ||
            resp.statusCode == 204) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ส่งการตรวจรับสำเร็จ'),
                backgroundColor: Colors.green,
              ),
            );
            await _loadApproversForItem();
            await _loadCommentsForItem();
          }
          return;
        }
      } catch (e) {
        debugPrint('POST requester-accept error: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('การส่งการตรวจรับล้มเหลว')),
        );
      }
    } catch (e) {
      debugPrint('Error calling requester-accept: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เกิดข้อผิดพลาด ขณะส่งการตรวจรับ')),
        );
      }
    }
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
      final uri = Uri.parse('$_baseHost/repair-requests');
      final resp = await http
          .get(uri, headers: _authHeaders())
          .timeout(const Duration(seconds: 10));
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
    final uri = Uri.parse('$_baseHost/repair-requests/$id/files');
    setState(() {
      _loadingFiles = true;
      _currentFetchId = id;
      _currentFetchUri = uri.toString();
    });
    try {
      final resp = await http
          .get(uri, headers: _authHeaders())
          .timeout(const Duration(seconds: 10));
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
    } finally {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  Future<void> _fetchCommentsForId(String id) async {
    final uri = Uri.parse('$_baseHost/repair-requests/$id/comments');
    setState(() {
      _loadingComments = true;
    });
    try {
      final resp = await http
          .get(uri, headers: _authHeaders())
          .timeout(const Duration(seconds: 10));
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

        // Normalize/collect attachments (images/files) for each comment so UI can display them.
        List<String> _collectImageStrings(dynamic node) {
          final exts = ['.png', '.jpg', '.jpeg', '.gif', '.webp'];
          final out = <String>[];
          void walk(dynamic n) {
            if (n == null) return;
            if (n is String) {
              final low = n.toLowerCase();
              for (final e in exts) {
                if (low.contains(e)) {
                  out.add(n);
                  return;
                }
              }
              if (low.startsWith('http')) out.add(n);
              return;
            }
            if (n is Map) {
              for (final v in n.values) walk(v);
              return;
            }
            if (n is List) {
              for (final v in n) walk(v);
              return;
            }
          }

          walk(node);
          return out;
        }

        for (var i = 0; i < commentList.length; i++) {
          final c = commentList[i];
          final attachments = <String>[];
          if (c is Map) {
            // Common keys containing attachments
            final keys = ['attachments', 'files', 'images', 'media'];
            for (final k in keys) {
              if (c[k] is List) {
                for (final e in c[k]) {
                  if (e is String && e.isNotEmpty)
                    attachments.add(e);
                  else if (e is Map) {
                    for (final cand in [
                      'file',
                      'path',
                      'url',
                      'src',
                      'location',
                    ]) {
                      if (e[cand] != null) {
                        attachments.add(e[cand].toString());
                        break;
                      }
                    }
                  }
                }
              } else if (c[k] is String) {
                final s = c[k] as String;
                if (s.contains(',')) {
                  attachments.addAll(
                    s
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty),
                  );
                } else if (s.isNotEmpty) {
                  attachments.add(s);
                }
              }
            }

            // If not found via common keys, try to collect any image-like strings inside the comment object
            if (attachments.isEmpty) {
              final found = _collectImageStrings(c);
              attachments.addAll(found);
            }

            // Normalize URLs/paths and remove empties/duplicates
            final normalized = <String>[];
            for (final a in attachments) {
              final s = a.toString();
              if (s.isEmpty) continue;
              final url = _normalizeUrl(s);
              if (!normalized.contains(url)) normalized.add(url);
            }

            // attach to comment map for UI usage
            try {
              c['attachments'] = normalized;
            } catch (_) {}
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

  // Build headers including Authorization token when available
  Map<String, String> _authHeaders({bool json = false}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (Authen.token != null && Authen.token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${Authen.token}';
    }
    return headers;
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

  // Robustly extract a username string from an approver object
  String _extractUsername(dynamic approver) {
    if (approver == null) return 'ไม่มีข้อมูล';
    // direct keys
    final candidates = [
      'username',
      'user_name',
      'name',
      'display_name',
      'approver_name',
      'user',
      'requester',
    ];

    if (approver is String) return approver;
    if (approver is Map) {
      for (final k in candidates) {
        if (approver[k] != null) {
          final v = approver[k];
          if (v is String && v.isNotEmpty) return v;
          if (v is Map && v['username'] != null) {
            return v['username'].toString();
          }
        }
      }
      // check nested common containers
      for (final nk in ['user', 'approver', 'account', 'person']) {
        if (approver[nk] is Map) {
          final m = approver[nk] as Map;
          if (m['username'] != null) return m['username'].toString();
          if (m['name'] != null) return m['name'].toString();
        }
      }
      // last resort: try first string value
      for (final v in approver.values) {
        if (v is String && v.isNotEmpty) return v;
      }
    }
    return 'ไม่มีข้อมูล';
  }

  String _formatCreatedAt(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/$y\n$hh:$mm';
    } catch (_) {
      final date = _formatCreatedDateOnly(raw);
      final time = _formatCreatedTimeOnly(raw);
      if (time == '-' || time.isEmpty) return date;
      if (date == raw) return '$raw\nเวลา: $time';
      return '$date\nเวลา: $time';
    }
  }

  // Return date part (DD/MM/YYYY) from a datetime string, or the original/fallback
  String _formatCreatedDateOnly(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$d/$m/$y';
    } catch (_) {
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

  // Return time part (HH:MM) from a datetime string, or '-' if not found
  String _formatCreatedTimeOnly(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    } catch (_) {
      final timeRegex = RegExp(r'(\d{1,2}:\d{2})');
      final m = timeRegex.firstMatch(raw);
      if (m != null) return m.group(0) ?? '-';
      if (raw.contains(' ')) {
        final parts = raw.split(' ');
        for (var p in parts) {
          if (timeRegex.hasMatch(p)) return timeRegex.firstMatch(p)!.group(0)!;
        }
      }
      return '-';
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Remark saved'),
                      backgroundColor: Colors.green,
                    ),
                  );
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

    // Prefer API-provided `username` and `department_name` when present in rawData
    final raw = displayItem.rawData ?? <String, dynamic>{};
    final apiUsername =
        (raw['username'] ??
                raw['user_name'] ??
                raw['requester'] ??
                raw['requested_by'])
            ?.toString();
    final apiDept =
        (raw['department_name'] ?? raw['department'] ?? raw['dept_name'])
            ?.toString();
    final shownName = (apiUsername != null && apiUsername.isNotEmpty)
        ? apiUsername
        : displayItem.reqBy;
    final shownDept = (apiDept != null && apiDept.isNotEmpty)
        ? apiDept
        : displayItem.dept;

    // Resolve category_id and characteristic_id from raw data (if present)
    final catRaw = raw['category_id'] ?? raw['categoryId'] ?? raw['category'];
    final charRaw =
        raw['characteristic_id'] ??
        raw['characteristicId'] ??
        raw['characteristic'];
    int? catId = catRaw != null ? int.tryParse(catRaw.toString()) : null;
    int? charId = charRaw != null ? int.tryParse(charRaw.toString()) : null;

    final Map<int, String> categoryNames = {
      1: 'ไฟฟ้า',
      2: 'ประปา',
      3: 'โครงสร้าง',
      6: 'แอร์',
      7: 'อินเตอร์เน็ต',
      8: 'รถยนต์',
      9: 'โฟลคลิฟท์',
      10: 'หอพัก',
      11: 'เครื่องจักร',
    };

    final Map<int, String> characteristicNames = {
      1: 'สร้าง',
      2: 'ปรับปรุง',
      3: 'ซ่อม',
    };

    final apiCategory = catId != null && categoryNames.containsKey(catId)
        ? categoryNames[catId]
        : (raw['category_name'] ?? raw['categoryName'])?.toString() ?? '';
    final apiCharacteristic =
        charId != null && characteristicNames.containsKey(charId)
        ? characteristicNames[charId]
        : (raw['characteristic_name'] ?? raw['characteristicName'])
                  ?.toString() ??
              '';

    // If the API provides a status label indicating final rejection, disable action buttons
    final String statusLabelRaw =
        (raw['status_label'] ?? raw['statusLabel'] ?? displayItem.status)
            ?.toString() ??
        '';
    final bool overallRejected = statusLabelRaw == 'ไม่อนุมัติ';
    // Determine workflow phase; if API reports current_phase == 1, treat as phase one
    final dynamic phaseRaw =
        raw['current_phase'] ?? raw['currentPhase'] ?? raw['phase'];
    final bool isPhaseOne =
        phaseRaw != null &&
        (phaseRaw.toString() == '1' || (phaseRaw is int && phaseRaw == 1));
    // Determine workflow step order; show delete only when step_order == 1
    final dynamic stepOrderRaw =
        raw['current_step_order'] ??
        raw['currentStepOrder'] ??
        raw['step_order'] ??
        raw['stepOrder'];
    final bool isStepOne =
        stepOrderRaw != null &&
        (stepOrderRaw.toString() == '1' ||
            (stepOrderRaw is int && stepOrderRaw == 1));
    // Also expose a flag for step == 3 so UI can show the "ส่งงาน" button
    final bool isStepThree =
        stepOrderRaw != null &&
        (stepOrderRaw.toString() == '3' ||
            (stepOrderRaw is int && stepOrderRaw == 3));
    // Expose flag when API reports final-approved status_label == 'อนุมัติ'
    final bool statusApproved = statusLabelRaw.trim() == 'อนุมัติ';
    // Check logged-in user's department name (require MT)
    final String _loggedDept = (Authen.departmentName ?? '').toString().trim();
    final bool isDeptMT = _loggedDept.toUpperCase() == 'MT';
    // If API reports waiting-for-acceptance or failed inspection, hide approver UI
    final String statusLabelNormalized = statusLabelRaw.trim();
    final bool waitingForInspection =
        statusLabelNormalized == 'รอตรวจรับงาน' ||
        statusLabelNormalized == 'ตรวจสอบไม่ผ่าน';
    // Show the requester check button only when explicitly waiting for
    // requester inspection (รอตรวจรับงาน). Do not show when
    // status_label == 'ตรวจสอบไม่ผ่าน'.
    final bool showUserCheck = statusLabelNormalized == 'รอตรวจรับงาน';
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Remark saved'),
                  backgroundColor: Colors.green,
                ),
              );
              // Refresh comments
              await _loadCommentsForItem();
            }
          }
        },
        backgroundColor: const Color(0xFF48BB78),
        foregroundColor: Colors.white,
        tooltip: 'Add Remark',
        child: const Icon(Icons.note_add, color: Colors.white),
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
                    const SizedBox(height: 8),
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
                // Show requester and department similar to the header
                _buildTableRow('ผู้แจ้ง :', shownName, labelColor, valueColor),
                _buildTableRow('แผนก :', shownDept, labelColor, valueColor),
                _buildTableRow(
                  'หมวดหมู่ :',
                  apiCategory ?? '-',
                  labelColor,
                  valueColor,
                ),
                _buildTableRow(
                  'ลักษณะ :',
                  apiCharacteristic ?? '-',
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
                    'หมายเลขเอกสาร :',
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
                // If API indicated overall rejection via status_label, show fixed text and red color
                Builder(
                  builder: (ctx) {
                    final rawStatus =
                        (raw['status_label'] ??
                                raw['statusLabel'] ??
                                displayItem.status)
                            ?.toString() ??
                        displayItem.status;
                    final displayStatus = overallRejected
                        ? 'ไม่อนุมัติ'
                        : (waitingForInspection
                              ? 'รอตรวจสอบ'
                              : (rawStatus.trim() == 'อนุมัติ'
                                    ? 'กำลังดำเนินการ'
                                    : rawStatus));
                    final statusColor = overallRejected
                        ? Colors.red
                        : (statusApproved ? Colors.green : Colors.orange[800]);
                    return Text(
                      displayStatus,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 5),

            // Only show approver summary and table when NOT waiting for requester inspection
            if (!waitingForInspection) ...[
              // Status line showing loaded approvers count
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  _loadingApprovers
                      ? 'กำลังโหลดผู้อนุมัติ...'
                      : _approvers.isEmpty
                      ? 'ไม่พบผู้อนุมัติ'
                      : 'พบผู้อนุมัติ ${_approvers.length} คน: ${_approvers.map((a) => _extractUsername(a)).join(", ")}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _approvers.isEmpty ? Colors.red : Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

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
                  if (_loadingApprovers)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(child: Text('กำลังโหลด...')),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(),
                        ),
                      ],
                    ),
                  if (!_loadingApprovers && _approvers.isNotEmpty)
                    ..._approvers.asMap().entries.map((e) {
                      final idx = e.key;
                      final approver = e.value;
                      final username = _extractUsername(approver).toString();
                      final status =
                          (approver['status'] ??
                                  approver['step_state'] ??
                                  approver['state'] ??
                                  approver['approved'] ??
                                  '')
                              .toString();
                      final at =
                          (approver['approved_at'] ??
                                  approver['approvedAt'] ??
                                  approver['date'] ??
                                  approver['created_at'] ??
                                  '')
                              .toString();
                      final isApproved =
                          status.toString().toLowerCase().contains(
                            'approved',
                          ) ||
                          approver['approved'] == true ||
                          (approver['step_state'] != null &&
                              approver['step_state'].toString().toLowerCase() ==
                                  'approved');
                      final isRejected =
                          status.toString().toLowerCase().contains(
                            'rejected',
                          ) ||
                          approver['approved'] == false ||
                          (approver['step_state'] != null &&
                              approver['step_state'].toString().toLowerCase() ==
                                  'rejected');

                      // Determine whether logged-in user can act on this approver row
                      final approverUserIdRaw =
                          (approver['id'] ??
                          approver['user_id'] ??
                          approver['approver_id'] ??
                          approver['approverId']);
                      final approverUserId = approverUserIdRaw?.toString();
                      final loggedUserId = Authen.requesterId?.toString();
                      // User can act only when they are the approver and the overall request
                      // is not already marked as final-rejected ('ไม่อนุมัติ').
                      final canAct =
                          approverUserId != null &&
                          loggedUserId != null &&
                          approverUserId == loggedUserId &&
                          !overallRejected;

                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Center(child: Text('${idx + 1}')),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Center(
                              child: Text(
                                username,
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Center(
                              child: isApproved
                                  ? Column(
                                      children: [
                                        const Text(
                                          'อนุมัติแล้ว',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (at.isNotEmpty)
                                          Text(
                                            '${_formatCreatedDateOnly(at)} ${_formatCreatedTimeOnly(at)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black54,
                                            ),
                                          ),
                                      ],
                                    )
                                  : (canAct
                                        ? ElevatedButton(
                                            onPressed: () =>
                                                _approveApproverAt(idx),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10.0,
                                                    horizontal: 18.0,
                                                  ),
                                              textStyle: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            child: const Text('อนุมัติ'),
                                          )
                                        : const SizedBox()),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Center(
                              child: isRejected
                                  ? Column(
                                      children: [
                                        const Text(
                                          'ไม่อนุมัติ',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (at.isNotEmpty)
                                          Text(
                                            '${_formatCreatedDateOnly(at)} ${_formatCreatedTimeOnly(at)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black54,
                                            ),
                                          ),
                                      ],
                                    )
                                  : isApproved
                                  ? const SizedBox()
                                  : (canAct
                                        ? ElevatedButton(
                                            onPressed: () =>
                                                _rejectApproverAt(idx),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.redAccent,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10.0,
                                                    horizontal: 18.0,
                                                  ),
                                              textStyle: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            child: const Text('ไม่อนุมัติ'),
                                          )
                                        : const SizedBox()),
                            ),
                          ),
                        ],
                      );
                    }),
                  if (!_loadingApprovers && _approvers.isEmpty)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(child: Text('-')),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(child: Text('ไม่มีข้อมูล')),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: Text('-')),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: Text('-')),
                        ),
                      ],
                    ),
                ],
              ),
            ],

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
                                        Row(
                                          children: [
                                            Text(
                                              username.toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
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
                                  // Show delete button only when comment owner matches logged-in user
                                  Builder(
                                    builder: (ctx) {
                                      final commentUserId =
                                          (comment['user_id'] ??
                                                  comment['userId'])
                                              ?.toString();
                                      final loggedUserId = Authen.requesterId
                                          ?.toString();
                                      final canDeleteComment =
                                          loggedUserId != null &&
                                          commentUserId != null &&
                                          commentUserId == loggedUserId;

                                      if (!canDeleteComment) {
                                        return const SizedBox();
                                      }

                                      return IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 18,
                                        ),
                                        color: Colors.red,
                                        onPressed: () => _deleteComment(
                                          comment['id']?.toString() ?? '',
                                          commentUserId,
                                        ),
                                        tooltip: 'ลบคอมเมนต์',
                                      );
                                    },
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
                              const SizedBox(height: 8),
                              // Display attachments (thumbnails) if any
                              Builder(
                                builder: (cxt) {
                                  final atts = (comment['attachments'] is List)
                                      ? (comment['attachments'] as List)
                                            .map((e) => e.toString())
                                            .where((s) => s.isNotEmpty)
                                            .toList()
                                      : <String>[];
                                  if (atts.isEmpty) return const SizedBox();
                                  return SizedBox(
                                    height: 90,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: atts.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 8),
                                      itemBuilder: (ctx, ai) {
                                        final url = _normalizeUrl(atts[ai]);
                                        return GestureDetector(
                                          onTap: () =>
                                              _showFullImage(context, url),
                                          child: Container(
                                            width: 120,
                                            height: 90,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.grey[300]!,
                                              ),
                                            ),
                                            child: Image.network(
                                              url,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Center(
                                                    child: Icon(
                                                      Icons.broken_image,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
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

            const SizedBox(height: 12),

            // Delete button will be shown next to CloseJobButton below

            // ปุ่มปิดงาน (ย้ายไปยัง CloseJobButton) + ปุ่มเอกสาร (+ ปุ่มลบเมื่อมีสิทธิ)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_canCurrentUserDelete(displayItem) &&
                    !waitingForInspection &&
                    isPhaseOne &&
                    isStepOne) ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 20,
                      ),
                    ),
                    onPressed: () => _onDeletePressed(displayItem),
                    child: const Text(
                      'ลบคำขอ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // Hide CloseJobButton when overall status_label indicates rejection,
                // when the workflow is in phase 1, or when waiting for inspection
                if ((statusApproved ||
                        statusLabelNormalized == 'ตรวจสอบไม่ผ่าน') &&
                    isDeptMT) ...[
                  CloseJobButton(item: displayItem),
                  const SizedBox(width: 12),
                ],
                if (showUserCheck && _isCreatorOf(displayItem)) ...[
                  // User check button (pass/fail)
                  UserCheckButton(
                    item: displayItem,
                    onChecked: (status, [remark]) async {
                      if (status == 'passed') {
                        await _handleRequesterAccept();
                        return;
                      }

                      // Failed case: call reject-check API with comment in body
                      String? id = _currentRepairRequestId ?? widget.item?.id;
                      if (id == null || id.isEmpty)
                        id = await _resolveIdFromList();
                      if (id == null || id.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ไม่พบ ID สำหรับส่งผลการตรวจสอบ'),
                          ),
                        );
                        return;
                      }

                      final uri = Uri.parse(
                        '$_baseHost/repair-requests/$id/reject-check',
                      );
                      final headers = _authHeaders(json: true);
                      final bodyMap = <String, dynamic>{
                        'comment': remark ?? '',
                      };

                      try {
                        final resp = await http
                            .post(
                              uri,
                              headers: headers,
                              body: jsonEncode(bodyMap),
                            )
                            .timeout(const Duration(seconds: 10));
                        debugPrint(
                          'reject-check response: ${resp.statusCode} ${resp.body}',
                        );
                        if (resp.statusCode == 200 ||
                            resp.statusCode == 201 ||
                            resp.statusCode == 204) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'ส่งผลการตรวจสอบ: ไม่ผ่าน เรียบร้อยแล้ว',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );

                            // Navigate back to the home list and replace this
                            // detail page so the home page reloads once.
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (ctx) => const PurchaseReportPage(),
                              ),
                            );
                          }
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('การส่งผลการตรวจสอบล้มเหลว'),
                          ),
                        );
                      } catch (e) {
                        debugPrint('Error calling reject-check: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('เกิดข้อผิดพลาด ขณะส่งผลการตรวจสอบ'),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                ],

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => DocumentPage(item: displayItem),
                      ),
                    );
                  },
                  child: const Text(
                    'เอกสาร',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
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

  Future<void> _deleteRequest(String? id) async {
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบรหัสคำขอที่ต้องการลบ')),
      );
      return;
    }

    final uriPrimary = Uri.parse('$_baseHost/repair-requests/$id');
    final uriAlt = Uri.parse('$_baseHost/repair-requests/$id/delete');

    try {
      final headers = _authHeaders();
      final resp = await http
          .delete(uriPrimary, headers: headers)
          .timeout(const Duration(seconds: 10));
      debugPrint('DELETE $uriPrimary -> ${resp.statusCode} ${resp.body}');
      if (resp.statusCode == 200 ||
          resp.statusCode == 202 ||
          resp.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('ลบคำขอเรียบร้อยแล้ว')));
          Navigator.of(context).pop(true);
        }
        return;
      }

      // Try alternative endpoint (some APIs use POST /.../delete)
      try {
        final r2 = await http
            .post(uriAlt, headers: headers)
            .timeout(const Duration(seconds: 10));
        debugPrint('ALT POST $uriAlt -> ${r2.statusCode} ${r2.body}');
        if (r2.statusCode == 200 ||
            r2.statusCode == 202 ||
            r2.statusCode == 204) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ลบคำขอเรียบร้อยแล้ว')),
            );
            Navigator.of(context).pop(true);
          }
          return;
        }
      } catch (e) {
        debugPrint('Alt delete error: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ไม่สามารถลบคำขอได้')));
      }
    } catch (e) {
      debugPrint('Error deleting request: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('เกิดข้อผิดพลาดในการลบ')));
      }
    }
  }

  bool _canCurrentUserDelete(PurchaseItem displayItem) {
    final loggedUserId = Authen.requesterId?.toString();
    String? creatorId;
    final raw = displayItem.rawData ?? <String, dynamic>{};
    final creatorCandidates = [
      'user_id',
      'requester_id',
      'created_by',
      'created_by_id',
      'owner_id',
      'requesterId',
      'creator_id',
      'creator',
    ];
    for (final k in creatorCandidates) {
      final v = raw[k];
      if (v == null) continue;
      if (v is Map) {
        if (v['id'] != null) {
          creatorId = v['id'].toString();
          break;
        }
      } else {
        creatorId = v.toString();
        break;
      }
    }

    if (creatorId == null) {
      try {
        final maybe = int.tryParse(displayItem.reqBy);
        if (maybe != null) creatorId = maybe.toString();
      } catch (_) {}
    }

    bool anyApproved = false;
    for (final a in _approvers) {
      final status =
          (a['status'] ?? a['step_state'] ?? a['state'] ?? a['approved'] ?? '')
              .toString()
              .toLowerCase();
      if (status.contains('approved')) {
        anyApproved = true;
        break;
      }
      if (a['approved'] == true) {
        anyApproved = true;
        break;
      }
      if (a['step_state'] != null &&
          a['step_state'].toString().toLowerCase() == 'approved') {
        anyApproved = true;
        break;
      }
    }

    return loggedUserId != null &&
        creatorId != null &&
        loggedUserId == creatorId &&
        !anyApproved;
  }

  // Return true when the currently logged-in user is the creator/owner of the item
  bool _isCreatorOf(PurchaseItem displayItem) {
    final loggedUserId = Authen.requesterId?.toString();
    if (loggedUserId == null) return false;
    String? creatorId;
    final raw = displayItem.rawData ?? <String, dynamic>{};
    final creatorCandidates = [
      'user_id',
      'requester_id',
      'created_by',
      'created_by_id',
      'owner_id',
      'requesterId',
      'creator_id',
      'creator',
    ];
    for (final k in creatorCandidates) {
      final v = raw[k];
      if (v == null) continue;
      if (v is Map) {
        if (v['id'] != null) {
          creatorId = v['id'].toString();
          break;
        }
      } else {
        creatorId = v.toString();
        break;
      }
    }

    if (creatorId == null) {
      try {
        final maybe = int.tryParse(displayItem.reqBy);
        if (maybe != null) creatorId = maybe.toString();
      } catch (_) {}
    }

    return creatorId != null && creatorId == loggedUserId;
  }

  Future<void> _onDeletePressed(PurchaseItem displayItem) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('ต้องการลบคำขอนี้จริงหรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    String? id = displayItem.id;
    if (id.isEmpty) {
      final rawData = displayItem.rawData;
      if (rawData != null) {
        id =
            rawData['id']?.toString() ??
            rawData['repair_request_id']?.toString();
      }
    }
    if (id == null || id.isEmpty) {
      id = await _resolveIdFromList();
    }
    await _deleteRequest(id);
  }

  Future<void> _closeRequest(String? id) async {
    // Moved to CloseJobButton widget in closejob.dart
    return;
  }

  Future<void> _deleteComment(String commentId, [String? commentUserId]) async {
    if (commentId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่พบรหัสคอมเมนต์')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('ต้องการลบคอมเมนต์นี้จริงหรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Authorization: only allow delete when logged-in user matches comment owner
    final loggedUserId = Authen.requesterId?.toString();
    if (loggedUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาล็อกอินก่อนทำรายการ')));
      return;
    }
    if (commentUserId == null || commentUserId != loggedUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คุณไม่มีสิทธิ์ลบคอมเมนต์นี้')),
      );
      return;
    }

    try {
      if (_currentRepairRequestId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ไม่พบรหัสคำขอ')));
        return;
      }

      // Use comment-specific delete endpoint: /repair-requests/comments/:commentId
      final uri = Uri.parse('$_baseHost/repair-requests/comments/$commentId');
      final headers = _authHeaders();

      final resp = await http
          .delete(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      debugPrint('DELETE comment -> ${resp.statusCode} ${resp.body}');

      if (resp.statusCode == 200 ||
          resp.statusCode == 202 ||
          resp.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ลบคอมเมนต์เรียบร้อยแล้ว')),
          );
          // Refresh comments
          await _loadCommentsForItem();
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ไม่สามารถลบคอมเมนต์ได้')));
      }
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('เกิดข้อผิดพลาดในการลบ')));
      }
    }
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
