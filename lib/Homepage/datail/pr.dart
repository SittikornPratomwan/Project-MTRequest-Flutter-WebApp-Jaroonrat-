import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../Authen/authen.dart';
import '../../Service/mt_request_api.dart';

/// Show a popup dialog for entering a PR value.
Future<Map<String, dynamic>?> showPrDialog(
  BuildContext context, {
  required String? repairRequestId,
  String initialValue = '',
  String initialText = '',
}) {
  final prNumberController = TextEditingController(text: initialValue);
  final prTextController = TextEditingController(text: initialText);
  var isSaving = false;

  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (ctx) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 560,
            maxHeight: 320,
            minWidth: 320,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              Future<void> submit() async {
                final prNumber = prNumberController.text.trim();
                final prText = prTextController.text.trim();

                if (repairRequestId == null || repairRequestId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ไม่พบ ID สำหรับบันทึก PR')),
                  );
                  return;
                }

                setState(() {
                  isSaving = true;
                });

                final uri = Uri.parse(
                  '${MtRequestApi.baseUrl}/repair-requests/$repairRequestId/pr',
                );
                final headers = <String, String>{
                  'Content-Type': 'application/json',
                };
                if (Authen.token != null && Authen.token!.isNotEmpty) {
                  headers['Authorization'] = 'Bearer ${Authen.token}';
                }

                final body = jsonEncode({
                  'prNumber': prNumber,
                  'prText': prText,
                });

                try {
                  final response = await http
                      .put(uri, headers: headers, body: body)
                      .timeout(MtRequestApi.requestTimeout);

                  if (response.statusCode == 200 ||
                      response.statusCode == 201 ||
                      response.statusCode == 204) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('บันทึก PR สำเร็จ'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.of(ctx).pop({
                        'saved': true,
                        'prNumber': prNumber,
                        'prText': prText,
                      });
                    }
                    return;
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'บันทึก PR ไม่สำเร็จ (${response.statusCode})',
                        ),
                      ),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('เกิดข้อผิดพลาดขณะบันทึก PR'),
                      ),
                    );
                  }
                } finally {
                  if (ctx.mounted) {
                    setState(() {
                      isSaving = false;
                    });
                  }
                }
              }

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.blueGrey, width: 2),
                ),
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Add PR',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: prNumberController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'พิมพ์เลขที่ PR ...',
                          labelText: 'PR Number',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: prTextController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'พิมพ์รายละเอียด PR ...',
                          labelText: 'PR Text',
                        ),
                        minLines: 3,
                        maxLines: 5,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => submit(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isSaving ? null : submit,
                            child: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );
}
