import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'order_detail_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  OrdersPageState createState() => OrdersPageState();
}

class OrdersPageState extends State<OrdersPage> {
  final supabase = Supabase.instance.client;

  List invoiceList = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    getInvoices();
  }

  // method public untuk refresh dari luar (HomePage)
  void refreshOrders() {
    getInvoices();
  }

  Future<void> getInvoices() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) return;

      final data = await supabase
          .from('tabel_invoice')
          .select('''
      *,
      tabel_metode_pembayaran!tabel_invoice_id_metode_fkey (
        id_metode,
        nama_metode,
        nomor_pembayaran,
        atas_nama,
        logo
      )
    ''')
          .eq('auth_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        invoiceList = data;
        isLoading = false;
      });
    } catch (e) {
      print(e);

      setState(() {
        isLoading = false;
      });
    }
  }

  Color statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'menunggu_verifikasi':
        return Colors.blue;
      case 'dibayar':
        return Colors.green;
      case 'diproses':
        return Colors.deepPurple;
      case 'selesai':
        return Colors.teal;
      case 'ditolak':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String statusText(String status) {
    switch (status) {
      case 'pending':
        return 'Belum Bayar';
      case 'menunggu_verifikasi':
        return 'Menunggu Verifikasi';
      case 'dibayar':
        return 'Sudah Dibayar';
      case 'diproses':
        return 'Sedang Diproses';
      case 'selesai':
        return 'Selesai';
      case 'ditolak':
        return 'Pembayaran Ditolak';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (invoiceList.isEmpty) {
      return const Center(
        child: Text('Belum ada pesanan', style: TextStyle(fontSize: 16)),
      );
    }

    return RefreshIndicator(
      onRefresh: getInvoices,
      child: ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: invoiceList.length,
        itemBuilder: (context, index) {
          final invoice = invoiceList[index];
          final status = invoice['status'] ?? 'pending';

          return Container(
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Colors.grey.shade100,
                width: 0.5,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OrderDetailPage(invoiceId: invoice['id_invoice']),
                  ),
                );
                getInvoices();
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'INV-${invoice['kode_invoice']}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              invoice['tanggal'] ?? '-',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            statusText(status).toUpperCase(),
                            style: TextStyle(
                              color: statusColor(status),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // TOTAL
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Pembayaran',
                          style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Rp ${invoice['total']}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFFFF8C42),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // METODE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Metode', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                        Text(
                          invoice['tabel_metode_pembayaran']?['nama_metode'] ??
                              'Tidak ada metode',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    // CATATAN ADMIN
                    if (invoice['catatan_admin'] != null &&
                        invoice['catatan_admin'].toString().isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF8C42).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFF8C42).withOpacity(0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.admin_panel_settings_rounded,
                                  color: Color(0xFFFF8C42),
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Catatan Admin',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF8C42),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              invoice['catatan_admin'],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],
                    // BUTTON DETAIL
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8C42),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderDetailPage(
                                invoiceId: invoice['id_invoice'],
                              ),
                            ),
                          );
                          getInvoices();
                        },
                        icon: const Icon(Icons.receipt_long, size: 16),
                        label: const Text('Detail Pesanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
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
