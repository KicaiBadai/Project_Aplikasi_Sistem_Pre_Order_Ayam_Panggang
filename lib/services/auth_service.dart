import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class AuthService {
  // REGISTER
  static Future<void> register({
    required String email,
    required String password,
    required String namaUser,
    required String noHp,
    required String alamat,
  }) async {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'com.preorderayam://login-callback',
    );

    final user = response.user;

    if (user != null) {
      await supabase.from('tabel_user').insert({
        'auth_id': user.id,
        'email': email,
        'no_hp': noHp,
        'alamat': alamat,
        'nama_user': namaUser,
        'role': 'customer',
      });
    }
  }

  // RESET PASSWORD
  static Future<void> resetPassword({required String email}) async {
    await supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'com.preorderayam://reset-password',
    );
  }

  // LOGIN
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // LOGOUT
  static Future<void> logout() async {
    await supabase.auth.signOut();
  }

  // CURRENT USER
  static User? currentUser() {
    return supabase.auth.currentUser;
  }
}
