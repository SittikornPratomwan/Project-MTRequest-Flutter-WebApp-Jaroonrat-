import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class RemarkPage extends StatefulWidget {
  const RemarkPage({super.key});

  @override
  State<RemarkPage> createState() => _RemarkPageState();
}

// Helper to show the remark UI as a popup dialog without darkening the background.
Future<Map<String, dynamic>?> showRemarkDialog(BuildContext context) {
  final TextEditingController controller = TextEditingController();
  final ImagePicker picker = ImagePicker();
  final List<Uint8List> images = [];
  const int maxImages = 5;

  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (ctx) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 760,
            maxHeight: 560,
            minWidth: 320,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              Future<void> pickImages() async {
                try {
                  final List<XFile>? picked = await picker.pickMultiImage();
                  if (picked != null && picked.isNotEmpty) {
                    for (final x in picked) {
                      if (images.length >= maxImages) break;
                      final bytes = await x.readAsBytes();
                      images.add(bytes);
                    }
                    setState(() {});
                    return;
                  }
                  final XFile? single = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (single != null) {
                    final bytes = await single.readAsBytes();
                    if (images.length < maxImages) {
                      images.add(bytes);
                      setState(() {});
                    }
                  }
                } catch (e) {
                  if (kDebugMode) debugPrint('Image pick error: $e');
                }
              }

              void removeAt(int idx) => setState(() => images.removeAt(idx));

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Add Remark',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 320,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'พิมพ์ข้อความ Remark ...',
                                ),
                                maxLines: null,
                                expands: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'รูปภาพ (สูงสุด $maxImages รูป)',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 110,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: images.length + 1,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  if (index == images.length) {
                                    final canAdd = images.length < maxImages;
                                    return GestureDetector(
                                      onTap: canAdd ? pickImages : null,
                                      child: Container(
                                        width: 110,
                                        height: 110,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey,
                                          ),
                                          color: canAdd
                                              ? Colors.grey[200]
                                              : Colors.grey[300],
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.add_a_photo,
                                            color: canAdd
                                                ? Colors.blue
                                                : Colors.grey,
                                            size: 32,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  final bytes = images[index];
                                  return Stack(
                                    children: [
                                      Container(
                                        width: 110,
                                        height: 110,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey,
                                          ),
                                        ),
                                        child: Image.memory(
                                          bytes,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => removeAt(index),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(ctx).pop({
                                'remark': controller.text.trim(),
                                'images': images,
                              });
                            },
                            child: const Text('Save'),
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

class _RemarkPageState extends State<RemarkPage> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<Uint8List> _images = [];
  static const int _maxImages = 5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      // Try multi image (works on many platforms)
      final List<XFile>? picked = await _picker.pickMultiImage();
      if (picked != null && picked.isNotEmpty) {
        for (final x in picked) {
          if (_images.length >= _maxImages) break;
          final bytes = await x.readAsBytes();
          _images.add(bytes);
        }
        setState(() {});
        return;
      }

      // Fallback: single image picker
      final XFile? single = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (single != null) {
        final bytes = await single.readAsBytes();
        if (_images.length < _maxImages) {
          setState(() => _images.add(bytes));
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Image pick error: $e');
    }
  }

  void _removeImageAt(int index) {
    setState(() => _images.removeAt(index));
  }

  void _onSave() {
    final remark = _controller.text.trim();
    Navigator.of(context).pop({'remark': remark, 'images': _images});
  }

  @override
  Widget build(BuildContext context) {
    // Use a centered constrained dialog-like UI
    return Scaffold(
      backgroundColor: Colors.black54,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 760,
              maxHeight: 560,
              minWidth: 320,
            ),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Add Remark',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _controller,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'พิมพ์ข้อความ Remark ...',
                            ),
                            maxLines: 6,
                          ),
                          const SizedBox(height: 12),

                          // Image thumbnails
                          Text(
                            'รูปภาพ (สูงสุด $_maxImages รูป)',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 110,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _images.length + 1,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                if (index == _images.length) {
                                  final canAdd = _images.length < _maxImages;
                                  return GestureDetector(
                                    onTap: canAdd ? _pickImages : null,
                                    child: Container(
                                      width: 110,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        color: canAdd
                                            ? Colors.grey[200]
                                            : Colors.grey[300],
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.add_a_photo,
                                          color: canAdd
                                              ? Colors.blue
                                              : Colors.grey,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                final bytes = _images[index];
                                return Stack(
                                  children: [
                                    Container(
                                      width: 110,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                      ),
                                      child: Image.memory(
                                        bytes,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => _removeImageAt(index),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _onSave,
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
