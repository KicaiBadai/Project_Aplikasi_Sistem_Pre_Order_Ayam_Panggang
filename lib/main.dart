import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 1. Import package-nya

import 'auth_gate.dart';

final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ================= SUPABASE =================
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );
  await Supabase.instance.client.auth
      .signOut(); // <- tambahkan ini untuk logout paksa


  // ================= ONESIGNAL =================

  // GANTI DENGAN APP ID DARI ONESIGNAL
  OneSignal.initialize(dotenv.env['ONESIGNAL_APP_ID'] ?? '');

  // MINTA IZIN NOTIFIKASI
  await OneSignal.Notifications.requestPermission(true);

  // ================= AUTH LISTENER =================
  supabase.auth.onAuthStateChange.listen((data) {
    final event = data.event;

    if (event == AuthChangeEvent.userUpdated) {
      print('Email berhasil diverifikasi');
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Pre Order Ayam',

      theme: ThemeData(primarySwatch: Colors.orange),

      home: const AuthGate(),
    );
  }
}
