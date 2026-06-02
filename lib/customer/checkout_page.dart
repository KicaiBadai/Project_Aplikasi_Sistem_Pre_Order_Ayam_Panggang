import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'payment_page.dart';

// CATATAN: Kode notifikasi admin (OneSignal) telah dipindahkan ke PaymentPage
// Tidak ada lagi import 'dart:convert' dan 'package:http/http.dart' di sini

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final supabase = Supabase.instance.client;

  List cartList = [];
  List metodeList = [];

  bool isLoading = true;
  bool isGetLocation = false;
  bool isProsesCheckout = false;

  Map? selectedMetode;

  double? latitude;
  double? longitude;

  final namaController = TextEditingController();
  final hpController = TextEditingController();
  final alamatController = TextEditingController();
  final catatanController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadCart();
    loadMetode();
  }

  Future<void> getCurrentLocation() async {
    try {
      setState(() {
        isGetLocation = true;
      });

      if (!(Theme.of(context).platform == TargetPlatform.android ||
          Theme.of(context).platform == TargetPlatform.iOS)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS hanya berjalan di Android/iOS')),
        );
        setState(() => isGetLocation = false);
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('GPS belum aktif')));
        setState(() => isGetLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Izin lokasi ditolak')));
        setState(() => isGetLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      latitude = position.latitude;
      longitude = position.longitude;

      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude!,
        longitude!,
      );
      Placemark place = placemarks[0];
      String fullAddress =
          '${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}';

      setState(() {
        alamatController.text = fullAddress;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lokasi berhasil diambil'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => isGetLocation = false);
    }
  }

  Future<void> loadCart() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final data = await supabase
        .from('tabel_keranjang')
        .select('''
          qty,
          tabel_barang (
            id_barang,
            harga,
            nama_barang
          )
        ''')
        .eq('auth_id', user.id);
    setState(() {
      cartList = data;
      isLoading = false;
    });
  }

  Future<void> loadMetode() async {
    try {
      final data = await supabase
          .from('tabel_metode_pembayaran')
          .select()
          .eq('status', 'aktif');
      setState(() {
        metodeList = data;
        if (data.isNotEmpty) selectedMetode = data[0];
      });
    } catch (e) {
      print(e);
    }
  }

  int getTotal() {
    int total = 0;
    for (var item in cartList) {
      final barang = item['tabel_barang'];
      total += (barang['harga'] as int) * (item['qty'] as int);
    }
    return total;
  }

  // FUNGSI sendNotifAdmin() TELAH DIHAPUS
  // Notifikasi admin dikirim dari PaymentPage setelah bukti transfer diunggah

  Future<void> checkout() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (namaController.text.isEmpty ||
        hpController.text.isEmpty ||
        alamatController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lengkapi data pengiriman'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (selectedMetode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih metode pembayaran'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => isProsesCheckout = true);

    try {
      final total = getTotal();
      final invoice = await supabase
          .from('tabel_invoice')
          .insert({
            'auth_id': user.id,
            'kode_invoice': DateTime.now().millisecondsSinceEpoch.toString(),
            'total': total,
            'status': 'pending',
            'tanggal': DateTime.now().toIso8601String(),
            'id_metode': selectedMetode!['id_metode'],
            'nama_penerima': namaController.text,
            'no_hp': hpController.text,
            'alamat': alamatController.text,
            'catatan': catatanController.text,
            'latitude': latitude,
            'longitude': longitude,
          })
          .select()
          .single();

      final idInvoice = invoice['id_invoice'];

      for (var item in cartList) {
        final barang = item['tabel_barang'];
        final harga = barang['harga'] as int;
        final qty = item['qty'] as int;
        await supabase.from('tabel_pesanan').insert({
          'id_invoice': idInvoice,
          'id_barang': barang['id_barang'],
          'qty': qty,
          'harga': harga,
          'subtotal': harga * qty,
        });
      }

      await supabase.from('tabel_pembayaran').insert({
        'id_invoice': idInvoice,
        'status_verifikasi': 'pending',
      });

      await supabase.from('tabel_keranjang').delete().eq('auth_id', user.id);

      // notifikasi admin dipindahkan ke PaymentPage
      // await sendNotifAdmin();  // TIDAK ADA LAGI

      final metodeNama = selectedMetode!['nama_metode']
          .toString()
          .toLowerCase();
      if (metodeNama.contains('cod')) {
        await supabase
            .from('tabel_invoice')
            .update({'status': 'selesai'})
            .eq('id_invoice', idInvoice);
        await supabase
            .from('tabel_pembayaran')
            .update({'status_verifikasi': 'paid'})
            .eq('id_invoice', idInvoice);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan COD berhasil dibuat'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentPage(invoiceId: idInvoice),
          ),
        );
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => isProsesCheckout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFFF8C42)),
              SizedBox(height: 16),
              Text('Memuat...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFEF7E8),
      appBar: AppBar(
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFF8C42),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ringkasan pesanan dalam Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ringkasan Pesanan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cartList.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = cartList[index];
                            final barang = item['tabel_barang'];
                            return Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    barang['nama_barang'],
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'x${item['qty']}',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Rp ${(barang['harga'] as int).toString()}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Rp ${getTotal()}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF8C42),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Form data pengiriman
                const Text(
                  'Data Pengiriman',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: namaController,
                  decoration: InputDecoration(
                    labelText: 'Nama Penerima',
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: Color(0xFFFF8C42),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: hpController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Nomor HP',
                    prefixIcon: const Icon(
                      Icons.phone_android_outlined,
                      color: Color(0xFFFF8C42),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: alamatController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Alamat Lengkap',
                    prefixIcon: const Icon(
                      Icons.home_outlined,
                      color: Color(0xFFFF8C42),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF8C42),
                      side: const BorderSide(color: Color(0xFFFF8C42)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: isGetLocation ? null : getCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: isGetLocation
                        ? const Text('Mengambil lokasi...')
                        : const Text('Ambil Lokasi GPS'),
                  ),
                ),
                if (latitude != null && longitude != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.gps_fixed,
                          size: 16,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lat: $latitude, Lng: $longitude',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: catatanController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Catatan (opsional)',
                    prefixIcon: const Icon(
                      Icons.edit_note,
                      color: Color(0xFFFF8C42),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Metode pembayaran
                const Text(
                  'Metode Pembayaran',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Map>(
                  value: selectedMetode,
                  items: metodeList.map((item) {
                    return DropdownMenuItem<Map>(
                      value: item,
                      child: Row(
                        children: [
                          Icon(
                            Icons.payment,
                            color: const Color(0xFFFF8C42),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(item['nama_metode']),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedMetode = val),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
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
                      elevation: 2,
                    ),
                    onPressed: isProsesCheckout ? null : checkout,
                    child: isProsesCheckout
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Bayar Sekarang',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
          if (isProsesCheckout)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF8C42)),
              ),
            ),
        ],
      ),
    );
  }
}
