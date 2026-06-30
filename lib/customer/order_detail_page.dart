import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderDetailPage extends StatefulWidget {
  final int invoiceId;

  const OrderDetailPage({super.key, required this.invoiceId});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final supabase = Supabase.instance.client;

  Map? invoice;
  Map? pembayaran;

  List pesananList = [];

  bool isLoading = true;
  bool isUpload = false;

  File? imageFile;

  @override
  void initState() {
    super.initState();
    getDetail();
  }

  // ===================== GET DETAIL =====================
  Future<void> getDetail() async {
    try {
      final invoiceData = await supabase
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
          .eq('id_invoice', widget.invoiceId)
          .single();

      final pembayaranData = await supabase
          .from('tabel_pembayaran')
          .select()
          .eq('id_invoice', widget.invoiceId)
          .maybeSingle();

      final pesananData = await supabase
          .from('tabel_pesanan')
          .select('''
            qty,
            harga,
            subtotal,
            tabel_barang (
              nama_barang,
              foto
            )
          ''')
          .eq('id_invoice', widget.invoiceId);

      setState(() {
        invoice = invoiceData;
        pembayaran = pembayaranData;
        pesananList = pesananData;
        isLoading = false;
      });
    } catch (e) {
      print(e);

      setState(() {
        isLoading = false;
      });
    }
  }

  // ===================== PICK IMAGE =====================
  Future<void> pickImage() async {
    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (picked == null) return;

    setState(() {
      imageFile = File(picked.path);
    });
  }

  // ===================== UPLOAD BUKTI =====================
  Future<void> uploadBukti() async {
    try {
      if (imageFile == null) return;

      setState(() {
        isUpload = true;
      });

      final fileName = 'bukti_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage
          .from('bukti-transfer')
          .upload(fileName, imageFile!);

      final url = supabase.storage
          .from('bukti-transfer')
          .getPublicUrl(fileName);

      await supabase
          .from('tabel_pembayaran')
          .update({
            'bukti_transfer': url,
            'status_verifikasi': 'menunggu_verifikasi',
          })
          .eq('id_invoice', widget.invoiceId);

      await supabase
          .from('tabel_invoice')
          .update({'status': 'menunggu_verifikasi'})
          .eq('id_invoice', widget.invoiceId);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bukti berhasil dikirim')));

      getDetail();
    } catch (e) {
      print(e);
    } finally {
      setState(() {
        isUpload = false;
      });
    }
  }

  // ===================== STATUS =====================
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
        return 'Diproses';

      case 'selesai':
        return 'Selesai';

      case 'ditolak':
        return 'Ditolak';

      default:
        return status;
    }
  }

  // ===================== UI =====================
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (invoice == null) {
      return const Scaffold(
        body: Center(child: Text("Invoice tidak ditemukan")),
      );
    }

    final metode = invoice!['tabel_metode_pembayaran'];

    final isCOD =
        metode != null &&
        metode['nama_metode'].toString().toLowerCase().contains('cod');

    final status = invoice!['status'] ?? 'pending';

    return Scaffold(
      backgroundColor: const Color(0xFFFEF7E8),
      appBar: AppBar(
        title: const Text(
          "Detail Pesanan",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFF8C42),
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // ===================== INVOICE =====================
            Container(
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
                border: Border.all(color: Colors.grey.shade100, width: 0.5),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    "INV-${invoice!['kode_invoice']}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // STATUS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                    children: [
                      const Text(
                        "Status",
                        style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
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

                  const Divider(height: 32),

                  // TANGGAL
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                    children: [
                      const Text("Tanggal", style: TextStyle(color: Colors.grey, fontSize: 14)),

                      Text(
                        invoice!['tanggal'] ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // METODE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                    children: [
                      const Text("Metode Pembayaran", style: TextStyle(color: Colors.grey, fontSize: 14)),

                      Text(
                        metode?['nama_metode'] ?? 'COD / Tidak ada metode',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),

                  // NOMOR PEMBAYARAN
                  if (!isCOD && metode != null) ...[
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [
                        const Text("Nomor Pembayaran", style: TextStyle(color: Colors.grey, fontSize: 14)),

                        Text(
                          metode['nomor_pembayaran'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [
                        const Text("Atas Nama", style: TextStyle(color: Colors.grey, fontSize: 14)),

                        Text(
                          metode['atas_nama'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ===================== DATA PENERIMA =====================
            Container(
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
                border: Border.all(color: Colors.grey.shade100, width: 0.5),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    "Data Pengiriman",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // NAMA
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const Icon(Icons.person_outline, color: Color(0xFFFF8C42)),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            const Text(
                              "Nama Penerima",
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),

                            Text(
                              invoice!['nama_penerima'] ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // HP
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const Icon(Icons.phone_android_outlined, color: Color(0xFFFF8C42)),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            const Text(
                              "Nomor HP",
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),

                            Text(
                              invoice!['no_hp'] ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ALAMAT
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const Icon(Icons.location_on_outlined, color: Color(0xFFFF8C42)),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            const Text(
                              "Alamat",
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),

                            Text(
                              invoice!['alamat'] ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Catatan Pembeli", style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(width: 20),

                      Expanded(
                        child: Text(
                          invoice!['catatan'] == null ||
                                  invoice!['catatan'].toString().isEmpty
                              ? '-'
                              : invoice!['catatan'],
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),

                  // GPS
                  if (invoice!['latitude'] != null &&
                      invoice!['longitude'] != null) ...[
                    const SizedBox(height: 16),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Icon(Icons.gps_fixed_outlined, color: Colors.green),

                        const SizedBox(width: 10),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              const Text(
                                "Koordinat GPS",
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),

                              Text(
                                '${invoice!['latitude']}, ${invoice!['longitude']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ===================== COD INFO =====================
            if (isCOD)
              Container(
                padding: const EdgeInsets.all(15),

                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),

                child: Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined, color: Colors.green),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        "COD - Tidak perlu upload pembayaran",
                        style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // ===================== PESANAN =====================
            const Text(
              "Daftar Pesanan",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),

            const SizedBox(height: 15),

            ...pesananList.map((item) {
              final barang = item['tabel_barang'];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                  border: Border.all(color: Colors.grey.shade100, width: 0.5),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),

                      child: Image.network(
                        barang['foto'],
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 70,
                          height: 70,
                          color: Colors.grey.shade100,
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      ),
                    ),

                    const SizedBox(width: 15),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            barang['nama_barang'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1E293B),
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text("Qty : ${item['qty']}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),

                          const SizedBox(height: 5),

                          Text(
                            "Rp ${item['harga']}",
                            style: const TextStyle(
                              color: Color(0xFFFF8C42),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Text(
                      "Rp ${item['subtotal']}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 20),

            // ===================== TOTAL =====================
            Container(
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
                border: Border.all(color: Colors.grey.shade100, width: 0.5),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  const Text(
                    "Total Pembayaran",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),

                  Text(
                    "Rp ${invoice!['total']}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF8C42),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // ===================== BUKTI TRANSFER =====================
            if (!isCOD) ...[
              const Text(
                "Bukti Transfer",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),

              const SizedBox(height: 15),

              if (pembayaran?['bukti_transfer'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),

                  child: Image.network(pembayaran!['bukti_transfer']),
                ),

              const SizedBox(height: 15),

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF8C42),
                  side: const BorderSide(color: Color(0xFFFF8C42), width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: pickImage,
                icon: const Icon(Icons.image),
                label: const Text("Pilih / Ganti Bukti", style: TextStyle(fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 15),

              if (imageFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),

                  child: Image.file(
                    imageFile!,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 55,

                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8C42),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: isUpload ? null : uploadBukti,

                  child: isUpload
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Upload Bukti Pembayaran", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
