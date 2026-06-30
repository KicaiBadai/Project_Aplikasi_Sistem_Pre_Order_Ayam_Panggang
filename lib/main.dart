import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 1. Import package-nya
import 'package:intl/date_symbol_data_local.dart';

import 'auth_gate.dart';
import 'pages/splash_screen.dart';
import 'pages/change_password_page.dart';

final supabase = Supabase.instance.client;
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await initializeDateFormatting('id', null);

  // ================= SUPABASE =================
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );


  // ================= ONESIGNAL =================

  // GANTI DENGAN APP ID DARI ONESIGNAL
  OneSignal.initialize(dotenv.env['ONESIGNAL_APP_ID'] ?? '');

  // MINTA IZIN NOTIFIKASI
  await OneSignal.Notifications.requestPermission(true);

  // ================= AUTH LISTENER =================
  supabase.auth.onAuthStateChange.listen((data) async {
    final event = data.event;
    final session = data.session;

    if (event == AuthChangeEvent.userUpdated) {
      print('Email berhasil diverifikasi');
    }

    if (event == AuthChangeEvent.passwordRecovery) {
      print('Menerima permintaan reset password, set isRecoveringPassword ke true');
      isRecoveringPassword = true;
    }

    if (event == AuthChangeEvent.signedIn && session != null) {
      final email = session.user.email;
      if (email != null) {
        final isAdmin = (email.toLowerCase() == 'admin@gmail.com');
        try {
          if (isAdmin) {
            await OneSignal.login("admin");
            await OneSignal.User.addTagWithKey("role", "admin");
            print('OneSignal logged in as admin');
          } else {
            await OneSignal.login(email);
            await OneSignal.User.addTagWithKey("role", "customer");
            print('OneSignal logged in as customer: $email');
          }
        } catch (e) {
          print('Gagal sinkronisasi OneSignal: $e');
        }
      }
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,

      title: 'Pre Order Ayam',

      theme: ThemeData(primarySwatch: Colors.orange),

      home: const SplashScreen(),
    );
  }
}
