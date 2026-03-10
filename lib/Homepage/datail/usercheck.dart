import 'package:flutter/material.dart';

/// Button that shows a simple pass/fail dialog and returns choice via callback.
class UserCheckButton extends StatelessWidget {
  final dynamic item;
  final void Function(String status, [String? remark])? onChecked;

  const UserCheckButton({Key? key, this.item, this.onChecked})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      onPressed: () => _openDialog(context),
      child: const Text(
        'ตรวจสอบ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _openDialog(BuildContext context) async {
    final choice = await showDialog<String?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('ผลการตรวจสอบ'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('passed'),
            child: const Text('ผ่าน', style: TextStyle(color: Colors.green)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('failed'),
            child: const Text('ไม่ผ่าน', style: TextStyle(color: Colors.red)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('ยกเลิก'),
          ),
        ],
      ),
    );

    if (choice == null) return;
    if (choice == 'passed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ผลตรวจสอบ: ผ่าน'),
          backgroundColor: Colors.green,
        ),
      );
      if (onChecked != null) onChecked!('passed');
      return;
    }

    // If failed, ask for optional remark
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ไม่ผ่าน - ระบุหมายเหตุ (บังคับ)'),
        content: TextField(controller: controller, maxLines: 3),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final remark = controller.text.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'ผลตรวจสอบ: ไม่ผ่าน${remark.isNotEmpty ? ' — $remark' : ''}',
        ),
      ),
    );
    if (onChecked != null) onChecked!('failed', remark.isEmpty ? null : remark);
  }
}
