import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentMethodsAdminPage extends StatefulWidget {
  const PaymentMethodsAdminPage({super.key});

  @override
  State<PaymentMethodsAdminPage> createState() => _PaymentMethodsAdminPageState();
}

class _PaymentMethodsAdminPageState extends State<PaymentMethodsAdminPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> methods = [];

  @override
  void initState() {
    super.initState();
    loadMethods();
  }

  Future<void> loadMethods() async {
    try {
      setState(() => isLoading = true);
      final data = await supabase
          .from('tabel_metode_pembayaran')
          .select()
          .order('id_metode', ascending: true);
      
      setState(() {
        methods = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat metode pembayaran: $e'), backgroundColor: Colors.red),
        );
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _deleteMethod(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Hapus Metode?',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        content: const Text('Apakah Anda yakin ingin menghapus metode pembayaran ini? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('tabel_metode_pembayaran').delete().eq('id_metode', id);
      loadMethods();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Metode pembayaran berhasil dihapus'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showFormDialog({Map<String, dynamic>? method}) async {
    final isEdit = method != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: method?['nama_metode'] ?? '');
    final numberController = TextEditingController(text: method?['nomor_pembayaran'] ?? '');
    final ownerController = TextEditingController(text: method?['atas_nama'] ?? '');
    final logoController = TextEditingController(text: method?['logo'] ?? '');
    String status = method?['status'] ?? 'aktif';

    InputDecoration customInputDecoration({
      required String labelText,
      required String hintText,
      required IconData prefixIcon,
    }) {
      return InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(prefixIcon, color: const Color(0xFFFF8C42)),
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF8C42), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade200, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
      );
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: const Color(0xFFFEF7E8),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEdit ? '✏️ Edit Metode Bayar' : '✨ Tambah Metode Bayar',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, size: 20),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.grey.shade200,
                                padding: const EdgeInsets.all(6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: nameController,
                          decoration: customInputDecoration(
                            labelText: 'Nama Metode Pembayaran',
                            hintText: 'Contoh: Transfer Bank BCA',
                            prefixIcon: Icons.payments_outlined,
                          ),
                          validator: (value) =>
                              value == null || value.isEmpty ? 'Nama metode wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: numberController,
                          decoration: customInputDecoration(
                            labelText: 'Nomor Rekening / Pembayaran',
                            hintText: 'Contoh: 1234567890',
                            prefixIcon: Icons.tag,
                          ),
                          validator: (value) =>
                              value == null || value.isEmpty ? 'Nomor pembayaran wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: ownerController,
                          decoration: customInputDecoration(
                            labelText: 'Atas Nama Pemilik',
                            hintText: 'Contoh: Ahmad Fauzi',
                            prefixIcon: Icons.account_box_outlined,
                          ),
                          validator: (value) =>
                              value == null || value.isEmpty ? 'Nama pemilik wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: logoController,
                          decoration: customInputDecoration(
                            labelText: 'Link Logo (URL Gambar, Opsional)',
                            hintText: 'https://example.com/logo.png',
                            prefixIcon: Icons.link_rounded,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: status,
                          decoration: InputDecoration(
                            labelText: 'Status Metode',
                            prefixIcon: const Icon(Icons.toggle_on_outlined, color: Color(0xFFFF8C42)),
                            labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFFF8C42), width: 1.5),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'aktif', child: Text('Aktif')),
                            DropdownMenuItem(value: 'nonaktif', child: Text('Nonaktif')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => status = val);
                            }
                          },
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  side: BorderSide(color: Colors.grey.shade300),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(
                                  'Batal',
                                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (formKey.currentState?.validate() ?? false) {
                                    Navigator.pop(context);
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (_) => const Center(
                                        child: CircularProgressIndicator(color: Color(0xFFFF8C42)),
                                      ),
                                    );

                                    try {
                                      final payload = {
                                        'nama_metode': nameController.text.trim(),
                                        'nomor_pembayaran': numberController.text.trim(),
                                        'atas_nama': ownerController.text.trim(),
                                        'logo': logoController.text.trim().isEmpty ? null : logoController.text.trim(),
                                        'status': status,
                                      };

                                      if (isEdit) {
                                        await supabase
                                            .from('tabel_metode_pembayaran')
                                            .update(payload)
                                            .eq('id_metode', method['id_metode']);
                                      } else {
                                        await supabase
                                            .from('tabel_metode_pembayaran')
                                            .insert(payload);
                                      }

                                      if (!mounted) return;
                                      Navigator.pop(context); // close loading
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(isEdit
                                              ? 'Metode pembayaran berhasil diperbarui'
                                              : 'Metode pembayaran berhasil ditambahkan'),
                                          backgroundColor: Colors.green,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      loadMethods();
                                    } catch (e) {
                                      if (!mounted) return;
                                      Navigator.pop(context); // close loading
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Gagal menyimpan: $e'),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF8C42),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('Simpan',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF7E8),
      appBar: AppBar(
        title: const Text(
          'Metode Pembayaran',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFF8C42),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadMethods,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadMethods,
        color: const Color(0xFFFF8C42),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF8C42)),
              )
            : methods.isEmpty
                ? const Center(
                    child: Text('Belum ada metode pembayaran', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: methods.length,
                    itemBuilder: (context, index) {
                      final method = methods[index];
                      final isAktif = method['status'] == 'aktif';
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.grey.shade100,
                            width: 0.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF8C42).withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.grey.shade100, width: 0.5),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: method['logo'] != null && method['logo'].toString().isNotEmpty
                                        ? Image.network(
                                            method['logo'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.payments_outlined, color: Color(0xFFFF8C42)),
                                          )
                                        : const Icon(Icons.payments_outlined, color: Color(0xFFFF8C42)),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              method['nama_metode'] ?? '-',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1E293B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isAktif ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              isAktif ? 'Aktif' : 'Nonaktif',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isAktif ? Colors.green : Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'No: ${method['nomor_pembayaran'] ?? '-'}',
                                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'A.N. ${method['atas_nama'] ?? '-'}',
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                      onPressed: () => _showFormDialog(method: method),
                                      tooltip: 'Edit',
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.blue.withOpacity(0.05),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_outlined, color: Colors.red, size: 20),
                                      onPressed: () => _deleteMethod(method['id_metode']),
                                      tooltip: 'Hapus',
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.red.withOpacity(0.05),
                                        padding: const EdgeInsets.all(8),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        backgroundColor: const Color(0xFFFF8C42),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add),
      ),
    );
  }
}
