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

          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
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
                padding: const EdgeInsets.all(15),
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
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              invoice['tanggal'] ?? '-',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor(status),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusText(status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
                          style: TextStyle(fontSize: 15),
                        ),
                        Text(
                          'Rp ${invoice['total']}',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.orange,
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
                        const Text('Metode', style: TextStyle(fontSize: 15)),
                        Text(
                          invoice['tabel_metode_pembayaran']?['nama_metode'] ??
                              'Tidak ada metode',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
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
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.admin_panel_settings,
                                  color: Colors.blue,
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Catatan Admin',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              invoice['catatan_admin'],
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
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
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Detail Pesanan'),
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
