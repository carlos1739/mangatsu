import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:project_manga/screens/auth/login.dart';
import 'package:project_manga/screens/auth/user/user_session.dart';
// SESUAIKAN: path file Beranda (kalau merah, klik "Beranda" lalu Ctrl + .)
import 'package:project_manga/screens/home/home.dart';

class Profil extends StatelessWidget {
  const Profil({super.key});

  // SESUAIKAN port Flask (samakan dengan yang dipakai di halaman login/register)
  static String get baseUrl =>
      kIsWeb ? 'http://localhost:5000' : 'http://10.0.2.2:5000';

  void _logout(BuildContext context) {
    UserSession.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SignIn()),
      (route) => false,
    );
  }

  void _goHome(BuildContext context) {
    UserSession.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const Beranda()),
      (route) => false,
    );
  }

  /// Return null kalau berhasil, atau pesan error kalau gagal.
  Future<String?> _deleteAccount(String password) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/delete-account'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': UserSession.email ?? '',
          'password': password,
        }),
      );

      if (response.statusCode == 200) return null;

      try {
        final body = jsonDecode(response.body);
        return body['message']?.toString() ??
            'Gagal (kode ${response.statusCode})';
      } catch (_) {
        return 'Gagal (kode ${response.statusCode})';
      }
    } catch (e) {
      return 'Tidak bisa terhubung ke server: $e';
    }
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final passwordController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Akun'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Apakah kamu yakin ingin menghapus akun ini? '
                'Semua data akan hilang dan tidak bisa dikembalikan.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Masukkan password untuk konfirmasi',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    final error = await _deleteAccount(passwordController.text);

    if (!context.mounted) return;
    if (error == null) {
      _goHome(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Logo dan nama aplikasi
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/logo/LogoM1.png', width: 50),
                    const Text(
                      "angaTsu",
                      style: TextStyle(
                        fontFamily: 'Tilt',
                        color: Colors.black,
                        fontSize: 30,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            const Text(
              "Profil Pengguna",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: UserSession.isLoggedIn
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoField(label: "Nama", value: UserSession.nama ?? '-'),
                        const SizedBox(height: 20),
                        _InfoField(
                          label: "Email",
                          value: UserSession.email ?? '-',
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _logout(context),
                            child: const Text(
                              "Logout",
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showDeleteDialog(context),
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text(
                              "Hapus Akun",
                              style: TextStyle(fontSize: 18, color: Colors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    )
                  : Column(
                      children: [
                        const Text("Kamu belum login."),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _logout(context),
                            child: const Text(
                              "Ke halaman Login",
                              style: TextStyle(fontSize: 18),
                            ),
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

class _InfoField extends StatelessWidget {
  final String label;
  final String value;

  const _InfoField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(value, style: const TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}