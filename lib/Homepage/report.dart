import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../Authen/authen.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  static const String _baseUrl = 'http://26.99.205.41:9000/drugs';

  final List<int> _years = List<int>.generate(7, (index) => 2024 + index);
  final List<_MonthOption> _months = const [
    _MonthOption(value: 1, label: 'มกราคม'),
    _MonthOption(value: 2, label: 'กุมภาพันธ์'),
    _MonthOption(value: 3, label: 'มีนาคม'),
    _MonthOption(value: 4, label: 'เมษายน'),
    _MonthOption(value: 5, label: 'พฤษภาคม'),
    _MonthOption(value: 6, label: 'มิถุนายน'),
    _MonthOption(value: 7, label: 'กรกฎาคม'),
    _MonthOption(value: 8, label: 'สิงหาคม'),
    _MonthOption(value: 9, label: 'กันยายน'),
    _MonthOption(value: 10, label: 'ตุลาคม'),
    _MonthOption(value: 11, label: 'พฤศจิกายน'),
    _MonthOption(value: 12, label: 'ธันวาคม'),
  ];

  late int _selectedYearSummary;
  late int _selectedYearDeptCategory;
  late int _selectedMonthDeptCategory;
  late int _selectedYearCategory;
  late int _selectedMonthCategory;

  bool _isLoadingSummary = false;
  bool _isLoadingDeptCategory = false;
  bool _isLoadingCategory = false;

  String? _summaryError;
  String? _deptCategoryError;
  String? _categoryError;

  List<_MonthlySummaryItem> _monthlySummaryItems = const [];
  List<_DeptCategoryItem> _deptCategoryItems = const [];
  List<_CategorySummaryItem> _categorySummaryItems = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYearSummary = now.year;
    _selectedYearDeptCategory = now.year;
    _selectedMonthDeptCategory = now.month;
    _selectedYearCategory = now.year;
    _selectedMonthCategory = now.month;
    _fetchAllReports();
  }

  Future<void> _fetchAllReports() async {
    await Future.wait([
      _fetchYearSummary(),
      _fetchDeptCategoryReport(),
      _fetchCategoryReport(),
    ]);
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = Authen.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> _getReportData(
    String path,
    Map<String, String> queryParameters,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: queryParameters);

    final response = await http
        .get(uri, headers: _buildHeaders())
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      String message = 'โหลดข้อมูลไม่สำเร็จ (${response.statusCode})';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map) {
          final candidate =
              errorData['message'] ?? errorData['error'] ?? errorData['detail'];
          if (candidate != null && candidate.toString().trim().isNotEmpty) {
            message = candidate.toString();
          }
        }
      } catch (_) {}
      throw Exception(message);
    }

    if (response.body.trim().isEmpty) {
      return const <dynamic>[];
    }

    return jsonDecode(response.body);
  }

  List<Map<String, dynamic>> _extractItemList(dynamic source) {
    if (source == null) {
      return const [];
    }

    if (source is List) {
      return source.map<Map<String, dynamic>>((item) {
        if (item is Map<String, dynamic>) {
          return item;
        }
        if (item is Map) {
          return item.map((key, value) => MapEntry(key.toString(), value));
        }
        return {'value': item};
      }).toList();
    }

    if (source is Map) {
      final normalizedMap = source.map(
        (key, value) => MapEntry(key.toString(), value),
      );

      for (final key in const [
        'data',
        'results',
        'items',
        'summary',
        'report',
        'payload',
      ]) {
        final nested = normalizedMap[key];
        if (nested is List) {
          return _extractItemList(nested);
        }
      }

      if (normalizedMap.values.every((value) => value is num)) {
        return normalizedMap.entries
            .map(
              (entry) => <String, dynamic>{
                'key': entry.key,
                'count': entry.value,
              },
            )
            .toList();
      }

      if (normalizedMap.values.every(
        (value) => value is Map || value is num || value is String,
      )) {
        return normalizedMap.entries.map((entry) {
          final value = entry.value;
          if (value is Map) {
            return <String, dynamic>{
              'key': entry.key,
              ...value.map(
                (nestedKey, nestedValue) =>
                    MapEntry(nestedKey.toString(), nestedValue),
              ),
            };
          }
          return <String, dynamic>{'key': entry.key, 'value': value};
        }).toList();
      }

      return [normalizedMap];
    }

    return [
      <String, dynamic>{'value': source},
    ];
  }

  String _findFirstString(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  int _findFirstInt(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value == null) {
        continue;
      }
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      final parsed = int.tryParse(value.toString());
      if (parsed != null) {
        return parsed;
      }
    }
    return 0;
  }

  String _monthLabelFromValue(int month) {
    for (final option in _months) {
      if (option.value == month) {
        return option.label;
      }
    }
    return month.toString();
  }

  String _normalizeMonthLabel(dynamic rawMonth) {
    if (rawMonth == null) {
      return '-';
    }
    if (rawMonth is int) {
      return _monthLabelFromValue(rawMonth);
    }
    final text = rawMonth.toString().trim();
    final yearMonthMatch = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(text);
    if (yearMonthMatch != null) {
      final monthPart = int.tryParse(yearMonthMatch.group(2) ?? '');
      if (monthPart != null) {
        return _monthLabelFromValue(monthPart);
      }
    }
    final parsed = int.tryParse(text);
    if (parsed != null) {
      return _monthLabelFromValue(parsed);
    }
    return text;
  }

  Future<void> _fetchYearSummary() async {
    setState(() {
      _isLoadingSummary = true;
      _summaryError = null;
    });

    try {
      final data = await _getReportData(
        '/repair-requests/reports/year-summary',
        {'year': _selectedYearSummary.toString()},
      );

      final rows = _extractItemList(data)
          .map((item) {
            final rawMonth =
                item['month'] ??
                item['month_no'] ??
                item['monthNumber'] ??
                item['month_number'] ??
                item['month_name'] ??
                item['monthName'] ??
                item['label'] ??
                item['name'] ??
                item['key'];
            final monthValue = _findFirstInt(item, [
              'month',
              'month_no',
              'monthNumber',
              'month_number',
            ]);
            final monthLabel = _findFirstString(item, [
              'month',
              'month_name',
              'monthName',
              'label',
              'name',
              'key',
            ]);
            final count = _findFirstInt(item, [
              'count',
              'total',
              'total_requests',
              'request_count',
              'value',
            ]);

            return _MonthlySummaryItem(
              monthLabel: _normalizeMonthLabel(
                monthLabel.isNotEmpty
                    ? monthLabel
                    : (monthValue == 0 ? rawMonth : monthValue),
              ),
              count: count,
            );
          })
          .where((item) => item.monthLabel.isNotEmpty)
          .toList();

      rows.sort((left, right) {
        final leftIndex = _months.indexWhere(
          (item) => item.label == left.monthLabel,
        );
        final rightIndex = _months.indexWhere(
          (item) => item.label == right.monthLabel,
        );
        if (leftIndex == -1 || rightIndex == -1) {
          return left.monthLabel.compareTo(right.monthLabel);
        }
        return leftIndex.compareTo(rightIndex);
      });

      if (!mounted) {
        return;
      }
      setState(() {
        _monthlySummaryItems = rows;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _summaryError = error.toString().replaceFirst('Exception: ', '');
        _monthlySummaryItems = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
        });
      }
    }
  }

  Future<void> _fetchDeptCategoryReport() async {
    setState(() {
      _isLoadingDeptCategory = true;
      _deptCategoryError = null;
    });

    try {
      final data =
          await _getReportData('/repair-requests/reports/by-dept-category', {
            'year': _selectedYearDeptCategory.toString(),
            'month': _selectedMonthDeptCategory.toString(),
          });

      final rows =
          _extractItemList(data)
              .map((item) {
                final department = _findFirstString(item, [
                  'department_name',
                  'departmentName',
                  'department',
                  'dept_name',
                  'deptName',
                  'dept',
                ]);
                final category = _findFirstString(item, [
                  'category_name',
                  'categoryName',
                  'category',
                  'repair_category',
                  'type_name',
                  'type',
                  'key',
                ]);
                final count = _findFirstInt(item, [
                  'count',
                  'total',
                  'total_requests',
                  'request_count',
                  'value',
                ]);

                return _DeptCategoryItem(
                  department: department,
                  category: category,
                  count: count,
                );
              })
              .where(
                (item) =>
                    item.department.isNotEmpty || item.category.isNotEmpty,
              )
              .toList()
            ..sort((left, right) {
              final departmentCompare = left.department.compareTo(
                right.department,
              );
              if (departmentCompare != 0) {
                return departmentCompare;
              }
              return right.count.compareTo(left.count);
            });

      if (!mounted) {
        return;
      }
      setState(() {
        _deptCategoryItems = rows;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _deptCategoryError = error.toString().replaceFirst('Exception: ', '');
        _deptCategoryItems = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDeptCategory = false;
        });
      }
    }
  }

  Future<void> _fetchCategoryReport() async {
    setState(() {
      _isLoadingCategory = true;
      _categoryError = null;
    });

    try {
      final data =
          await _getReportData('/repair-requests/reports/by-category', {
            'year': _selectedYearCategory.toString(),
            'month': _selectedMonthCategory.toString(),
          });

      final rows =
          _extractItemList(data)
              .map((item) {
                final category = _findFirstString(item, [
                  'category_name',
                  'categoryName',
                  'category',
                  'repair_category',
                  'type_name',
                  'type',
                  'key',
                ]);
                final count = _findFirstInt(item, [
                  'count',
                  'total',
                  'total_requests',
                  'request_count',
                  'value',
                ]);

                return _CategorySummaryItem(category: category, count: count);
              })
              .where((item) => item.category.isNotEmpty)
              .toList()
            ..sort((left, right) => right.count.compareTo(left.count));

      if (!mounted) {
        return;
      }
      setState(() {
        _categorySummaryItems = rows;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _categoryError = error.toString().replaceFirst('Exception: ', '');
        _categorySummaryItems = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategory = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MTrequest Report'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _fetchAllReports,
            icon: const Icon(Icons.refresh),
            tooltip: 'โหลดข้อมูลใหม่',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAllReports,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'รายผลการแจ้งซ่อม',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSummarySection(),
            const SizedBox(height: 16),
            _buildDeptCategorySection(),
            const SizedBox(height: 16),
            _buildCategorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final total = _monthlySummaryItems.fold<int>(
      0,
      (sum, item) => sum + item.count,
    );

    return _ReportSectionCard(
      title: '1. จำนวนใบงานรายเดือน',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<int>(
                  value: _selectedYearSummary,
                  decoration: const InputDecoration(
                    labelText: 'เลือกปี',
                    border: OutlineInputBorder(),
                  ),
                  items: _years
                      .map(
                        (year) => DropdownMenuItem<int>(
                          value: year,
                          child: Text(year.toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedYearSummary = value;
                    });
                    _fetchYearSummary();
                  },
                ),
              ),
              _buildCountChip('รวมทั้งปี', total),
            ],
          ),
          const SizedBox(height: 16),
          _buildLoadingErrorOrContent(
            isLoading: _isLoadingSummary,
            error: _summaryError,
            isEmpty: _monthlySummaryItems.isEmpty,
            emptyMessage: 'ไม่พบข้อมูลรายเดือนของปีที่เลือก',
            onRetry: _fetchYearSummary,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('เดือน')),
                  DataColumn(label: Text('จำนวนใบงาน')),
                ],
                rows: _monthlySummaryItems
                    .map(
                      (item) => DataRow(
                        cells: [
                          DataCell(Text(item.monthLabel)),
                          DataCell(Text(item.count.toString())),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeptCategorySection() {
    final total = _deptCategoryItems.fold<int>(
      0,
      (sum, item) => sum + item.count,
    );

    return _ReportSectionCard(
      title: '2. แผนกแจ้งหมวดอะไรเท่าไหร่',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<int>(
                  value: _selectedYearDeptCategory,
                  decoration: const InputDecoration(
                    labelText: 'เลือกปี',
                    border: OutlineInputBorder(),
                  ),
                  items: _years
                      .map(
                        (year) => DropdownMenuItem<int>(
                          value: year,
                          child: Text(year.toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedYearDeptCategory = value;
                    });
                    _fetchDeptCategoryReport();
                  },
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<int>(
                  value: _selectedMonthDeptCategory,
                  decoration: const InputDecoration(
                    labelText: 'เลือกเดือน',
                    border: OutlineInputBorder(),
                  ),
                  items: _months
                      .map(
                        (month) => DropdownMenuItem<int>(
                          value: month.value,
                          child: Text(month.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedMonthDeptCategory = value;
                    });
                    _fetchDeptCategoryReport();
                  },
                ),
              ),
              _buildCountChip('รวมรายการ', total),
            ],
          ),
          const SizedBox(height: 16),
          _buildLoadingErrorOrContent(
            isLoading: _isLoadingDeptCategory,
            error: _deptCategoryError,
            isEmpty: _deptCategoryItems.isEmpty,
            emptyMessage: 'ไม่พบข้อมูลแผนกและหมวดของช่วงเวลาที่เลือก',
            onRetry: _fetchDeptCategoryReport,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('แผนก')),
                  DataColumn(label: Text('หมวด')),
                  DataColumn(label: Text('จำนวน')),
                ],
                rows: _deptCategoryItems
                    .map(
                      (item) => DataRow(
                        cells: [
                          DataCell(
                            Text(
                              item.department.isEmpty ? '-' : item.department,
                            ),
                          ),
                          DataCell(
                            Text(item.category.isEmpty ? '-' : item.category),
                          ),
                          DataCell(Text(item.count.toString())),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    final total = _categorySummaryItems.fold<int>(
      0,
      (sum, item) => sum + item.count,
    );

    return _ReportSectionCard(
      title: '3. หมวดไหนถูกแจ้งซ่อมเท่าไหร่',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<int>(
                  value: _selectedYearCategory,
                  decoration: const InputDecoration(
                    labelText: 'เลือกปี',
                    border: OutlineInputBorder(),
                  ),
                  items: _years
                      .map(
                        (year) => DropdownMenuItem<int>(
                          value: year,
                          child: Text(year.toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedYearCategory = value;
                    });
                    _fetchCategoryReport();
                  },
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<int>(
                  value: _selectedMonthCategory,
                  decoration: const InputDecoration(
                    labelText: 'เลือกเดือน',
                    border: OutlineInputBorder(),
                  ),
                  items: _months
                      .map(
                        (month) => DropdownMenuItem<int>(
                          value: month.value,
                          child: Text(month.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedMonthCategory = value;
                    });
                    _fetchCategoryReport();
                  },
                ),
              ),
              _buildCountChip('รวมรายการ', total),
            ],
          ),
          const SizedBox(height: 16),
          _buildLoadingErrorOrContent(
            isLoading: _isLoadingCategory,
            error: _categoryError,
            isEmpty: _categorySummaryItems.isEmpty,
            emptyMessage: 'ไม่พบข้อมูลหมวดของช่วงเวลาที่เลือก',
            onRetry: _fetchCategoryReport,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('หมวด')),
                  DataColumn(label: Text('จำนวน')),
                ],
                rows: _categorySummaryItems
                    .map(
                      (item) => DataRow(
                        cells: [
                          DataCell(Text(item.category)),
                          DataCell(Text(item.count.toString())),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingErrorOrContent({
    required bool isLoading,
    required String? error,
    required bool isEmpty,
    required String emptyMessage,
    required VoidCallback onRetry,
    required Widget child,
  }) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error,
              style: TextStyle(
                color: Colors.red[800],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    if (isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(emptyMessage, style: TextStyle(color: Colors.grey[700])),
      );
    }

    return child;
  }

  Widget _buildCountChip(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Color(0xFF0D47A1),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReportSectionCard extends StatelessWidget {
  const _ReportSectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: TextStyle(color: Colors.grey[700])),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MonthOption {
  const _MonthOption({required this.value, required this.label});

  final int value;
  final String label;
}

class _MonthlySummaryItem {
  const _MonthlySummaryItem({required this.monthLabel, required this.count});

  final String monthLabel;
  final int count;
}

class _DeptCategoryItem {
  const _DeptCategoryItem({
    required this.department,
    required this.category,
    required this.count,
  });

  final String department;
  final String category;
  final int count;
}

class _CategorySummaryItem {
  const _CategorySummaryItem({required this.category, required this.count});

  final String category;
  final int count;
}
