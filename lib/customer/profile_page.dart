import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;

  final namaController = TextEditingController();
  final noHpController = TextEditingController();
  final alamatController = TextEditingController();

  bool isLoading = true;
  bool isSave = false;
  bool isEdit = false;

  Map? userData;

  File? imageFile;

  @override
  void initState() {
    super.initState();

    getProfile();
  }

  Future<void> getProfile() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) return;

      final data = await supabase
          .from('tabel_user')
          .select()
          .eq('auth_id', user.id)
          .single();

      namaController.text = data['nama_user'] ?? '';
      noHpController.text = data['no_hp'] ?? '';
      alamatController.text = data['alamat'] ?? '';

      setState(() {
        userData = data;
        isLoading = false;
      });
    } catch (e) {
      print(e);

      setState(() {
        isLoading = false;
      });
    }
  }

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

  Future<String?> uploadImage() async {
    try {
      if (imageFile == null) {
        return userData?['foto_profile'];
      }

      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage.from('foto-profile').upload(fileName, imageFile!);

      final imageUrl = supabase.storage
          .from('foto-profile')
          .getPublicUrl(fileName);

      return imageUrl;
    } catch (e) {
      print(e);

      return null;
    }
  }

  Future<void> saveProfile() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) return;

      setState(() {
        isSave = true;
      });

      final imageUrl = await uploadImage();

      await supabase
          .from('tabel_user')
          .update({
            'nama_user': namaController.text.trim(),
            'no_hp': noHpController.text.trim(),
            'alamat': alamatController.text.trim(),
            'foto_profile': imageUrl,
          })
          .eq('auth_id', user.id);

      await getProfile();

      setState(() {
        isEdit = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile berhasil diperbarui')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() {
        isSave = false;
      });
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Widget buildInfoTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),

      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10),
        ],
      ),

      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),

            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),

            child: Icon(icon, color: Colors.orange),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),

                const SizedBox(height: 5),

                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '-';

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],

      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, bottom: 30),

              decoration: const BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),

              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.white,

                        backgroundImage: imageFile != null
                            ? FileImage(imageFile!)
                            : userData?['foto_profile'] != null
                            ? NetworkImage(userData!['foto_profile'])
                            : null,

                        child:
                            imageFile == null &&
                                userData?['foto_profile'] == null
                            ? const Icon(
                                Icons.person,
                                size: 55,
                                color: Colors.orange,
                              )
                            : null,
                      ),

                      if (isEdit)
                        Positioned(
                          bottom: 0,
                          right: 0,

                          child: InkWell(
                            onTap: pickImage,

                            child: Container(
                              padding: const EdgeInsets.all(8),

                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),

                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  Text(
                    namaController.text.isEmpty
                        ? 'Customer'
                        : namaController.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(email, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),

              child: Column(
                children: [
                  // INFO CARD
                  buildInfoTile(
                    Icons.phone,
                    'No Handphone',
                    noHpController.text,
                  ),

                  buildInfoTile(
                    Icons.location_on,
                    'Alamat',
                    alamatController.text,
                  ),

                  const SizedBox(height: 10),

                  // BUTTON EDIT
                  SizedBox(
                    width: double.infinity,
                    height: 50,

                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          isEdit = !isEdit;
                        });
                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),

                      icon: Icon(
                        isEdit ? Icons.close : Icons.edit,
                        color: Colors.white,
                      ),

                      label: Text(
                        isEdit ? 'Batal Edit' : 'Edit Profile',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),

                  // FORM EDIT
                  if (isEdit) ...[
                    const SizedBox(height: 25),

                    Container(
                      padding: const EdgeInsets.all(20),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.08),
                            blurRadius: 10,
                          ),
                        ],
                      ),

                      child: Column(
                        children: [
                          TextField(
                            controller: namaController,

                            decoration: InputDecoration(
                              labelText: 'Nama Lengkap',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          TextField(
                            controller: noHpController,
                            keyboardType: TextInputType.phone,

                            decoration: InputDecoration(
                              labelText: 'No HP',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          TextField(
                            controller: alamatController,
                            maxLines: 3,

                            decoration: InputDecoration(
                              labelText: 'Alamat',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),

                          const SizedBox(height: 25),

                          SizedBox(
                            width: double.infinity,
                            height: 50,

                            child: ElevatedButton(
                              onPressed: isSave ? null : saveProfile,

                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),

                              child: isSave
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      'Simpan Perubahan',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // LOGOUT
                  SizedBox(
                    width: double.infinity,
                    height: 50,

                    child: OutlinedButton.icon(
                      onPressed: logout,

                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),

                      icon: const Icon(Icons.logout),

                      label: const Text('Logout'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
