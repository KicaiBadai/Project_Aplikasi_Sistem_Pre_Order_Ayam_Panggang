import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class OrdersAdminPage extends StatefulWidget {
  const OrdersAdminPage({super.key});

  @override
  State<OrdersAdminPage> createState() => _OrdersAdminPageState();
}

class _OrdersAdminPageState extends State<OrdersAdminPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List orders = [];

  @override
  void initState() {
    super.initState();
    getOrders();
  }

  Future<void> getOrders() async {
    try {
      final data = await supabase
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
          .order('id_invoice', ascending: false);
      setState(() {
        orders = data;
        isLoading = false;
      });
    } catch (e) {
      print(e);
      setState(() => isLoading = false);
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

      await getOrders();

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
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Detail Pesanan',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _buildInfoRow('Invoice', 'INV-${order['kode_invoice']}'),
                _buildInfoRow('Total', formatRupiah(order['total'])),
                _buildInfoRow(
                  'Metode',
                  order['tabel_metode_pembayaran']?['nama_metode'] ?? '-',
                ),
                _buildInfoRow(
                  'Status',
                  order['status'] ?? '-',
                  status: true,
                  statusColor: getStatusColor(order['status'] ?? 'pending'),
                ),
                const Divider(height: 32),
                const Text(
                  'Item Pesanan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final barang = item['tabel_barang'];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                barang['foto'] ?? '',
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 70,
                                  height: 70,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.image_not_supported),
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
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Qty: ${item['qty']}'),
                                  Text('Harga: ${formatRupiah(item['harga'])}'),
                                  Text(
                                    'Subtotal: ${formatRupiah(item['subtotal'])}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 32),
                const Text(
                  'Bukti Transfer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
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
                            height: 250,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 250,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Text('Gagal memuat gambar'),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.zoom_in,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Zoom',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text('Belum upload bukti transfer'),
                    ),
                  ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
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
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool status = false,
    Color? statusColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
          if (status)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor?.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                value.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            )
          else
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: 95,
      height: 36,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF8C42)),
      );
    }

    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Belum ada pesanan',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: getOrders,
      color: const Color(0xFFFF8C42),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final status = order['status'] ?? 'pending';
          final statusColor = getStatusColor(status);
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: InkWell(
              onTap: () => showDetail(order),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.receipt_long,
                            color: statusColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'INV-${order['kode_invoice']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatRupiah(order['total']),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.payment,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order['tabel_metode_pembayaran']?['nama_metode'] ??
                              '-',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8C42).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Detail',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFF8C42),
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 10,
                                color: Color(0xFFFF8C42),
                              ),
                            ],
                          ),
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
    );
  }
}
