import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin/admin_page.dart';
import 'customer/home_page.dart';
import 'pages/change_password_page.dart';

bool isRecoveringPassword = false;

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<String> getUserRole(User user) async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('tabel_user')
          .select('role')
          .eq('email', user.email!)
          .maybeSingle();
      
      if (data == null) {
        // Buat record user baru jika login via Google (OAuth)
        final rawMeta = user.userMetadata;
        final name = rawMeta?['full_name'] ?? rawMeta?['name'] ?? 'User Google';
        await supabase.from('tabel_user').insert({
          'auth_id': user.id,
          'email': user.email!,
          'nama_user': name,
          'role': 'customer',
          'no_hp': '',
          'alamat': '',
        });
        return 'customer';
      }

      debugPrint("Role dari database: ${data['role']}");
      return data['role'] ?? 'customer';
    } catch (e) {
      debugPrint("Error mengambil role: $e");
      return 'customer';
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;
        final event = snapshot.data?.event;

        // Jika terdeteksi event pemulihan password, langsung tampilkan ChangePasswordPage
        if (event == AuthChangeEvent.passwordRecovery || isRecoveringPassword) {
          debugPrint(
            "AuthGate: Event passwordRecovery/isRecoveringPassword terdeteksi, arahkan ke ChangePasswordPage",
          );
          return const ChangePasswordPage();
        }

        // Jika belum login, langsung tampilkan HomePage (tanpa login)
        if (session == null) {
          debugPrint(
            "AuthGate: Tidak ada session, tampilkan HomePage (tanpa login)",
          );
          return const HomePage(); // <-- Ganti LoginPage dengan HomePage
        }

        final emailUser = session.user.email;
        debugPrint("AuthGate: User login dengan email: $emailUser");

        // Cek hardcode admin (case insensitive)
        final isAdminEmail = emailUser?.toLowerCase() == 'admin@gmail.com';
        if (isAdminEmail) {
          debugPrint("AuthGate: Email admin terdeteksi, arahkan ke AdminPage");
          return const AdminPage();
        }

        debugPrint("AuthGate: Bukan admin, cek role di database");
        return FutureBuilder<String>(
          future: getUserRole(session.user),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final role = roleSnapshot.data ?? 'customer';
            debugPrint("AuthGate: Role yang didapat = $role");

            if (role == 'admin') {
              return const AdminPage();
            } else {
              return const HomePage();
            }
          },
        );
      },
    );
  }
}
