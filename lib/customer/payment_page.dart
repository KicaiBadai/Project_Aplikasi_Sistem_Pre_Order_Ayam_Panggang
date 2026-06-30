import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../services/notification_service.dart';


class PaymentPage extends StatefulWidget {
  final int invoiceId;

  const PaymentPage({super.key, required this.invoiceId});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final supabase = Supabase.instance.client;
  Map? invoice;
  Map? metodeData;
  bool isLoading = true;
  bool isUpload = false;
  bool isPicking = false;
  File? imageFile;

  @override
  void initState() {
    super.initState();
    getInvoice();
  }

  @override
  void dispose() {
    imageFile = null;
    super.dispose();
  }

  Future<void> getInvoice() async {
    try {
      final data = await supabase
          .from('tabel_invoice')
          .select('''
            *,
            tabel_metode_pembayaran (
              id_metode,
              nama_metode,
              nomor_pembayaran,
              atas_nama,
              logo
            )
          ''')
          .eq('id_invoice', widget.invoiceId)
          .single();

      setState(() {
        invoice = data;
        metodeData = data['tabel_metode_pembayaran'];
        isLoading = false;
      });
    } catch (e) {
      print(e);
      setState(() => isLoading = false);
    }
  }

  Future<bool> _requestGalleryPermission() async {
    if (await Permission.photos.isGranted) return true;
    if (await Permission.photos.request().isGranted) return true;
    return false;
  }

  Future<File?> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );
      return result != null ? File(result.path) : file;
    } catch (e) {
      print("Gagal kompresi: $e");
      return file;
    }
  }

  Future<void> pickImage() async {
    if (isPicking) return;
    setState(() => isPicking = true);
    try {
      final hasPermission = await _requestGalleryPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin akses galeri diperlukan'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (picked == null) return;
      final compressed = await _compressImage(File(picked.path));
      if (mounted) setState(() => imageFile = compressed);
    } catch (e) {
      print("Error pick image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isPicking = false);
    }
  }

  Future<void> uploadBuktiTransfer() async {
    if (imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih bukti transfer terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => isUpload = true);
    try {
      final fileName = 'bukti_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage
          .from('bukti-transfer')
          .upload(fileName, imageFile!);
      final imageUrl = supabase.storage
          .from('bukti-transfer')
          .getPublicUrl(fileName);
      await supabase
          .from('tabel_pembayaran')
          .update({
            'bukti_transfer': imageUrl,
            'status_verifikasi': 'menunggu_verifikasi',
          })
          .eq('id_invoice', widget.invoiceId);
      await supabase
          .from('tabel_invoice')
          .update({'status': 'menunggu_verifikasi'})
          .eq('id_invoice', widget.invoiceId);

      // Kirim notifikasi ke admin setelah upload berhasil
      final namaPenerima = invoice?['nama_penerima'] ?? 'Pelanggan';
      final total = invoice?['total'] ?? 0;
      await NotificationService.sendNotificationToAdmin(
        namaPenerima: namaPenerima,
        total: total,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bukti transfer berhasil dikirim'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal upload: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isUpload = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF8C42)),
        ),
      );
    }
    if (invoice == null) {
      return const Scaffold(
        body: Center(child: Text('Invoice tidak ditemukan')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFEF7E8),
      appBar: AppBar(
        title: const Text(
          'Pembayaran',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFF8C42),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Invoice
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INVOICE',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '#${invoice?['kode_invoice'] ?? '-'}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Bayar',
                        style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Rp ${invoice?['total'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Color(0xFFFF8C42),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // Metode Pembayaran Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8C42).withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFF8C42).withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (metodeData?['logo'] != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            metodeData!['logo'],
                            width: 55,
                            height: 55,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 55,
                              height: 55,
                              color: Colors.white,
                              child: const Icon(
                                Icons.payment,
                                color: Color(0xFFFF8C42),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          metodeData?['nama_metode'] ??
                              'Metode tidak ditemukan',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(color: const Color(0xFFFF8C42).withOpacity(0.15)),
                  const SizedBox(height: 15),
                  const Text(
                    'Nomor Pembayaran',
                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 5),
                  SelectableText(
                    metodeData?['nomor_pembayaran'] ?? '-',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Atas Nama',
                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    metodeData?['atas_nama'] ?? '-',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Tombol pilih gambar
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF8C42),
                  side: const BorderSide(color: Color(0xFFFF8C42), width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: isPicking ? null : pickImage,
                icon: isPicking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFF8C42),
                        ),
                      )
                    : const Icon(Icons.image, color: Color(0xFFFF8C42)),
                label: Text(
                  isPicking ? 'Memilih gambar...' : 'Pilih Bukti Transfer',
                  style: const TextStyle(
                    color: Color(0xFFFF8C42),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Preview gambar
            if (imageFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(
                  imageFile!,
                  cacheWidth: 800,
                  cacheHeight: 600,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 30),

            // Tombol kirim
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8C42),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: (isUpload || isPicking) ? null : uploadBuktiTransfer,
                child: isUpload
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Kirim Bukti Transfer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
