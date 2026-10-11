import 'package:flutter/material.dart';
import 'package:project_manga/screens/auth/signup.dart';
import 'package:project_manga/screens/auth/user/user_session.dart';
import 'package:project_manga/screens/home/home.dart';
import 'package:project_manga/services/auth_service.dart';

class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final TextEditingController emailCtr = TextEditingController();
  final TextEditingController pswCtr = TextEditingController();
  bool secure = true;
  bool loading = false;
  String? errorMessage;

  @override
  void dispose() {
    emailCtr.dispose();
    pswCtr.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = emailCtr.text.trim();
    final password = pswCtr.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => errorMessage = 'Email dan password wajib diisi');
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      final data = await AuthService.login(
        email: email,
        password: password,
      );
      final user = data['user'] as Map<String, dynamic>;
      UserSession.set(user);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Beranda()),
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
            const SizedBox(height: 60),
            const Text(
              'Login',
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
                onPressed: loading ? null : _login,
                child: loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Login'),
              ),
            ),
            const SizedBox(height: 25),
            TextButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const Signup()),
              ),
              child: const Text('Belum punya akun? Daftar disini'),
            ),
          ],
        ),
      ),
    );
  }
}
