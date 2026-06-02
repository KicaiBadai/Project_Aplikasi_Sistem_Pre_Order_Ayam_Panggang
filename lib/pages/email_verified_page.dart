import 'package:flutter/material.dart';

class EmailVerifiedPage extends StatelessWidget {
  const EmailVerifiedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified, color: Colors.green, size: 100),

              const SizedBox(height: 20),

              const Text(
                'Email Berhasil Diverifikasi',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              const Text(
                'Sekarang kamu bisa login ke aplikasi.',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Kembali Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
