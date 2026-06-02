import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ReportAdminPage extends StatefulWidget {
  const ReportAdminPage({super.key});

  @override
  State<ReportAdminPage> createState() => _ReportAdminPageState();
}

class _ReportAdminPageState extends State<ReportAdminPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> invoices = [];
  bool isLoading = true;
  DateTime? startDate;
  DateTime? endDate;
  int totalOmzet = 0;
  int totalTransaksi = 0;

  @override
  void initState() {
    super.initState();
    loadReport();
  }

  Future<void> loadReport() async {
    setState(() => isLoading = true);
    try {
      var query = supabase.from('tabel_invoice').select();
      if (startDate != null) {
        query = query.gte('created_at', startDate!.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte(
          'created_at',
          endDate!.add(const Duration(days: 1)).toIso8601String(),
        );
      }
      final List<dynamic> data = await query;
      int omzet = 0;
      for (final item in data) {
        final status = item['status'] as String?;
        if (status == 'selesai' || status == 'dibayar') {
          omzet += (item['total'] ?? 0) as int;
        }
      }
      setState(() {
        invoices = data.cast<Map<String, dynamic>>();
        totalOmzet = omzet;
        totalTransaksi = data.length;
        isLoading = false;
      });
    } catch (e) {
      debugPrint(e.toString());
      setState(() => isLoading = false);
    }
  }

  String rupiah(int value) {
    return NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  String formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _requestStoragePermission() async {
    if (await Permission.storage.isGranted) return;
    if (await Permission.manageExternalStorage.isGranted) return;

    if (await Permission.manageExternalStorage.request().isGranted) return;
    if (await Permission.storage.request().isGranted) return;

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Izin Penyimpanan Diperlukan'),
          content: const Text(
            'Untuk menyimpan laporan PDF, aplikasi memerlukan izin akses penyimpanan. Silakan izinkan di pengaturan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Nanti'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Buka Pengaturan'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> exportPdf() async {
    await _requestStoragePermission();

    bool hasPermission =
        await Permission.storage.isGranted ||
        await Permission.manageExternalStorage.isGranted;
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Izin penyimpanan tidak diberikan, PDF tidak dapat disimpan.',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final pdf = pw.Document();

      final tableData = invoices.map((e) {
        final createdAt = e['created_at']?.toString();
        final tanggal = (createdAt != null && createdAt.length >= 10)
            ? createdAt.substring(0, 10)
            : '-';
        return [
          e['kode_invoice'] ?? '-',
          tanggal,
          rupiah((e['total'] ?? 0) as int),
          e['status'] ?? '-',
        ];
      }).toList();

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Laporan Penjualan PreOrder Ayam',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                if (startDate != null && endDate != null)
                  pw.Text(
                    'Periode: ${formatDate(startDate)} - ${formatDate(endDate)}',
                  ),
                pw.SizedBox(height: 5),
                pw.Text('Total Transaksi: $totalTransaksi'),
                pw.Text('Total Omzet: ${rupiah(totalOmzet)}'),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  headers: ['Invoice', 'Tanggal', 'Total', 'Status'],
                  data: tableData,
                  border: pw.TableBorder.all(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
              ],
            );
          },
        ),
      );

      final downloadsDir = Directory('/storage/emulated/0/Download');
      Directory targetDir;
      if (await downloadsDir.exists()) {
        targetDir = downloadsDir;
      } else {
        targetDir =
            await getExternalStorageDirectory() ??
            await getTemporaryDirectory();
      }

      final fileName =
          'laporan_penjualan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${targetDir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF tersimpan di:\n${file.path}'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> pickDateRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFFFF8C42)),
          ),
          child: child!,
        );
      },
    );
    if (result != null) {
      startDate = result.start;
      endDate = result.end;
      await loadReport();
    }
  }

  void resetFilter() async {
    startDate = null;
    endDate = null;
    await loadReport();
  }

  String getStatusLabel(String status) {
    switch (status) {
      case 'selesai':
        return '✅ Selesai';
      case 'dibayar':
        return '💰 Dibayar';
      case 'pending':
        return '⏳ Pending';
      case 'menunggu_verifikasi':
        return '⌛ Menunggu Verifikasi';
      default:
        return status;
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'selesai':
        return Colors.green;
      case 'dibayar':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'menunggu_verifikasi':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF7E8),
      appBar: AppBar(
        title: const Text(
          'Laporan Penjualan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFF8C42),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: resetFilter,
            tooltip: 'Reset filter',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: exportPdf,
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFF8C42)),
                  SizedBox(height: 16),
                  Text(
                    'Memuat laporan...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Card Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildSummaryCard(
                        'Total Omzet',
                        rupiah(totalOmzet),
                        Icons.money,
                        const Color(0xFFFF8C42),
                      ),
                      const SizedBox(width: 16),
                      _buildSummaryCard(
                        'Total Transaksi',
                        totalTransaksi.toString(),
                        Icons.receipt,
                        Colors.blue,
                      ),
                    ],
                  ),
                ),
                // Filter Panel
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.filter_alt,
                                color: Color(0xFFFF8C42),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Filter Tanggal',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              if (startDate != null || endDate != null)
                                TextButton.icon(
                                  onPressed: resetFilter,
                                  icon: const Icon(Icons.clear, size: 18),
                                  label: const Text('Reset'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: pickDateRange,
                                  icon: const Icon(Icons.calendar_today),
                                  label: Text(
                                    startDate != null && endDate != null
                                        ? '${formatDate(startDate)} - ${formatDate(endDate)}'
                                        : 'Pilih Rentang Tanggal',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFFFF8C42),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // List Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text(
                        'Daftar Invoice',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${invoices.length} item',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // List Invoice
                Expanded(
                  child: invoices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Tidak ada data',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                startDate != null && endDate != null
                                    ? 'Tidak ada transaksi pada periode tersebut'
                                    : 'Belum ada transaksi',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: invoices.length,
                          itemBuilder: (context, index) {
                            final item = invoices[index];
                            final status = item['status'] ?? '-';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: getStatusColor(
                                      status,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.receipt,
                                    color: getStatusColor(status),
                                  ),
                                ),
                                title: Text(
                                  item['kode_invoice'] ?? '-',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      getStatusLabel(status),
                                      style: TextStyle(
                                        color: getStatusColor(status),
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (item['created_at'] != null)
                                      Text(
                                        DateFormat('dd/MM/yyyy HH:mm').format(
                                          DateTime.parse(item['created_at']),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Text(
                                  rupiah((item['total'] ?? 0) as int),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFFFF8C42),
                                  ),
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
