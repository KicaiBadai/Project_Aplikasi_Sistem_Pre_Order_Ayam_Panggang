import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CustomerAdminPage extends StatefulWidget {
  const CustomerAdminPage({super.key});

  @override
  State<CustomerAdminPage> createState() => _CustomerAdminPageState();
}

class _CustomerAdminPageState extends State<CustomerAdminPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> customers = [];

  @override
  void initState() {
    super.initState();
    loadCustomers();
  }

  Future<void> loadCustomers() async {
    try {
      setState(() => isLoading = true);
      final data = await supabase
          .from('tabel_user')
          .select()
          .eq('role', 'customer')
          .order('created_at', ascending: false);
      List<Map<String, dynamic>> result = [];
      for (final user in data) {
        final invoices = await supabase
            .from('tabel_invoice')
            .select('total,status')
            .eq('auth_id', user['auth_id']);
        int totalBelanja = 0;
        int jumlahTransaksi = invoices.length;
        for (final inv in invoices) {
          if (inv['status'] == 'selesai' || inv['status'] == 'dibayar') {
            totalBelanja += (inv['total'] ?? 0) as int;
          }
        }
        result.add({
          ...user,
          'jumlah_transaksi': jumlahTransaksi,
          'total_belanja': totalBelanja,
        });
      }
      result.sort(
        (a, b) =>
            (b['total_belanja'] as int).compareTo(a['total_belanja'] as int),
      );
      setState(() {
        customers = result;
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

  void showDetail(Map customer) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFFF8C42),
              child: Text(
                (customer['nama_user'] ?? 'C')[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                customer['nama_user'] ?? '-',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(Icons.email, 'Email', customer['email'] ?? '-'),
            const Divider(),
            _infoRow(Icons.phone, 'No HP', customer['no_hp'] ?? '-'),
            const Divider(),
            _infoRow(Icons.home, 'Alamat', customer['alamat'] ?? '-'),
            const Divider(),
            _infoRow(
              Icons.receipt,
              'Jumlah Transaksi',
              customer['jumlah_transaksi'].toString(),
            ),
            const Divider(),
            _infoRow(
              Icons.money,
              'Total Belanja',
              rupiah(customer['total_belanja']),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF8C42),
            ),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFFF8C42)),
          const SizedBox(width: 12),
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalCustomer = customers.length;
    int totalBelanjaSemua = customers.fold(
      0,
      (sum, item) => sum + ((item['total_belanja'] ?? 0) as int),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFEF7E8),
      appBar: AppBar(
        title: const Text(
          'Data Customer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFF8C42),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadCustomers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadCustomers,
        color: const Color(0xFFFF8C42),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF8C42)),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Customer',
                            totalCustomer.toString(),
                            Icons.people,
                            Colors.orange.shade50,
                            const Color(0xFFFF8C42),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Total Belanja',
                            rupiah(totalBelanjaSemua),
                            Icons.attach_money,
                            Colors.orange.shade50,
                            const Color(0xFFFF8C42),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: customers.isEmpty
                        ? const Center(
                            child: Text(
                              'Belum ada customer',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: customers.length,
                            itemBuilder: (context, index) {
                              final customer = customers[index];
                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: InkWell(
                                  onTap: () => showDetail(customer),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 28,
                                          backgroundColor: const Color(
                                            0xFFFF8C42,
                                          ).withOpacity(0.1),
                                          child: Text(
                                            (customer['nama_user'] ?? 'C')[0]
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFFF8C42),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                customer['nama_user'] ?? '-',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                customer['email'] ?? '-',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.receipt,
                                                    size: 14,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${customer['jumlah_transaksi']} transaksi',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFFFF8C42,
                                                ).withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                rupiah(
                                                  customer['total_belanja'],
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFFF8C42),
                                                ),
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
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color bgColor,
    Color iconColor,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
