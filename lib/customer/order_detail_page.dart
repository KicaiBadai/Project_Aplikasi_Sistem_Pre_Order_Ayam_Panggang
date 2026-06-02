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
      appBar: AppBar(title: const Text("Detail Pesanan")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // ===================== INVOICE =====================
            Card(
              elevation: 4,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),

              child: Padding(
                padding: const EdgeInsets.all(15),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      "INV-${invoice!['kode_invoice']}",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // STATUS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [
                        const Text("Status", style: TextStyle(fontSize: 15)),

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

                    const Divider(height: 30),

                    // TANGGAL
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [
                        const Text("Tanggal"),

                        Text(
                          invoice!['tanggal'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // METODE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [
                        const Text("Metode Pembayaran"),

                        Text(
                          metode?['nama_metode'] ?? 'COD / Tidak ada metode',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),

                    // NOMOR PEMBAYARAN
                    if (!isCOD && metode != null) ...[
                      const SizedBox(height: 15),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,

                        children: [
                          const Text("Nomor Pembayaran"),

                          Text(
                            metode['nomor_pembayaran'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,

                        children: [
                          const Text("Atas Nama"),

                          Text(
                            metode['atas_nama'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ===================== DATA PENERIMA =====================
            Card(
              elevation: 4,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),

              child: Padding(
                padding: const EdgeInsets.all(15),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      "Data Pengiriman",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // NAMA
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Icon(Icons.person),

                        const SizedBox(width: 10),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              const Text(
                                "Nama Penerima",
                                style: TextStyle(color: Colors.grey),
                              ),

                              Text(
                                invoice!['nama_penerima'] ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // HP
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Icon(Icons.phone),

                        const SizedBox(width: 10),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              const Text(
                                "Nomor HP",
                                style: TextStyle(color: Colors.grey),
                              ),

                              Text(
                                invoice!['no_hp'] ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ALAMAT
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Icon(Icons.location_on),

                        const SizedBox(width: 10),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              const Text(
                                "Alamat",
                                style: TextStyle(color: Colors.grey),
                              ),

                              Text(
                                invoice!['alamat'] ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Catatan"),
                        const SizedBox(width: 20),

                        Expanded(
                          child: Text(
                            invoice!['catatan'] == null ||
                                    invoice!['catatan'].toString().isEmpty
                                ? '-'
                                : invoice!['catatan'],
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),

                    // GPS
                    if (invoice!['latitude'] != null &&
                        invoice!['longitude'] != null) ...[
                      const SizedBox(height: 20),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          const Icon(Icons.gps_fixed),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                const Text(
                                  "Koordinat GPS",
                                  style: TextStyle(color: Colors.grey),
                                ),

                                Text(
                                  '${invoice!['latitude']}, ${invoice!['longitude']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],

                    // CATATAN
                    if (invoice!['catatan'] != null &&
                        invoice!['catatan'] != '') ...[
                      const SizedBox(height: 20),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          const Icon(Icons.note),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                const Text(
                                  "Catatan",
                                  style: TextStyle(color: Colors.grey),
                                ),

                                Text(
                                  invoice!['catatan'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
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
            ),

            const SizedBox(height: 20),

            // ===================== COD INFO =====================
            if (isCOD)
              Container(
                padding: const EdgeInsets.all(15),

                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(15),
                ),

                child: const Row(
                  children: [
                    Icon(Icons.local_shipping, color: Colors.green),

                    SizedBox(width: 10),

                    Expanded(
                      child: Text("COD - Tidak perlu upload pembayaran"),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // ===================== PESANAN =====================
            const Text(
              "Daftar Pesanan",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            ...pesananList.map((item) {
              final barang = item['tabel_barang'];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),

                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),

                        child: Image.network(
                          barang['foto'],
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
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
                                fontSize: 16,
                              ),
                            ),

                            const SizedBox(height: 5),

                            Text("Qty : ${item['qty']}"),

                            const SizedBox(height: 5),

                            Text(
                              "Rp ${item['harga']}",
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Text(
                        "Rp ${item['subtotal']}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            // ===================== TOTAL =====================
            Card(
              elevation: 4,

              child: Padding(
                padding: const EdgeInsets.all(15),

                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    const Text(
                      "Total Pembayaran",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Text(
                      "Rp ${invoice!['total']}",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ===================== BUKTI TRANSFER =====================
            if (!isCOD) ...[
              const Text(
                "Bukti Transfer",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              if (pembayaran?['bukti_transfer'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),

                  child: Image.network(pembayaran!['bukti_transfer']),
                ),

              const SizedBox(height: 15),

              OutlinedButton.icon(
                onPressed: pickImage,

                icon: const Icon(Icons.image),

                label: const Text("Pilih / Ganti Bukti"),
              ),

              const SizedBox(height: 15),

              if (imageFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),

                  child: Image.file(
                    imageFile!,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                height: 50,

                child: ElevatedButton(
                  onPressed: isUpload ? null : uploadBukti,

                  child: isUpload
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Upload Bukti Pembayaran"),
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
