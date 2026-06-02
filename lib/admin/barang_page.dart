import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BarangPage extends StatefulWidget {
  const BarangPage({super.key});

  @override
  State<BarangPage> createState() => _BarangPageState();
}

class _BarangPageState extends State<BarangPage> {
  final supabase = Supabase.instance.client;
  List barangList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    getBarang();
  }

  Future<void> getBarang() async {
    try {
      final data = await supabase
          .from('tabel_barang')
          .select()
          .order('id_barang', ascending: false);
      setState(() {
        barangList = data;
        isLoading = false;
      });
    } catch (e) {
      print(e);
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteBarang(int id) async {
    try {
      await supabase.from('tabel_barang').delete().eq('id_barang', id);
      getBarang();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barang berhasil dihapus'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print(e);
    }
  }

  void showForm({Map? barang}) {
    final namaController = TextEditingController(text: barang?['nama_barang']);
    final deskripsiController = TextEditingController(
      text: barang?['deskripsi'],
    );
    final hargaController = TextEditingController(
      text: barang?['harga']?.toString(),
    );
    final stokController = TextEditingController(
      text: barang?['stok']?.toString(),
    );
    String status = barang?['status'] ?? 'tersedia';
    File? imageFile;
    String fotoUrl = barang?['foto'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      barang == null ? 'Tambah Barang' : 'Edit Barang',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF8C42),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: namaController,
                      decoration: InputDecoration(
                        labelText: 'Nama Barang',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: deskripsiController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Deskripsi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: hargaController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Harga',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: stokController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Stok',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Column(
                      children: [
                        if (imageFile != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              imageFile!,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                        else if (fotoUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              fotoUrl,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (picked != null) {
                                setModalState(() {
                                  imageFile = File(picked.path);
                                });
                              }
                            },
                            icon: const Icon(Icons.image),
                            label: const Text('Pilih Foto'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF8C42),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField(
                      value: status,
                      items: const [
                        DropdownMenuItem(
                          value: 'tersedia',
                          child: Text('Tersedia'),
                        ),
                        DropdownMenuItem(value: 'habis', child: Text('Habis')),
                      ],
                      onChanged: (value) {
                        status = value!;
                      },
                      decoration: InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            String foto = fotoUrl;
                            if (imageFile != null) {
                              final fileName =
                                  'barang_${DateTime.now().millisecondsSinceEpoch}.jpg';
                              await supabase.storage
                                  .from('foto-barang')
                                  .upload(fileName, imageFile!);
                              foto = supabase.storage
                                  .from('foto-barang')
                                  .getPublicUrl(fileName);
                            }
                            final data = {
                              'nama_barang': namaController.text,
                              'deskripsi': deskripsiController.text,
                              'harga': double.parse(hargaController.text),
                              'stok': int.parse(stokController.text),
                              'foto': foto,
                              'status': status,
                            };
                            if (barang == null) {
                              await supabase.from('tabel_barang').insert(data);
                            } else {
                              await supabase
                                  .from('tabel_barang')
                                  .update(data)
                                  .eq('id_barang', barang['id_barang']);
                            }
                            if (!mounted) return;
                            Navigator.pop(context);
                            getBarang();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  barang == null
                                      ? 'Barang berhasil ditambah'
                                      : 'Barang berhasil diupdate',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            print(e);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8C42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          barang == null ? 'Tambah Barang' : 'Update Barang',
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF8C42)),
      );
    }
    return RefreshIndicator(
      onRefresh: getBarang,
      color: const Color(0xFFFF8C42),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: ElevatedButton.icon(
                onPressed: () => showForm(),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Barang'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8C42),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ),
          if (barangList.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'Belum ada data barang',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final barang = barangList[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
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
                              child: const Icon(
                                Icons.image,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                barang['nama_barang'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rp ${barang['harga']}',
                                style: const TextStyle(
                                  color: Color(0xFFFF8C42),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: barang['stok'] > 0
                                          ? Colors.green.shade50
                                          : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Stok: ${barang['stok']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: barang['stok'] > 0
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: barang['status'] == 'tersedia'
                                          ? Colors.blue.shade50
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      barang['status'] == 'tersedia'
                                          ? 'Tersedia'
                                          : 'Habis',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: barang['status'] == 'tersedia'
                                            ? Colors.blue
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => showForm(barang: barang),
                              icon: const Icon(
                                Icons.edit,
                                color: Color(0xFFFF8C42),
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  deleteBarang(barang['id_barang']),
                              icon: const Icon(Icons.delete, color: Colors.red),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }, childCount: barangList.length),
            ),
        ],
      ),
    );
  }
}
