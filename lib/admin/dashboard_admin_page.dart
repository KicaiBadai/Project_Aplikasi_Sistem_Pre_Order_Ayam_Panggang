import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'report_admin_page.dart';
import 'customer_admin_page.dart';
import 'payment_methods_admin_page.dart';
import '../services/notification_service.dart';

class DashboardAdminPage extends StatefulWidget {
  final VoidCallback? onViewAllOrders;
  const DashboardAdminPage({super.key, this.onViewAllOrders});

  @override
  State<DashboardAdminPage> createState() => _DashboardAdminPageState();
}

class _DashboardAdminPageState extends State<DashboardAdminPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  int totalProduk = 0;
  int totalCustomer = 0;
  int totalInvoice = 0;
  int pendingPayment = 0;
  List recentOrders = [];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id', null).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    try {
      final produk = await supabase.from('tabel_barang').select();
      final customer = await supabase
          .from('tabel_user')
          .select()
          .eq('role', 'customer');
      final invoice = await supabase.from('tabel_invoice').select();
      final pending = await supabase
          .from('tabel_pembayaran')
          .select()
          .eq('status_verifikasi', 'pending');
      
      final orders = await supabase
          .from('tabel_invoice')
          .select('''
            *,
            tabel_metode_pembayaran (
              id_metode,
              nama_metode
            ),
            tabel_pembayaran (
              id_pembayaran,
              bukti_transfer,
              status_verifikasi,
              catatan_admin
            ),
            tabel_pesanan (
              qty,
              harga,
              subtotal,
              tabel_barang (
                nama_barang,
                foto
              )
            )
          ''')
          .order('id_invoice', ascending: false)
          .limit(5);

      final users = await supabase.from('tabel_user').select('auth_id, email');
      final userMap = {for (var u in users) u['auth_id']: u['email']};

      List<Map<String, dynamic>> modifiedData = List<Map<String, dynamic>>.from(orders);
      for (var order in modifiedData) {
        order['email'] = userMap[order['auth_id']] ?? '-';
      }

      setState(() {
        totalProduk = produk.length;
        totalCustomer = customer.length;
        totalInvoice = invoice.length;
        pendingPayment = pending.length;
        recentOrders = modifiedData;
        isLoading = false;
      });
    } catch (e) {
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal memuat dashboard')));
        setState(() => isLoading = false);
      }
    }
  }

  String formatRupiah(dynamic amount) {
    final number = (amount ?? 0) as num;
    return NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(number);
  }

  String formatDateTime(String? timestamp) {
    if (timestamp == null) return '-';
    try {
      DateTime parsed = DateTime.parse(timestamp);
      if (!parsed.isUtc) {
        parsed = DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
          parsed.microsecond,
        );
      }
      final localDateTime = parsed.toLocal();
      return DateFormat('dd-MM-yyyy HH:mm').format(localDateTime);
    } catch (e) {
      return timestamp;
    }
  }

  String _getFormattedDate() {
    try {
      return DateFormat('EEEE, d MMMM yyyy', 'id').format(DateTime.now());
    } catch (_) {
      try {
        return DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
      } catch (e) {
        return DateTime.now().toString();
      }
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'dibayar':
        return Colors.green;
      case 'diproses':
        return Colors.blue;
      case 'dikirim':
        return Colors.purple;
      case 'selesai':
        return Colors.teal;
      case 'ditolak':
        return Colors.red;
      default:
        return const Color(0xFFFF8C42);
    }
  }

  Future<void> updateStatus({
    required int idInvoice,
    required String newInvoiceStatus,
    required String newPaymentStatus,
  }) async {
    try {
      final currentInvoice = await supabase
          .from('tabel_invoice')
          .select()
          .eq('id_invoice', idInvoice)
          .single();

      if (newInvoiceStatus == 'dibayar' &&
          currentInvoice['status'] != 'dibayar') {
        final pesanan = await supabase
            .from('tabel_pesanan')
            .select()
            .eq('id_invoice', idInvoice);

        for (final item in pesanan) {
          final barang = await supabase
              .from('tabel_barang')
              .select()
              .eq('id_barang', item['id_barang'])
              .single();

          int stokSekarang = barang['stok'] ?? 0;
          int qtyPesanan = item['qty'] ?? 0;

          if (stokSekarang < qtyPesanan) {
            throw Exception('Stok ${barang['nama_barang']} tidak mencukupi');
          }

          await supabase
              .from('tabel_barang')
              .update({'stok': stokSekarang - qtyPesanan})
              .eq('id_barang', item['id_barang']);
        }
      }

      await supabase
          .from('tabel_invoice')
          .update({'status': newInvoiceStatus})
          .eq('id_invoice', idInvoice);

      await supabase
          .from('tabel_pembayaran')
          .update({'status_verifikasi': newPaymentStatus})
          .eq('id_invoice', idInvoice);

      // Kirim notifikasi ke customer
      try {
        final userData = await supabase
            .from('tabel_user')
            .select('email')
            .eq('auth_id', currentInvoice['auth_id'])
            .single();
        final customerEmail = userData['email'];
        if (customerEmail != null) {
          await NotificationService.sendNotificationToCustomer(
            customerEmail: customerEmail,
            invoiceCode: currentInvoice['kode_invoice'] ?? idInvoice.toString(),
            status: newInvoiceStatus,
          );
        }
      } catch (notifErr) {
        print('Gagal kirim notifikasi ke customer: $notifErr');
      }

      await loadDashboard();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status berhasil diperbarui'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print(e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _editCatatanAdmin(Map order, StateSetter setStateSheet) async {
    final controller =
        TextEditingController(text: order['catatan_admin'] ?? '');
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Catatan Admin'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Masukkan catatan...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8C42),
            ),
            onPressed: () async {
              try {
                await supabase
                    .from('tabel_invoice')
                    .update({'catatan_admin': controller.text.trim()})
                    .eq('id_invoice', order['id_invoice']);
                
                setStateSheet(() {
                  order['catatan_admin'] = controller.text.trim();
                });
                
                await loadDashboard();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Catatan admin berhasil diperbarui'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                print(e);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal memperbarui catatan admin'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showZoomableImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.black87,
        child: Stack(
          children: [
            InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 60, color: Colors.white),
                      SizedBox(height: 10),
                      Text(
                        'Gagal memuat gambar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showDetail(Map order) {
    final pembayaran = order['tabel_pembayaran'];
    String? buktiTransfer;
    if (pembayaran != null && pembayaran.isNotEmpty) {
      buktiTransfer = pembayaran[0]['bukti_transfer'];
    }
    final items = order['tabel_pesanan'] as List;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSheet) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFEF7E8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.6,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, controller) => SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INV-${order['kode_invoice']}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatDateTime(order['created_at']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // CARD 1: Status & Ringkasan Pembayaran
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Status Pesanan',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: getStatusColor(order['status'] ?? 'pending').withOpacity(0.1),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                (order['status'] ?? 'PENDING').toUpperCase(),
                                style: TextStyle(
                                  color: getStatusColor(order['status'] ?? 'pending'),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildDetailItem(
                          icon: Icons.payments_outlined,
                          label: 'Metode Bayar',
                          value: order['tabel_metode_pembayaran']?['nama_metode'] ?? '-',
                        ),
                        const SizedBox(height: 12),
                        _buildDetailItem(
                          icon: Icons.monetization_on_outlined,
                          label: 'Total Tagihan',
                          value: formatRupiah(order['total']),
                          valueColor: const Color(0xFFFF8C42),
                          isBoldValue: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CARD 2: Informasi Pelanggan & Pengiriman
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informasi Penerima',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const Divider(height: 24),
                        _buildDetailItem(
                          icon: Icons.person_outline,
                          label: 'Nama Penerima',
                          value: order['nama_penerima'] ?? '-',
                        ),
                        const SizedBox(height: 12),
                        _buildDetailItem(
                          icon: Icons.phone_android_outlined,
                          label: 'No. Telepon',
                          value: order['no_hp'] ?? '-',
                        ),
                        const SizedBox(height: 12),
                        _buildDetailItem(
                          icon: Icons.mail_outline,
                          label: 'Email',
                          value: order['email'] ?? '-',
                        ),
                        const SizedBox(height: 12),
                        _buildDetailItem(
                          icon: Icons.location_on_outlined,
                          label: 'Alamat Kirim',
                          value: order['alamat'] ?? '-',
                        ),
                        const SizedBox(height: 12),
                        _buildDetailItem(
                          icon: Icons.edit_note_outlined,
                          label: 'Catatan Pembeli',
                          value: order['catatan'] ?? '-',
                          valueStyle: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CARD 3: Catatan Admin (CRUD)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Catatan Admin',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Color(0xFFFF8C42), size: 20),
                              onPressed: () => _editCatatanAdmin(order, setStateSheet),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFFF8C42).withOpacity(0.1),
                                padding: const EdgeInsets.all(6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8C42).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFF8C42).withOpacity(0.15)),
                          ),
                          child: Text(
                            (order['catatan_admin'] != null && order['catatan_admin'].toString().isNotEmpty)
                                ? order['catatan_admin']
                                : 'Belum ada catatan dari admin.',
                            style: TextStyle(
                              color: (order['catatan_admin'] != null && order['catatan_admin'].toString().isNotEmpty)
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade500,
                              fontStyle: (order['catatan_admin'] != null && order['catatan_admin'].toString().isNotEmpty)
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CARD 4: Item Pesanan
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daftar Item',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const Divider(height: 24),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final item = items[i];
                            final barang = item['tabel_barang'];
                            return Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    barang['foto'] ?? '',
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.image_not_supported, size: 20, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        barang['nama_barang'] ?? '-',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item['qty']}x @ ${formatRupiah(item['harga'])}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatRupiah(item['subtotal']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CARD 5: Bukti Transfer
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bukti Pembayaran',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const Divider(height: 24),
                        if (buktiTransfer != null)
                          GestureDetector(
                            onTap: () => _showZoomableImage(buktiTransfer!),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    buktiTransfer,
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 200,
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: Text('Gagal memuat gambar bukti transfer'),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: const Center(
                              child: Text(
                                'Belum mengunggah bukti transfer.',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // BOTTOM ACTION BUTTONS
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildActionButton('Konfirmasi', Colors.green, () async {
                        Navigator.pop(context);
                        await updateStatus(
                          idInvoice: order['id_invoice'],
                          newInvoiceStatus: 'dibayar',
                          newPaymentStatus: 'verified',
                        );
                      }),
                      _buildActionButton('Proses', Colors.blue, () async {
                        Navigator.pop(context);
                        await updateStatus(
                          idInvoice: order['id_invoice'],
                          newInvoiceStatus: 'diproses',
                          newPaymentStatus: 'verified',
                        );
                      }),
                      _buildActionButton('Kirim', Colors.purple, () async {
                        Navigator.pop(context);
                        await updateStatus(
                          idInvoice: order['id_invoice'],
                          newInvoiceStatus: 'dikirim',
                          newPaymentStatus: 'verified',
                        );
                      }),
                      _buildActionButton('Selesai', Colors.teal, () async {
                        Navigator.pop(context);
                        await updateStatus(
                          idInvoice: order['id_invoice'],
                          newInvoiceStatus: 'selesai',
                          newPaymentStatus: 'verified',
                        );
                      }),
                      _buildActionButton('Tolak', Colors.red, () async {
                        Navigator.pop(context);
                        await updateStatus(
                          idInvoice: order['id_invoice'],
                          newInvoiceStatus: 'ditolak',
                          newPaymentStatus: 'rejected',
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBoldValue = false,
    TextStyle? valueStyle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: valueStyle ?? TextStyle(
              fontSize: 13,
              fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: 98,
      height: 38,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadDashboard,
      color: const Color(0xFFFF8C42),
      child: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF8C42)),
            )
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PREMIUM HEADER CARD BANNER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF8C42), Color(0xFFFFAD73)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF8C42).withOpacity(0.25),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Halo, Admin! 👋',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Pantau status pesanan dan penjualan ayam panggang dengan mudah hari ini.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, size: 12, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                _getFormattedDate(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // STATISTIK - ROW LAYOUTS (No Vertical Overflow!)
                  const Text(
                    '📊 Ikhtisar Toko',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Total Produk',
                          value: totalProduk.toString(),
                          icon: Icons.inventory_2_outlined,
                          color: const Color(0xFFFF8C42),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Customer',
                          value: totalCustomer.toString(),
                          icon: Icons.people_outline,
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Invoice',
                          value: totalInvoice.toString(),
                          icon: Icons.receipt_outlined,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Pending Pay',
                          value: pendingPayment.toString(),
                          icon: Icons.payments_outlined,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // MENU CEPAT
                  const Text(
                    '⚡ Menu Cepat',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: MenuButton(
                          icon: Icons.bar_chart_outlined,
                          title: "Laporan",
                          color: const Color(0xFFFF8C42),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ReportAdminPage(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MenuButton(
                          icon: Icons.people_outline,
                          title: "Customer",
                          color: const Color(0xFF3B82F6),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CustomerAdminPage(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MenuButton(
                          icon: Icons.payment_outlined,
                          title: "Metode Bayar",
                          color: const Color(0xFF10B981),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PaymentMethodsAdminPage(),
                              ),
                            ).then((_) => loadDashboard());
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // PESANAN TERBARU HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '📦 Pesanan Terbaru',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (recentOrders.isNotEmpty && widget.onViewAllOrders != null)
                        TextButton(
                          onPressed: widget.onViewAllOrders,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFFF8C42),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Lihat Semua',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_right, size: 16),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (recentOrders.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox,
                            size: 40,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Belum ada pesanan masuk',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentOrders.length,
                      itemBuilder: (context, index) {
                        final order = recentOrders[index];
                        final status = order['status'] ?? 'pending';
                        final statusColor = getStatusColor(status);

                        // Generate items summary
                        final itemsList = order['tabel_pesanan'] as List? ?? [];
                        final itemsSummary = itemsList.map((item) {
                          final barang = item['tabel_barang'];
                          final nama = barang?['nama_barang'] ?? '-';
                          final qty = item['qty'] ?? 0;
                          return '$nama ($qty)';
                        }).join(', ');

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.grey.shade100, width: 0.5),
                          ),
                          color: Colors.white,
                          child: InkWell(
                            onTap: () => showDetail(order),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'INV-${order['kode_invoice']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${order['nama_penerima'] ?? '-'} (${order['email'] ?? '-'})',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.restaurant_menu, size: 14, color: Colors.grey.shade500),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          itemsSummary.isNotEmpty ? itemsSummary : 'Tidak ada detail barang',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(height: 1),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        formatRupiah(order['total']),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFF8C42),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Text(
                                            formatDateTime(order['created_at']),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MenuButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const MenuButton({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
