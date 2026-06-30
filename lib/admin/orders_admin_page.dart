import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';

class OrdersAdminPage extends StatefulWidget {
  const OrdersAdminPage({super.key});

  @override
  State<OrdersAdminPage> createState() => _OrdersAdminPageState();
}

class _OrdersAdminPageState extends State<OrdersAdminPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List orders = [];
  List allOrders = [];
  DateTime? selectedDate;
  int? selectedMonth;
  int? selectedYear;

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

      final users = await supabase.from('tabel_user').select('auth_id, email');
      final userMap = {for (var u in users) u['auth_id']: u['email']};

      List<Map<String, dynamic>> modifiedData = List<Map<String, dynamic>>.from(data);
      for(var order in modifiedData) {
        order['email'] = userMap[order['auth_id']] ?? '-';
      }

      setState(() {
        allOrders = modifiedData;
        isLoading = false;
      });
      _applyFilters();
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

  String formatDateTime(String? timestamp) {
    if (timestamp == null) return '-';
    try {
      DateTime parsed = DateTime.parse(timestamp);
      // If the string doesn't contain timezone info, DateTime.parse parses it as local.
      // But database stores it in UTC, so we force it to UTC component-wise before converting to local.
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

  String _getMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month - 1];
  }

  void _applyFilters() {
    List filtered = allOrders;

    if (selectedDate != null) {
      filtered = filtered.where((order) {
        final createdAtStr = order['created_at'];
        if (createdAtStr == null) return false;
        final orderDate = DateTime.parse(createdAtStr).toLocal();
        return orderDate.year == selectedDate!.year &&
            orderDate.month == selectedDate!.month &&
            orderDate.day == selectedDate!.day;
      }).toList();
    } else if (selectedMonth != null && selectedYear != null) {
      filtered = filtered.where((order) {
        final createdAtStr = order['created_at'];
        if (createdAtStr == null) return false;
        final orderDate = DateTime.parse(createdAtStr).toLocal();
        return orderDate.year == selectedYear &&
            orderDate.month == selectedMonth;
      }).toList();
    }

    setState(() {
      orders = filtered;
    });
  }

  void _clearAllFilters() {
    setState(() {
      selectedDate = null;
      selectedMonth = null;
      selectedYear = null;
      orders = allOrders;
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF8C42),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedMonth = null;
        selectedYear = null;
        _applyFilters();
      });
    }
  }

  Future<void> _pickMonthYear() async {
    int tempMonth = selectedMonth ?? DateTime.now().month;
    int tempYear = selectedYear ?? DateTime.now().year;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Pilih Bulan & Tahun',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            setDialogState(() => tempYear--);
                          },
                          icon: const Icon(Icons.chevron_left),
                          color: const Color(0xFFFF8C42),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8C42).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tempYear.toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF8C42),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setDialogState(() => tempYear++);
                          },
                          icon: const Icon(Icons.chevron_right),
                          color: const Color(0xFFFF8C42),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2.2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final monthVal = index + 1;
                        final isSelected = tempMonth == monthVal;
                        return InkWell(
                          onTap: () {
                            setDialogState(() => tempMonth = monthVal);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFF8C42) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFFF8C42) : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              _getMonthNameShort(monthVal),
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                            child: Text(
                              'Batal',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                selectedMonth = tempMonth;
                                selectedYear = tempYear;
                                selectedDate = null;
                                _applyFilters();
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF8C42),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Pilih',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getMonthNameShort(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return months[month - 1];
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

  Future<void> _editCatatanAdmin(Map order, StateSetter setStateSheet) async {
    final TextEditingController controller =
        TextEditingController(text: order['catatan_admin'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await supabase
                    .from('tabel_invoice')
                    .update({'catatan_admin': controller.text.trim()})
                    .eq('id_invoice', order['id_invoice']);

                setStateSheet(() {
                  order['catatan_admin'] = controller.text.trim();
                });
                getOrders();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Catatan admin berhasil diperbarui'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(e.toString()), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8C42)),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
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

  Widget _buildFloatingFilterButton() {
    final hasActiveFilter = selectedDate != null || (selectedMonth != null && selectedYear != null);

    String filterLabel = 'Filter';
    if (selectedDate != null) {
      filterLabel = DateFormat('dd MMM yyyy').format(selectedDate!);
    } else if (selectedMonth != null && selectedYear != null) {
      filterLabel = _getMonthNameShort(selectedMonth!) + ' $selectedYear';
    }

    return Card(
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      color: hasActiveFilter ? const Color(0xFFFF8C42) : Colors.white,
      child: InkWell(
        onTap: _showFilterBottomSheet,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: hasActiveFilter ? const Color(0xFFFF8C42) : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasActiveFilter ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
                color: hasActiveFilter ? Colors.white : const Color(0xFFFF8C42),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                filterLabel,
                style: TextStyle(
                  color: hasActiveFilter ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (hasActiveFilter) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _clearAllFilters,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final hasActiveFilter = selectedDate != null || (selectedMonth != null && selectedYear != null);

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Pesanan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (hasActiveFilter)
                        TextButton(
                          onPressed: () {
                            _clearAllFilters();
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Reset Semua',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selectedDate != null
                            ? const Color(0xFFFF8C42).withOpacity(0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_today_rounded,
                        color: selectedDate != null ? const Color(0xFFFF8C42) : Colors.grey.shade700,
                      ),
                    ),
                    title: const Text(
                      'Filter Harian (Tanggal)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      selectedDate != null
                          ? DateFormat('dd MMMM yyyy').format(selectedDate!)
                          : 'Pilih tanggal spesifik',
                      style: TextStyle(
                        color: selectedDate != null ? const Color(0xFFFF8C42) : Colors.grey,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickDate();
                    },
                  ),
                  const Divider(height: 24),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (selectedMonth != null && selectedYear != null)
                            ? const Color(0xFFFF8C42).withOpacity(0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.date_range_rounded,
                        color: (selectedMonth != null && selectedYear != null)
                            ? const Color(0xFFFF8C42) : Colors.grey.shade700,
                      ),
                    ),
                    title: const Text(
                      'Filter Bulanan (Bulan & Tahun)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      (selectedMonth != null && selectedYear != null)
                          ? _getMonthName(selectedMonth!) + ' $selectedYear'
                          : 'Pilih bulan dan tahun',
                      style: TextStyle(
                        color: (selectedMonth != null && selectedYear != null)
                            ? const Color(0xFFFF8C42) : Colors.grey,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickMonthYear();
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF8C42)),
      );
    }

    final hasActiveFilter = selectedDate != null || (selectedMonth != null && selectedYear != null);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: getOrders,
          color: const Color(0xFFFF8C42),
          child: orders.isEmpty
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          hasActiveFilter ? Icons.search_off : Icons.inbox,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          hasActiveFilter
                              ? 'Tidak ada pesanan yang cocok dengan filter'
                              : 'Belum ada pesanan',
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        if (hasActiveFilter) ...[
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _clearAllFilters,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF8C42),
                            ),
                            child: const Text('Hapus Filter', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
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

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.015),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade100, width: 0.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: () => showDetail(order),
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
                      ),
                    );
                  },
                ),
        ),
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: _buildFloatingFilterButton(),
          ),
        ),
      ],
    );
  }
}
