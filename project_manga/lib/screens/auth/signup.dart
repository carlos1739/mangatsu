import 'package:flutter/material.dart';
import 'package:project_manga/screens/auth/login.dart';
import 'package:project_manga/services/auth_service.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final TextEditingController nameCtr = TextEditingController();
  final TextEditingController emailCtr = TextEditingController();
  final TextEditingController pswCtr = TextEditingController();
  final TextEditingController confirmCtr = TextEditingController();
  bool secure = true;
  bool confirmSecure = true;
  bool loading = false;
  String? errorMessage;

  @override
  void dispose() {
    nameCtr.dispose();
    emailCtr.dispose();
    pswCtr.dispose();
    confirmCtr.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = nameCtr.text.trim();
    final email = emailCtr.text.trim();
    final password = pswCtr.text;

    if (name.length < 2 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ||
        password.length < 8) {
      setState(() => errorMessage = 'Nama, email valid, dan password minimal 8 karakter wajib diisi');
      return;
    }
    if (password != confirmCtr.text) {
      setState(() => errorMessage = 'Password dan konfirmasi password tidak sama');
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      await AuthService.register(
        name: name,
        email: email,
        password: password,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SignIn()),
      );
    } catch (error) {
      if (mounted) {
        setState(() => errorMessage = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 50),
            const Text(
              'Daftar',
              style: TextStyle(fontFamily: 'Tilt', fontSize: 50),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logo/LogoM1.png', width: 50),
                const Text(
                  'angaTsu',
                  style: TextStyle(fontFamily: 'Tilt', fontSize: 50),
                ),
              ],
            ),
            const SizedBox(height: 35),
            TextField(
              controller: nameCtr,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Masukkan Nama',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: emailCtr,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Masukkan Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: pswCtr,
              obscureText: secure,
              decoration: InputDecoration(
                hintText: 'Masukkan Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => secure = !secure),
                  icon: Icon(secure ? Icons.visibility_off : Icons.visibility),
                ),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: confirmCtr,
              obscureText: confirmSecure,
              decoration: InputDecoration(
                hintText: 'Masukkan Password Ulang',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => confirmSecure = !confirmSecure),
                  icon: Icon(
                    confirmSecure ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: OutlinedButton(
                onPressed: loading ? null : _register,
                child: loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Daftar'),
              ),
            ),
            const SizedBox(height: 25),
            TextButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SignIn()),
              ),
              child: const Text('Sudah punya akun? Login disini'),
            ),
          ],
        ),
      ),
    );
  }
}
