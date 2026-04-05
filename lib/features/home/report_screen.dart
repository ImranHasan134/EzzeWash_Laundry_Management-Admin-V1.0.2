// lib/features/home/report_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/color/app_colors.dart';
import '../../main.dart';
import 'service_reviews_screen.dart';

class MonthlyStatData {
  int orders = 0;
  int delivered = 0;
  double revenue = 0.0;
}

class ReportsScreen extends StatefulWidget {
  final bool isSuperAdmin;
  final String? managerStoreId;
  const ReportsScreen({super.key, required this.isSuperAdmin, this.managerStoreId});

  @override State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _byService = [];

  List<Map<String, dynamic>> _rawOrders = [];
  List<Map<String, dynamic>> _rawReviews = [];

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  List<int> _availableYears = [2026, 2025];

  Map<String, MonthlyStatData> _monthlyStats = {};

  @override void initState() { super.initState(); _loadReports(); }

  Future<void> _loadReports() async {
    setState(() => _loading = true);
    try {
      var query = supabase.from(AppConstants.ordersTable).select('status, total_price, created_at, service_id, services(title)');
      if (!widget.isSuperAdmin && widget.managerStoreId != null) {
        query = query.eq('store_id', widget.managerStoreId!);
      }
      final orders = await query;
      _rawOrders = List<Map<String, dynamic>>.from(orders);

      final reviewsData = await supabase.from('reviews').select('rating, service_id');
      _rawReviews = List<Map<String, dynamic>>.from(reviewsData);

      final ratingSum = <String, double>{};
      final ratingCount = <String, int>{};
      for (final r in _rawReviews) {
        final sId = r['service_id'] as String?;
        if (sId == null) continue;
        final rating = (r['rating'] as num?)?.toDouble() ?? 0.0;
        ratingSum[sId] = (ratingSum[sId] ?? 0.0) + rating;
        ratingCount[sId] = (ratingCount[sId] ?? 0) + 1;
      }

      int minYear = 2025;
      final tempStats = <String, MonthlyStatData>{};

      for (final o in _rawOrders) {
        if (o['created_at'] == null) continue;
        final d = DateTime.parse(o['created_at']).toLocal();
        if (d.year < minYear) minYear = d.year;

        final key = '${d.month}-${d.year}';
        tempStats.putIfAbsent(key, () => MonthlyStatData());
        tempStats[key]!.orders += 1;

        if (o['status'] == 'delivered') {
          tempStats[key]!.delivered += 1;
          tempStats[key]!.revenue += ((o['total_price'] as num?)?.toDouble() ?? 0.0);
        }
      }

      _availableYears = List.generate(DateTime.now().year - minYear + 1, (i) => minYear + i);
      if (!_availableYears.contains(_selectedYear)) _selectedYear = _availableYears.last;

      final svcData = <String, Map<String, dynamic>>{};
      for (final o in _rawOrders) {
        final sId = o['service_id'] as String?;
        if (sId == null) continue;
        final title = (o['services'] as Map?)?['title'] as String? ?? 'Unknown';

        if (!svcData.containsKey(sId)) {
          svcData[sId] = {'id': sId, 'title': title, 'count': 0};
        }
        svcData[sId]!['count'] = (svcData[sId]!['count'] as int) + 1;
      }

      final svcList = svcData.values.map((s) {
        final sId = s['id'] as String;
        final avgRating = ratingCount[sId] != null && ratingCount[sId]! > 0
            ? ratingSum[sId]! / ratingCount[sId]!
            : 0.0;

        return {
          'id': sId,
          'title': s['title'],
          'count': s['count'],
          'avgRating': avgRating,
          'reviewCount': ratingCount[sId] ?? 0
        };
      }).toList()..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      setState(() {
        _monthlyStats = tempStats;
        _byService = svcList;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error loading reports: $e");
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _exportMonthlyPDF() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing PDF... Select "Save as PDF" in the print dialog.'),
          duration: Duration(seconds: 3),
          backgroundColor: AppColors.primary,
        ),
      );

      final selectedMonthOrders = _rawOrders.where((o) {
        if (o['created_at'] == null) return false;
        final d = DateTime.parse(o['created_at']).toLocal();
        return d.month == _selectedMonth && d.year == _selectedYear;
      }).toList();

      int totalMonthOrders = selectedMonthOrders.length;
      double totalMonthRevenue = 0.0;

      final serviceDetails = <String, Map<String, dynamic>>{};

      for (final o in selectedMonthOrders) {
        final sId = o['service_id'] as String?;
        if (sId == null) continue;
        final title = (o['services'] as Map?)?['title'] as String? ?? 'Unknown';
        final status = o['status'] as String? ?? '';

        if (!serviceDetails.containsKey(sId)) {
          serviceDetails[sId] = {
            'title': title, 'total': 0, 'delivered': 0,
            'cancelled': 0, 'picked_up': 0, 'revenue': 0.0
          };
        }

        serviceDetails[sId]!['total'] += 1;
        if (status == 'delivered') {
          serviceDetails[sId]!['delivered'] += 1;
          final price = ((o['total_price'] as num?)?.toDouble() ?? 0.0);
          serviceDetails[sId]!['revenue'] += price;
          totalMonthRevenue += price;
        }
        if (status == 'cancelled') serviceDetails[sId]!['cancelled'] += 1;
        if (status == 'picked_up' || status == 'out_for_delivery' || status == 'dropped') {
          serviceDetails[sId]!['picked_up'] += 1;
        }
      }

      final tableData = serviceDetails.entries.map((e) {
        final sId = e.key;
        final data = e.value;

        final relevantReviews = _rawReviews.where((r) => r['service_id'] == sId).toList();
        double avgRating = 0.0;
        if (relevantReviews.isNotEmpty) {
          final sum = relevantReviews.fold(0.0, (prev, element) => prev + ((element['rating'] as num?)?.toDouble() ?? 0.0));
          avgRating = sum / relevantReviews.length;
        }

        return [
          data['title'],
          avgRating > 0 ? avgRating.toStringAsFixed(1) : 'N/A',
          data['total'].toString(),
          (data['picked_up'] + data['delivered']).toString(),
          data['delivered'].toString(),
          data['cancelled'].toString(),
          'BDT ${data['revenue'].toStringAsFixed(0)}'
        ];
      }).toList();

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('EzeeWash Analytics', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                      pw.SizedBox(height: 4),
                      pw.Text('Monthly Performance Report', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Text('${_monthName(_selectedMonth)} $_selectedYear', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 30),

              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPdfSummaryBox('Total Revenue', 'BDT ${totalMonthRevenue.toStringAsFixed(0)}', PdfColors.green50),
                    _buildPdfSummaryBox('Total Orders', '$totalMonthOrders', PdfColors.blue50),
                  ]
              ),
              pw.SizedBox(height: 40),

              pw.Text('Service Breakdown (${_monthName(_selectedMonth)})', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
                headerHeight: 35,
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
                  5: pw.Alignment.center,
                  6: pw.Alignment.centerRight,
                },
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headers: ['Service Name', 'Rating', 'Total', 'Picked Up', 'Delivered', 'Cancelled', 'Revenue'],
                data: tableData.isEmpty ? [['No orders for this month', '', '', '', '', '', '']] : tableData,
              ),

              pw.SizedBox(height: 40),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),
              pw.Text('Generated on ${DateTime.now().toLocal().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            ];
          },
        ),
      );

      // We use layoutPdf because it works safely across Desktop, Web, and Mobile.
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'EzeeWash_Report_${_monthName(_selectedMonth)}_$_selectedYear.pdf',
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  pw.Widget _buildPdfSummaryBox(String title, String value, PdfColor bgColor) {
    return pw.Container(
        width: 230,
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
            color: bgColor,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5)
        ),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
              pw.SizedBox(height: 8),
              pw.Text(value, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            ]
        )
    );
  }

  @override Widget build(BuildContext context) {
    return Column(children: [
      Container(
        height: 72, padding: const EdgeInsets.symmetric(horizontal: 32), decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text('Reports & Analytics', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text)), Text(widget.isSuperAdmin ? 'Business performance overview' : 'Your Store Performance Overview', style: GoogleFonts.inter(fontSize: 14, color: AppColors.subtext))]),
          const Spacer(),

          Container(
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary),
                  tooltip: 'Export Monthly PDF',
                  onPressed: _rawOrders.isEmpty ? null : _exportMonthlyPDF
              )
          ),
          const SizedBox(width: 12),

          Container(decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Icon(Icons.refresh_rounded, color: AppColors.text), onPressed: _loadReports)),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                color: Colors.red.withOpacity(0.1),
                child: Text('Error: $_error', style: const TextStyle(color: Colors.red)),
              ),

            _MonthlyPerformanceCard(
              selectedMonth: _selectedMonth,
              selectedYear: _selectedYear,
              availableYears: _availableYears,
              monthlyStats: _monthlyStats,
              onMonthChanged: (val) => setState(() => _selectedMonth = val!),
              onYearChanged: (val) => setState(() => _selectedYear = val!),
            ),
            const SizedBox(height: 32),

            if (_byService.isNotEmpty) ...[
              Text('Orders by Service (All-Time)', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)), const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(children: _byService.map((s) {
                  final max = (_byService.first['count'] as int).toDouble();
                  final count = (s['count'] as int).toDouble();
                  final avg = s['avgRating'] as double;
                  final revCount = s['reviewCount'] as int;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ServiceReviewsScreen(
                              serviceId: s['id'],
                              serviceTitle: s['title'],
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s['title'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.text)),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.star_rounded, color: avg > 0 ? Colors.amber : Colors.grey.shade400, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                              avg > 0 ? avg.toStringAsFixed(1) : 'No ratings',
                                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: avg > 0 ? Colors.amber.shade700 : Colors.grey.shade500)
                                          ),
                                          if (revCount > 0)
                                            Text(' ($revCount reviews)', style: GoogleFonts.inter(fontSize: 13, color: AppColors.subtext)),
                                        ],
                                      )
                                    ]
                                ),
                                Row(
                                  children: [
                                    Text('${s['count']} orders', style: GoogleFonts.inter(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.subtext.withOpacity(0.5)),
                                  ],
                                )
                              ]
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(value: max > 0 ? count / max : 0, minHeight: 8, backgroundColor: AppColors.background, color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                        ]),
                      ),
                    ),
                  );
                }).toList()),
              ),
            ],
          ]),
        ),
      ),
    ]);
  }

  String _monthName(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];
}

class _MonthlyPerformanceCard extends StatelessWidget {
  final int selectedMonth;
  final int selectedYear;
  final List<int> availableYears;
  final Map<String, MonthlyStatData> monthlyStats;
  final ValueChanged<int?> onMonthChanged;
  final ValueChanged<int?> onYearChanged;

  const _MonthlyPerformanceCard({
    required this.selectedMonth,
    required this.selectedYear,
    required this.availableYears,
    required this.monthlyStats,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    final String targetKey = '$selectedMonth-$selectedYear';
    final stats = monthlyStats[targetKey] ?? MonthlyStatData();

    final double revenue = stats.revenue;
    final int orders = stats.orders;
    final int delivered = stats.delivered;
    final double avgValue = orders > 0 ? revenue / orders : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Monthly Performance', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)),
              Row(
                children: [
                  _buildDropdown(
                    value: selectedMonth,
                    items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_monthName(i + 1)))),
                    onChanged: onMonthChanged,
                  ),
                  const SizedBox(width: 12),
                  _buildDropdown(
                    value: selectedYear,
                    items: availableYears.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                    onChanged: onYearChanged,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 24),

          LayoutBuilder(
              builder: (context, constraints) {
                final box1 = _buildKpiBox('Total Revenue', '৳${revenue.toStringAsFixed(0)}', Icons.attach_money, AppColors.success);
                final box2 = _buildKpiBox('Total Orders', '$orders', Icons.receipt_long_outlined, AppColors.primary);
                final box3 = _buildKpiBox('Avg Order Value', '৳${avgValue.toStringAsFixed(0)}', Icons.bar_chart, AppColors.info);
                final box4 = _buildKpiBox('Delivered', '$delivered', Icons.check_circle_outline, AppColors.success);

                if (constraints.maxWidth > 800) {
                  return Row(children: [box1, const SizedBox(width: 16), box2, const SizedBox(width: 16), box3, const SizedBox(width: 16), box4]);
                } else {
                  return Column(
                    children: [
                      Row(children: [box1, const SizedBox(width: 16), box2]),
                      const SizedBox(height: 16),
                      Row(children: [box3, const SizedBox(width: 16), box4]),
                    ],
                  );
                }
              }
          ),
        ],
      ),
    );
  }

  Widget _buildKpiBox(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border)
        ),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22)
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.inter(color: AppColors.subtext, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text))
                    ]
                )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({required int value, required List<DropdownMenuItem<int>> items, required ValueChanged<int?> onChanged}) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          icon: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.text),
          ),
          isDense: true,
          dropdownColor: AppColors.surface,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  String _monthName(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];
}